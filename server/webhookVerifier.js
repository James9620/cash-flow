const crypto = require('crypto');

const enabledValues = new Set(['1', 'true', 'yes', 'required', 'enabled']);
const configuredMaxWebhookAgeSeconds = Number(process.env.PLAID_WEBHOOK_MAX_AGE_SECONDS ?? 300);
const maxWebhookAgeSeconds = Number.isFinite(configuredMaxWebhookAgeSeconds)
  ? configuredMaxWebhookAgeSeconds
  : 300;
const configuredKeyCacheTtlMs = Number(process.env.PLAID_WEBHOOK_KEY_CACHE_MS ?? 60 * 60 * 1000);
const keyCacheTtlMs = Number.isFinite(configuredKeyCacheTtlMs)
  ? configuredKeyCacheTtlMs
  : 60 * 60 * 1000;
const verificationKeyCache = new Map();

let warnedAboutDisabledVerification = false;

function isWebhookVerificationEnabled() {
  const configuredValue = process.env.PLAID_WEBHOOK_VERIFICATION?.trim().toLowerCase();
  return enabledValues.has(configuredValue);
}

function decodeBase64Url(value) {
  return Buffer.from(value, 'base64url');
}

function decodeJwtPart(value) {
  return JSON.parse(decodeBase64Url(value).toString('utf8'));
}

function timingSafeEqualString(left, right) {
  const leftBuffer = Buffer.from(left);
  const rightBuffer = Buffer.from(right);

  if (leftBuffer.length !== rightBuffer.length) {
    return false;
  }

  return crypto.timingSafeEqual(leftBuffer, rightBuffer);
}

function getWebhookToken(req) {
  const token = req.get('Plaid-Verification');

  if (!token) {
    throw new Error('Missing Plaid-Verification header.');
  }

  return token;
}

function getSafePublicJwk(key) {
  return {
    kty: key.kty,
    crv: key.crv,
    x: key.x,
    y: key.y,
    use: key.use,
    kid: key.kid,
    alg: key.alg,
  };
}

async function getWebhookVerificationKey(plaidClient, keyId) {
  const cached = verificationKeyCache.get(keyId);
  const now = Math.floor(Date.now() / 1000);
  const cacheIsFresh = cached && Date.now() - cached.cachedAt < keyCacheTtlMs;

  if (cacheIsFresh && (!cached.key.expired_at || cached.key.expired_at > now)) {
    return cached.key;
  }

  const response = await plaidClient.webhookVerificationKeyGet({ key_id: keyId });
  const key = response.data?.key;

  if (!key) {
    throw new Error('Plaid did not return a webhook verification key.');
  }

  if (key.expired_at && key.expired_at <= now) {
    throw new Error('Plaid webhook verification key is expired.');
  }

  verificationKeyCache.set(keyId, { key, cachedAt: Date.now() });
  return key;
}

function verifyIssuedAt(payload) {
  const issuedAt = Number(payload.iat);
  const now = Math.floor(Date.now() / 1000);

  if (!Number.isFinite(issuedAt)) {
    throw new Error('Webhook verification token is missing iat.');
  }

  if (issuedAt > now + 60) {
    throw new Error('Webhook verification token is from the future.');
  }

  // Plaid recommends rejecting old webhook tokens to reduce replay risk.
  if (now - issuedAt > maxWebhookAgeSeconds) {
    throw new Error('Webhook verification token is too old.');
  }
}

function verifyRequestBodyHash(req, payload) {
  const expectedHash = payload.request_body_sha256;

  if (typeof expectedHash !== 'string') {
    throw new Error('Webhook verification token is missing request_body_sha256.');
  }

  if (!req.rawBody) {
    throw new Error('Raw webhook body was not captured before JSON parsing.');
  }

  const actualHash = crypto.createHash('sha256').update(req.rawBody).digest('hex');

  if (!timingSafeEqualString(actualHash, expectedHash)) {
    throw new Error('Webhook request body hash does not match the verification token.');
  }
}

function verifyJwtSignature(token, header, key) {
  const [encodedHeader, encodedPayload, encodedSignature] = token.split('.');

  if (!encodedHeader || !encodedPayload || !encodedSignature) {
    throw new Error('Plaid-Verification header is not a valid JWT.');
  }

  if (header.alg !== key.alg) {
    throw new Error('Webhook verification token algorithm does not match Plaid key.');
  }

  if (header.alg !== 'ES256') {
    throw new Error(`Unsupported Plaid webhook signing algorithm: ${header.alg}`);
  }

  const signingInput = Buffer.from(`${encodedHeader}.${encodedPayload}`);
  const signature = decodeBase64Url(encodedSignature);
  const publicKey = crypto.createPublicKey({
    key: getSafePublicJwk(key),
    format: 'jwk',
  });

  const isValid = crypto.verify(
    'sha256',
    signingInput,
    { key: publicKey, dsaEncoding: 'ieee-p1363' },
    signature,
  );

  if (!isValid) {
    throw new Error('Webhook verification token signature is invalid.');
  }
}

async function verifyPlaidWebhook(req, plaidClient) {
  const token = getWebhookToken(req);
  const [encodedHeader, encodedPayload] = token.split('.');

  if (!encodedHeader || !encodedPayload) {
    throw new Error('Plaid-Verification header is not a valid JWT.');
  }

  const header = decodeJwtPart(encodedHeader);
  const payload = decodeJwtPart(encodedPayload);

  if (typeof header.kid !== 'string' || header.kid.length === 0) {
    throw new Error('Webhook verification token is missing kid.');
  }

  verifyIssuedAt(payload);
  verifyRequestBodyHash(req, payload);

  const key = await getWebhookVerificationKey(plaidClient, header.kid);
  verifyJwtSignature(token, header, key);
}

function createPlaidWebhookVerifier(plaidClient) {
  return async function plaidWebhookVerifier(req, res, next) {
    if (!isWebhookVerificationEnabled()) {
      if (process.env.NODE_ENV === 'production' && !warnedAboutDisabledVerification) {
        warnedAboutDisabledVerification = true;
        console.warn(
          'PLAID_WEBHOOK_VERIFICATION is not enabled; Plaid webhooks are accepted without signature verification.',
        );
      }

      return next();
    }

    try {
      await verifyPlaidWebhook(req, plaidClient);
      return next();
    } catch (error) {
      console.warn(`Rejected Plaid webhook: ${error.message}`);
      return res.status(401).json({ error: 'Invalid Plaid webhook signature.' });
    }
  };
}

module.exports = {
  createPlaidWebhookVerifier,
};
