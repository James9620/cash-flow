require('dotenv').config();

const express = require('express');
const cors = require('cors');
const { Configuration, PlaidApi, PlaidEnvironments, Products, CountryCode } = require('plaid');

const app = express();
const port = process.env.PORT || 3000;

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
app.post('/create-link-token', async (req, res) => {
  try {
    const { user_id } = req.body;
    const response = await plaidClient.linkTokenCreate({
      user: { client_user_id: user_id },
      client_name: 'Cash Flow',
      products: [Products.Transactions],
      country_codes: [CountryCode.Us],
      language: 'en',
    });

    res.json({ link_token: response.data.link_token });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Called by the iOS app after the user connects their bank. Exchanges a short-lived public_token for a permanent access_token.
app.post('/exchange-public-token', async (req, res) => {
  try {
    const { public_token } = req.body;
    const response = await plaidClient.itemPublicTokenExchange({ public_token });

    // Proper database storage for the access_token will be added in Phase 4.
    console.log('ACCESS TOKEN (save this):', response.data.access_token);

    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Receives notifications from Plaid when new transaction data is available.
app.post('/webhook', (req, res) => {
  // Webhook signature verification will be added in Phase 4.
  console.log('PLAID WEBHOOK RECEIVED:', JSON.stringify(req.body, null, 2));

  res.json({ received: true });
});

app.listen(port, () => {
  console.log(`Cash Flow server running on port ${port}`);
});
