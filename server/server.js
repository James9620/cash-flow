require('dotenv').config();

const { createUserSessionToken, requireApiKey, requireUserId } = require('./auth');
const { verifyAppleIdentityToken: defaultVerifyAppleIdentityToken } = require('./appleAuth');
const { createPlaidWebhookVerifier } = require('./webhookVerifier');
const {
  getAccessToken,
  getSyncCursor,
  getTransactionsRefreshNeeded,
  getUserIdForItemId,
  markTransactionsRefreshNeeded,
  saveAccessToken,
  saveSyncCursor,
} = require('./tokenStore');

const port = process.env.PORT || 3000;
const syncPageSize = 500;
const maxSyncAttempts = 2;
const plaidRedirectUri = process.env.PLAID_REDIRECT_URI || 'https://cash-flow-production-341d.up.railway.app/oauth-redirect';
const plaidWebhookUrl = process.env.PLAID_WEBHOOK_URL || 'https://cash-flow-production-341d.up.railway.app/webhook';
const transactionUpdateWebhookCodes = new Set([
  'SYNC_UPDATES_AVAILABLE',
  'INITIAL_UPDATE',
  'HISTORICAL_UPDATE',
  'DEFAULT_UPDATE',
  'TRANSACTIONS_REMOVED',
]);
const enabledValues = new Set(['1', 'true', 'yes', 'required', 'enabled']);

function plaidErrorCode(error) {
  return error?.response?.data?.error_code ?? error?.data?.error_code ?? error?.error_code;
}

async function fetchTransactionUpdates(accessToken, startingCursor, attempt = 1, plaidClient) {
  let nextCursor = startingCursor;
  let hasMore = true;
  const added = [];
  const modified = [];
  const removed = [];
  let transactionsUpdateStatus = null;

  try {
    // Plaid may paginate transaction sync results, so keep asking until has_more is false.
    while (hasMore) {
      const request = {
        access_token: accessToken,
        count: syncPageSize,
      };

      if (nextCursor) {
        request.cursor = nextCursor;
      }

      const response = await plaidClient.transactionsSync(request);
      const data = response.data;

      added.push(...data.added);
      modified.push(...data.modified);
      removed.push(...data.removed);

      nextCursor = data.next_cursor;
      hasMore = data.has_more;
      transactionsUpdateStatus = data.transactions_update_status ?? transactionsUpdateStatus;
    }

    return {
      added,
      modified,
      removed,
      nextCursor,
      transactionsUpdateStatus,
    };
  } catch (error) {
    const shouldRestartSync =
      plaidErrorCode(error) === 'TRANSACTIONS_SYNC_MUTATION_DURING_PAGINATION' &&
      attempt < maxSyncAttempts;

    if (shouldRestartSync) {
      // If Plaid data changes during paging, Plaid says to restart from the cursor we began with.
      return fetchTransactionUpdates(accessToken, startingCursor, attempt + 1, plaidClient);
    }

    throw error;
  }
}

function createPlaidClient() {
  // Loading Plaid lazily lets tests import this file without initializing the SDK.
  const { Configuration, PlaidApi, PlaidEnvironments } = require('plaid');
  const plaidConfig = new Configuration({
    basePath: PlaidEnvironments[process.env.PLAID_ENV],
    baseOptions: {
      headers: {
        'PLAID-CLIENT-ID': process.env.PLAID_CLIENT_ID,
        'PLAID-SECRET': process.env.PLAID_SECRET,
      },
    },
  });

  return new PlaidApi(plaidConfig);
}

async function exchangeAppleSession(body, verifyAppleIdentityToken = defaultVerifyAppleIdentityToken) {
  const identityToken = body?.identity_token ?? body?.identityToken;
  const rawNonce = body?.raw_nonce ?? body?.rawNonce;

  if (typeof identityToken !== 'string' || identityToken.trim().length === 0) {
    const error = new Error('identity_token is required.');
    error.statusCode = 400;
    throw error;
  }

  if (typeof rawNonce !== 'string' || rawNonce.trim().length === 0) {
    const error = new Error('raw_nonce is required.');
    error.statusCode = 400;
    throw error;
  }

  const appleUser = await verifyAppleIdentityToken(identityToken.trim(), rawNonce.trim());
  const session = createUserSessionToken(appleUser.sub);

  return {
    session_token: session.token,
    user_id: appleUser.sub,
    expires_at: session.expiresAt,
  };
}

function createApp({
  plaidClient = createPlaidClient(),
  verifyAppleIdentityToken = defaultVerifyAppleIdentityToken,
} = {}) {
  const express = require('express');
  const cors = require('cors');
  const app = express();
  const verifyPlaidWebhook = createPlaidWebhookVerifier(plaidClient);

  app.use(cors());
  app.use(express.json({
    verify: (req, res, buffer) => {
      if (req.originalUrl.startsWith('/webhook')) {
        // Plaid signs the exact request body, so keep the raw bytes before JSON parsing.
        req.rawBody = Buffer.from(buffer);
      }
    },
  }));

  app.post('/auth/apple-session', async (req, res) => {
    try {
      res.json(await exchangeAppleSession(req.body, verifyAppleIdentityToken));
    } catch (error) {
      if (error.statusCode === 400) {
        return res.status(400).json({ error: error.message });
      }

      console.warn(`Rejected Apple session exchange: ${error.message}`);
      return res.status(401).json({ error: 'Unable to verify Apple sign-in.' });
    }
  });

  // Called by the iOS app to get a temporary token that opens the Plaid bank-connection UI.
  app.post('/create-link-token', requireApiKey, requireUserId, async (req, res) => {
    try {
      const response = await plaidClient.linkTokenCreate({
        user: { client_user_id: req.userId },
        client_name: 'Cash Flow',
        products: ['transactions'],
        country_codes: ['US'],
        language: 'en',
        redirect_uri: plaidRedirectUri,
        webhook: plaidWebhookUrl,
      });

      res.json({ link_token: response.data.link_token });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  // Exists solely to satisfy Plaid's OAuth flow requirement.
  app.get('/oauth-redirect', (req, res) => {
    res.send(`
      <!doctype html>
      <html lang="en">
        <head>
          <meta charset="utf-8">
          <title>Cash Flow</title>
        </head>
        <body>
          Redirecting back to Cash Flow...
        </body>
      </html>
    `);
  });

  // Called by the iOS app after the user connects their bank. Exchanges a short-lived public_token for a permanent access_token.
  app.post('/exchange-public-token', requireApiKey, requireUserId, async (req, res) => {
    try {
      const { public_token } = req.body;

      if (typeof public_token !== 'string' || public_token.trim().length === 0) {
        return res.status(400).json({ error: 'public_token is required.' });
      }

      const response = await plaidClient.itemPublicTokenExchange({
        public_token: public_token.trim(),
      });

      // Store the access token by user ID so each signed-in user keeps their own Plaid connection.
      await saveAccessToken(req.userId, response.data.access_token, response.data.item_id);

      // Log only the user ID, never the secret access token itself.
      console.log(`Plaid access token saved for user ${req.userId}`);

      res.json({ success: true });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  // transactionsSync returns incremental transaction updates from Plaid and is Plaid's recommended approach for fetching transactions.
  app.get('/fetch-transactions', requireApiKey, requireUserId, async (req, res) => {
    try {
      const accessToken = await getAccessToken(req.userId);

      if (!accessToken) {
        return res.status(400).json({ error: 'No access token - reconnect your bank.' });
      }

      const startingCursor = await getSyncCursor(req.userId);
      const {
        added,
        modified,
        removed,
        nextCursor,
        transactionsUpdateStatus,
      } = await fetchTransactionUpdates(accessToken, startingCursor, 1, plaidClient);

      if (nextCursor) {
        // Save the cursor only after every page was fetched successfully.
        await saveSyncCursor(req.userId, nextCursor);
      }

      res.json({
        // Keep transactions for older app code while newer app code reads the full sync shape.
        transactions: added,
        added,
        modified,
        removed,
        next_cursor: nextCursor,
        transactions_update_status: transactionsUpdateStatus,
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  // Lets the iOS app check whether a Plaid webhook has marked transactions as stale.
  app.get('/transactions-refresh-status', requireApiKey, requireUserId, async (req, res) => {
    try {
      res.json({ refresh_needed: await getTransactionsRefreshNeeded(req.userId) });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  // Receives notifications from Plaid when new transaction data is available.
  app.post('/webhook', verifyPlaidWebhook, async (req, res) => {
    try {
      console.log('Plaid webhook received:', {
        webhook_type: req.body.webhook_type,
        webhook_code: req.body.webhook_code,
        item_id: req.body.item_id,
      });

      if (
        req.body.webhook_type === 'TRANSACTIONS' &&
        transactionUpdateWebhookCodes.has(req.body.webhook_code)
      ) {
        if (typeof req.body.item_id !== 'string' || req.body.item_id.trim().length === 0) {
          console.log('Transaction webhook did not include an item_id, so no user was marked stale.');
          return res.json({ received: true });
        }

        const userId = await getUserIdForItemId(req.body.item_id.trim());

        if (userId) {
          await markTransactionsRefreshNeeded(userId, true);
          console.log(`New transaction data available for user ${userId} - app should refresh`);
        } else {
          console.log('New transaction data available, but no matching user was found for this item_id.');
        }
      }

      res.json({ received: true });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  return app;
}

function isEnabled(value) {
  return enabledValues.has(value?.trim().toLowerCase());
}

function validateProductionEnvironment(env = process.env) {
  if (env.NODE_ENV !== 'production') {
    return;
  }

  const errors = [];
  const authMode = env.AUTH_MODE?.trim().toLowerCase() || 'user-session';
  const tokenStoreBackend = env.TOKEN_STORE_BACKEND?.trim().toLowerCase();

  if (authMode !== 'user-session') {
    errors.push('AUTH_MODE must be user-session.');
  }

  if (!env.SESSION_JWT_SECRET?.trim()) {
    errors.push('SESSION_JWT_SECRET is required.');
  }

  if (tokenStoreBackend !== 'postgres') {
    errors.push('TOKEN_STORE_BACKEND must be postgres.');
  }

  if (!env.DATABASE_URL?.trim() && !env.POSTGRES_URL?.trim()) {
    errors.push('DATABASE_URL or POSTGRES_URL is required.');
  }

  if (!isEnabled(env.PLAID_WEBHOOK_VERIFICATION)) {
    errors.push('PLAID_WEBHOOK_VERIFICATION must be true.');
  }

  if (errors.length > 0) {
    throw new Error(`Production configuration error: ${errors.join(' ')}`);
  }
}

if (require.main === module) {
  validateProductionEnvironment();

  createApp().listen(port, () => {
    console.log(`Cash Flow server running on port ${port}`);
  });
}

module.exports = {
  createApp,
  exchangeAppleSession,
  fetchTransactionUpdates,
  plaidErrorCode,
  validateProductionEnvironment,
};
