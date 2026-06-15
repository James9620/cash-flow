require('dotenv').config();

const express = require('express');
const cors = require('cors');
const { Configuration, PlaidApi, PlaidEnvironments, Products, CountryCode } = require('plaid');
const { requireApiKey, requireUserId } = require('./auth');
const {
  getAccessToken,
  getSyncCursor,
  getUserIdForItemId,
  markTransactionsRefreshNeeded,
  saveAccessToken,
  saveSyncCursor,
} = require('./tokenStore');

const app = express();
const port = process.env.PORT || 3000;
const syncPageSize = 100;
const plaidRedirectUri = process.env.PLAID_REDIRECT_URI || 'https://cash-flow-production-341d.up.railway.app/oauth-redirect';
const plaidWebhookUrl = process.env.PLAID_WEBHOOK_URL || 'https://cash-flow-production-341d.up.railway.app/webhook';

app.use(cors());
app.use(express.json());

const plaidConfig = new Configuration({
  basePath: PlaidEnvironments[process.env.PLAID_ENV],
  baseOptions: {
    headers: {
      'PLAID-CLIENT-ID': process.env.PLAID_CLIENT_ID,
      'PLAID-SECRET': process.env.PLAID_SECRET,
    },
  },
});
const plaidClient = new PlaidApi(plaidConfig);

// Called by the iOS app to get a temporary token that opens the Plaid bank-connection UI.
app.post('/create-link-token', requireApiKey, requireUserId, async (req, res) => {
  try {
    const response = await plaidClient.linkTokenCreate({
      user: { client_user_id: req.userId },
      client_name: 'Cash Flow',
      products: [Products.Transactions],
      country_codes: [CountryCode.Us],
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

    // Store the access token by user ID so each app install keeps its own Plaid connection.
    saveAccessToken(req.userId, response.data.access_token, response.data.item_id);

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
    const accessToken = getAccessToken(req.userId);

    if (!accessToken) {
      return res.status(400).json({ error: 'No access token — reconnect your bank.' });
    }

    let nextCursor = getSyncCursor(req.userId);
    let hasMore = true;
    const added = [];
    const modified = [];
    const removed = [];

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
    }

    if (nextCursor) {
      saveSyncCursor(req.userId, nextCursor);
    }

    res.json({
      // Keep transactions for older app code while newer app code reads the full sync shape.
      transactions: added,
      added,
      modified,
      removed,
      next_cursor: nextCursor,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Receives notifications from Plaid when new transaction data is available.
app.post('/webhook', (req, res) => {
  // Before production, verify Plaid's webhook signature so only Plaid can trigger this route.
  console.log('PLAID WEBHOOK RECEIVED:', JSON.stringify(req.body, null, 2));
  if (req.body.webhook_type === 'TRANSACTIONS') {
    const userId = getUserIdForItemId(req.body.item_id);

    if (userId) {
      markTransactionsRefreshNeeded(userId, true);
      console.log(`New transaction data available for user ${userId} — app should refresh`);
    } else {
      console.log('New transaction data available, but no matching user was found for this item_id.');
    }
  }

  res.json({ received: true });
});

app.listen(port, () => {
  console.log(`Cash Flow server running on port ${port}`);
});
