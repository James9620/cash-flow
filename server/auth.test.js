const test = require('node:test');
const assert = require('node:assert/strict');

process.env.AUTH_MODE = 'user-session';
process.env.SESSION_JWT_SECRET = 'test-session-secret';
process.env.SESSION_JWT_ISSUER = 'cash-flow-server';
process.env.SESSION_JWT_AUDIENCE = 'com.jameslarkin.cashflow';
process.env.TOKEN_STORE_BACKEND = 'json';

const { createUserSessionToken, requireApiKey, verifyUserSessionToken } = require('./auth');
const { exchangeAppleSession, validateProductionEnvironment } = require('./server');

function callRequireApiKey(headers = {}) {
  return new Promise((resolve) => {
    const req = {
      headers,
      body: {},
      query: {},
    };
    const res = {
      statusCode: 200,
      status(statusCode) {
        this.statusCode = statusCode;
        return this;
      },
      json(body) {
        resolve({ status: this.statusCode, body });
      },
    };

    requireApiKey(req, res, () => {
      resolve({
        status: 200,
        authenticatedUserId: req.authenticatedUserId,
      });
    });
  });
}

test('Apple session exchange returns a Cash Flow session token', async () => {
  const response = await exchangeAppleSession(
    {
      identity_token: 'apple-token',
      raw_nonce: 'raw-nonce',
    },
    async (identityToken, rawNonce) => {
      assert.equal(identityToken, 'apple-token');
      assert.equal(rawNonce, 'raw-nonce');
      return { sub: 'apple-user-123' };
    },
  );

  assert.equal(response.user_id, 'apple-user-123');
  assert.equal(verifyUserSessionToken(response.session_token), 'apple-user-123');
  assert.match(response.expires_at, /^\d{4}-\d{2}-\d{2}T/);
});

test('Apple session exchange rejects invalid Apple identity tokens', async () => {
  await assert.rejects(
    () => exchangeAppleSession(
      {
        identity_token: 'bad-token',
        raw_nonce: 'raw-nonce',
      },
      async () => {
        throw new Error('invalid apple token');
      },
    ),
    /invalid apple token/,
  );
});

test('protected routes reject requests without a session token', async () => {
  const response = await callRequireApiKey();

  assert.equal(response.status, 401);
  assert.deepEqual(response.body, { error: 'Unauthorized' });
});

test('protected routes accept a valid app session token', async () => {
  const { token } = createUserSessionToken('apple-user-123');
  const response = await callRequireApiKey({
    authorization: `Bearer ${token}`,
  });

  assert.equal(response.status, 200);
  assert.equal(response.authenticatedUserId, 'apple-user-123');
});

test('production requires app sessions, Postgres, and webhook verification', () => {
  assert.throws(
    () => validateProductionEnvironment({
      NODE_ENV: 'production',
      AUTH_MODE: 'user-session',
      SESSION_JWT_SECRET: 'secret',
      TOKEN_STORE_BACKEND: 'json',
      DATABASE_URL: 'postgres://example',
      PLAID_WEBHOOK_VERIFICATION: 'true',
    }),
    /TOKEN_STORE_BACKEND must be postgres/,
  );

  assert.throws(
    () => validateProductionEnvironment({
      NODE_ENV: 'production',
      AUTH_MODE: 'user-session',
      SESSION_JWT_SECRET: 'secret',
      TOKEN_STORE_BACKEND: 'postgres',
      DATABASE_URL: 'postgres://example',
      PLAID_WEBHOOK_VERIFICATION: 'false',
    }),
    /PLAID_WEBHOOK_VERIFICATION must be true/,
  );
});

test('production rejects shared-secret auth mode', () => {
  assert.throws(
    () => validateProductionEnvironment({
      NODE_ENV: 'production',
      AUTH_MODE: 'development-shared-secret',
      SESSION_JWT_SECRET: 'secret',
      TOKEN_STORE_BACKEND: 'postgres',
      DATABASE_URL: 'postgres://example',
      PLAID_WEBHOOK_VERIFICATION: 'true',
    }),
    /AUTH_MODE must be user-session/,
  );
});

test('production accepts the required hardened configuration', () => {
  assert.doesNotThrow(() => validateProductionEnvironment({
    NODE_ENV: 'production',
    AUTH_MODE: 'user-session',
    SESSION_JWT_SECRET: 'secret',
    TOKEN_STORE_BACKEND: 'postgres',
    DATABASE_URL: 'postgres://example',
    PLAID_WEBHOOK_VERIFICATION: 'true',
  }));
});
