const crypto = require('crypto');
const https = require('https');

const appleJwksUrl = 'https://appleid.apple.com/auth/keys';
let cachedAppleJwks = null;

class AppleAuthError extends Error {}

function getAppleAudience() {
  return process.env.APPLE_BUNDLE_ID?.trim() || 'com.jameslarkin.cashflow';
}

function decodeBase64Url(value) {
  return Buffer.from(value, 'base64url');
}

function decodeJwtPart(value) {
  try {
    return JSON.parse(decodeBase64Url(value).toString('utf8'));
  } catch {
    throw new AppleAuthError('Apple identity token contains invalid JSON.');
  }
}

function parseJwt(token) {
  const parts = token.split('.');

  if (parts.length !== 3 || parts.some((part) => part.length === 0)) {
    throw new AppleAuthError('Apple identity token is not a valid JWT.');
  }

  return {
    header: decodeJwtPart(parts[0]),
    payload: decodeJwtPart(parts[1]),
    signature: decodeBase64Url(parts[2]),
    signingInput: `${parts[0]}.${parts[1]}`,
  };
}

function fetchJson(urlString) {
  return new Promise((resolve, reject) => {
    const request = https.get(urlString, { timeout: 5000 }, (response) => {
      if (response.statusCode < 200 || response.statusCode >= 300) {
        response.resume();
        reject(new AppleAuthError(`Apple JWKS returned ${response.statusCode}.`));
        return;
      }

      let body = '';
      response.setEncoding('utf8');

      response.on('data', (chunk) => {
        body += chunk;
      });

      response.on('end', () => {
        try {
          resolve(JSON.parse(body));
        } catch {
          reject(new AppleAuthError('Apple JWKS did not return JSON.'));
        }
      });
    });

    request.on('timeout', () => {
      request.destroy(new AppleAuthError('Timed out while fetching Apple JWKS.'));
    });

    request.on('error', (error) => {
      reject(error instanceof AppleAuthError
        ? error
        : new AppleAuthError(`Unable to fetch Apple JWKS: ${error.message}`));
    });
  });
}

async function getAppleJwks() {
  const now = Date.now();
  const cacheTtlMs = 60 * 60 * 1000;

  if (cachedAppleJwks && now - cachedAppleJwks.cachedAt < cacheTtlMs) {
    return cachedAppleJwks.keys;
  }

  const jwks = await fetchJson(appleJwksUrl);

  if (!Array.isArray(jwks.keys)) {
    throw new AppleAuthError('Apple JWKS response is missing keys.');
  }

  cachedAppleJwks = { keys: jwks.keys, cachedAt: now };
  return jwks.keys;
}

function timingSafeEqualBuffer(left, right) {
  if (left.length !== right.length) {
    return false;
  }

  return crypto.timingSafeEqual(left, right);
}

async function verifyAppleSignature(parsedJwt) {
  if (parsedJwt.header.alg !== 'RS256') {
    throw new AppleAuthError('Apple identity token must use RS256.');
  }

  if (typeof parsedJwt.header.kid !== 'string') {
    throw new AppleAuthError('Apple identity token is missing kid.');
  }

  const keys = await getAppleJwks();
  const jwk = keys.find((key) => key.kid === parsedJwt.header.kid);

  if (!jwk) {
    throw new AppleAuthError('Apple signing key was not found.');
  }

  const publicKey = crypto.createPublicKey({ key: jwk, format: 'jwk' });
  const isValid = crypto.verify(
    'sha256',
    Buffer.from(parsedJwt.signingInput),
    { key: publicKey },
    parsedJwt.signature,
  );

  if (!isValid) {
    throw new AppleAuthError('Apple identity token signature is invalid.');
  }
}

function expectedNonce(rawNonce) {
  return crypto.createHash('sha256').update(rawNonce).digest('hex');
}

function verifyAppleClaims(payload, rawNonce) {
  const now = Math.floor(Date.now() / 1000);
  const audience = getAppleAudience();

  if (payload.iss !== 'https://appleid.apple.com') {
    throw new AppleAuthError('Apple identity token issuer is invalid.');
  }

  const audiences = Array.isArray(payload.aud) ? payload.aud : [payload.aud];

  if (!audiences.includes(audience)) {
    throw new AppleAuthError('Apple identity token audience is invalid.');
  }

  if (Number(payload.exp) <= now) {
    throw new AppleAuthError('Apple identity token has expired.');
  }

  if (Number(payload.iat) > now + 60) {
    throw new AppleAuthError('Apple identity token was issued in the future.');
  }

  if (typeof payload.sub !== 'string' || payload.sub.trim().length === 0) {
    throw new AppleAuthError('Apple identity token subject is missing.');
  }

  if (payload.nonce !== expectedNonce(rawNonce)) {
    throw new AppleAuthError('Apple identity token nonce is invalid.');
  }

  return {
    sub: payload.sub.trim(),
    email: typeof payload.email === 'string' ? payload.email : null,
  };
}

async function verifyAppleIdentityToken(identityToken, rawNonce) {
  if (typeof identityToken !== 'string' || identityToken.trim().length === 0) {
    throw new AppleAuthError('identity_token is required.');
  }

  if (typeof rawNonce !== 'string' || rawNonce.trim().length === 0) {
    throw new AppleAuthError('raw_nonce is required.');
  }

  const parsedJwt = parseJwt(identityToken.trim());
  await verifyAppleSignature(parsedJwt);
  return verifyAppleClaims(parsedJwt.payload, rawNonce.trim());
}

module.exports = {
  AppleAuthError,
  verifyAppleIdentityToken,
};
