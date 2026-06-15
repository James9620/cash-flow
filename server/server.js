require('dotenv').config();

const express = require('express');
const cors = require('cors');
const { Configuration, PlaidApi, PlaidEnvironments, Products, CountryCode } = require('plaid');
const { requireApiKey, requireUserId } = require('./auth');

const app = express();
const port = process.env.PORT || 3000;
let accessToken = null;

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
      redirect_uri: 'https://cash-flow-production-341d.up.railway.app/oauth-redirect',
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

    // Store the access token in memory for this running server process.
    accessToken = response.data.access_token;

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
    if (!accessToken) {
      return res.status(400).json({ error: 'No access token — reconnect your bank.' });
    }

    const response = await plaidClient.transactionsSync({
      access_token: accessToken,
      count: 100,
    });

    res.json({ transactions: response.data.added });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Receives notifications from Plaid when new transaction data is available.
app.post('/webhook', (req, res) => {
  // Webhook signature verification will be added in Phase 4.
  console.log('PLAID WEBHOOK RECEIVED:', JSON.stringify(req.body, null, 2));
  if (req.body.webhook_type === 'TRANSACTIONS') {
    console.log('New transaction data available — app should refresh');
  }

  res.json({ received: true });
});

app.listen(port, () => {
  console.log(`Cash Flow server running on port ${port}`);
});
