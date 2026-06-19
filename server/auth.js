const crypto = require('crypto');
const http = require('http');
const https = require('https');

const sharedSecretAuthModes = new Set(['shared-secret', 'development-shared-secret']);
const jwtAlgorithms = new Map([
  ['HS256', { type: 'hmac', hash: 'sha256' }],
  ['HS384', { type: 'hmac', hash: 'sha384' }],
  ['HS512', { type: 'hmac', hash: 'sha512' }],
  ['RS256', { type: 'asymmetric', hash: 'sha256' }],
  ['RS384', { type: 'asymmetric', hash: 'sha384' }],
  ['RS512', { type: 'asymmetric', hash: 'sha512' }],
  ['ES256', { type: 'asymmetric', hash: 'sha256', dsaEncoding: 'ieee-p1363' }],
  ['ES384', { type: 'asymmetric', hash: 'sha384', dsaEncoding: 'ieee-p1363' }],
  ['ES512', { type: 'asymmetric', hash: 'sha512', dsaEncoding: 'ieee-p1363' }],
  [
    'PS256',
    {
      type: 'asymmetric',
      hash: 'sha256',
      padding: crypto.constants.RSA_PKCS1_PSS_PADDING,
      saltLength: crypto.constants.RSA_PSS_SALTLEN_DIGEST,
    },
  ],
  [
    'PS384',
    {
      type: 'asymmetric',
      hash: 'sha384',
      padding: crypto.constants.RSA_PKCS1_PSS_PADDING,
      saltLength: crypto.constants.RSA_PSS_SALTLEN_DIGEST,
    },
  ],
  [
    'PS512',
    {
      type: 'asymmetric',
      hash: 'sha512',
      padding: crypto.constants.RSA_PKCS1_PSS_PADDING,
      saltLength: crypto.constants.RSA_PSS_SALTLEN_DIGEST,
    },
  ],
]);

let warnedAboutProductionSharedSecret = false;
let cachedJwks = null;

function getAuthMode() {
  return process.env.AUTH_MODE?.trim().toLowerCase() || 'user-token';
}

function getBearerToken(req) {
  const authHeader = req.headers.authorization;

  if (typeof authHeader !== 'string') {
    return null;
  }

  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  return match ? match[1].trim() : null;
}

class JwtConfigurationError extends Error {}

class JwtValidationError extends Error {}

function getRequiredConfig(name) {
  const value = process.env[name]?.trim();

  if (!value) {
    throw new JwtConfigurationError(`Server is missing ${name} configuration.`);
  }

  return value;
}

function getPositiveNumberConfig(name, fallback) {
  const configuredValue = process.env[name];

  if (configuredValue === undefined) {
    return fallback;
  }

  const parsedValue = Number(configuredValue);
  return Number.isFinite(parsedValue) && parsedValue > 0 ? parsedValue : fallback;
}

function getCommaSeparatedConfig(name) {
  return process.env[name]
    ?.split(',')
    .map((value) => value.trim())
    .filter(Boolean) ?? [];
}

function getAllowedJwtAlgorithms() {
  const configuredAlgorithms = getCommaSeparatedConfig('JWT_ALLOWED_ALGORITHMS');
  const allowedAlgorithms = configuredAlgorithms.length > 0 ? configuredAlgorithms : ['RS256'];

  for (const algorithm of allowedAlgorithms) {
    if (!jwtAlgorithms.has(algorithm)) {
      throw new JwtConfigurationError(`Unsupported JWT algorithm configured: ${algorithm}`);
    }
  }

  return new Set(allowedAlgorithms);
}

function decodeBase64Url(value) {
  try {
    // JWTs use base64url, which is regular base64 made safe for URLs.
    return Buffer.from(value, 'base64url');
  } catch {
    throw new JwtValidationError('JWT contains invalid base64url data.');
  }
}

function decodeJwtJsonPart(value) {
  try {
    return JSON.parse(decodeBase64Url(value).toString('utf8'));
  } catch {
    throw new JwtValidationError('JWT contains invalid JSON.');
  }
}

function parseJwt(token) {
  const parts = token.split('.');

  if (parts.length !== 3 || parts.some((part) => part.length === 0)) {
    throw new JwtValidationError('Bearer token is not a valid JWT.');
  }

  const [encodedHeader, encodedPayload, encodedSignature] = parts;

  return {
    header: decodeJwtJsonPart(encodedHeader),
    payload: decodeJwtJsonPart(encodedPayload),
    signature: decodeBase64Url(encodedSignature),
    signingInput: `${encodedHeader}.${encodedPayload}`,
  };
}

function timingSafeEqualBuffer(left, right) {
  if (left.length !== right.length) {
    return false;
  }

  return crypto.timingSafeEqual(left, right);
}

function timingSafeEqualString(left, right) {
  return timingSafeEqualBuffer(Buffer.from(left), Buffer.from(right));
}

function getConfiguredPublicKey() {
  const publicKey = process.env.JWT_PUBLIC_KEY?.replace(/\\n/g, '\n');
  const publicKeyBase64 = process.env.JWT_PUBLIC_KEY_BASE64;

  if (publicKey) {
    return publicKey;
  }

  if (publicKeyBase64) {
    return Buffer.from(publicKeyBase64, 'base64').toString('utf8');
  }

  return null;
}

function getJwksUrl() {
  const configuredUrl = process.env.JWT_JWKS_URL?.trim() ?? process.env.JWT_JWKS_URI?.trim();

  if (!configuredUrl) {
    return null;
  }

  let url;

  try {
    url = new URL(configuredUrl);
  } catch {
    throw new JwtConfigurationError('JWT_JWKS_URL is not a valid URL.');
  }

  const allowInsecureJwks =
    process.env.NODE_ENV !== 'production' &&
    process.env.JWT_ALLOW_INSECURE_JWKS_URL?.trim().toLowerCase() === 'true';

  if (url.protocol !== 'https:' && !(allowInsecureJwks && url.protocol === 'http:')) {
    throw new JwtConfigurationError('JWT_JWKS_URL must use https.');
  }

  return url.toString();
}

function fetchJson(urlString, redirectCount = 0) {
  return new Promise((resolve, reject) => {
    const url = new URL(urlString);
    const client = url.protocol === 'http:' ? http : https;
    const timeoutMs = getPositiveNumberConfig('JWT_JWKS_TIMEOUT_MS', 5000);

    const request = client.get(url, { timeout: timeoutMs }, (response) => {
      const location = response.headers.location;

      if (
        response.statusCode >= 300 &&
        response.statusCode < 400 &&
        location &&
        redirectCount < 3
      ) {
        response.resume();
        resolve(fetchJson(new URL(location, url).toString(), redirectCount + 1));
        return;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        response.resume();
        reject(new JwtConfigurationError(`JWT_JWKS_URL returned ${response.statusCode}.`));
        return;
      }

      let body = '';
      response.setEncoding('utf8');

      response.on('data', (chunk) => {
        body += chunk;

        if (body.length > 1024 * 1024) {
          request.destroy(new JwtConfigurationError('JWT_JWKS_URL response is too large.'));
        }
      });

      response.on('end', () => {
        try {
          resolve(JSON.parse(body));
        } catch {
          reject(new JwtConfigurationError('JWT_JWKS_URL did not return JSON.'));
        }
      });
    });

    request.on('timeout', () => {
      request.destroy(new JwtConfigurationError('Timed out while fetching JWT_JWKS_URL.'));
    });

    request.on('error', (error) => {
      reject(error instanceof JwtConfigurationError
        ? error
        : new JwtConfigurationError(`Unable to fetch JWT_JWKS_URL: ${error.message}`));
    });
  });
}

async function getJwks(forceRefresh = false) {
  const jwksUrl = getJwksUrl();

  if (!jwksUrl) {
    throw new JwtConfigurationError(
      'Server is missing JWT_PUBLIC_KEY, JWT_PUBLIC_KEY_BASE64, or JWT_JWKS_URL configuration.',
    );
  }

  const cacheTtlMs = getPositiveNumberConfig('JWT_JWKS_CACHE_MS', 60 * 60 * 1000);
  const cacheIsFresh =
    cachedJwks &&
    cachedJwks.url === jwksUrl &&
    Date.now() - cachedJwks.cachedAt < cacheTtlMs;

  if (cacheIsFresh && !forceRefresh) {
    return cachedJwks.keys;
  }

  const jwks = await fetchJson(jwksUrl);

  if (!Array.isArray(jwks.keys)) {
    throw new JwtConfigurationError('JWT_JWKS_URL response must contain a keys array.');
  }

  // JWKS keys rotate over time, so cache them briefly instead of fetching every request.
  cachedJwks = {
    url: jwksUrl,
    keys: jwks.keys,
    cachedAt: Date.now(),
  };

  return cachedJwks.keys;
}

function getSafePublicJwk(jwk) {
  return {
    kty: jwk.kty,
    kid: jwk.kid,
    use: jwk.use,
    key_ops: jwk.key_ops,
    alg: jwk.alg,
    n: jwk.n,
    e: jwk.e,
    crv: jwk.crv,
    x: jwk.x,
    y: jwk.y,
  };
}

async function getPublicKeyForJwt(header) {
  const configuredPublicKey = getConfiguredPublicKey();

  if (configuredPublicKey) {
    try {
      return crypto.createPublicKey(configuredPublicKey);
    } catch {
      throw new JwtConfigurationError('JWT_PUBLIC_KEY is not a valid public key.');
    }
  }

  if (typeof header.kid !== 'string' || header.kid.length === 0) {
    throw new JwtValidationError('JWT is missing a key id.');
  }

  // The kid tells us which rotated public key signed this token.
  let keys = await getJwks();
  let jwk = keys.find((candidateKey) => candidateKey.kid === header.kid);

  if (!jwk) {
    keys = await getJwks(true);
    jwk = keys.find((candidateKey) => candidateKey.kid === header.kid);
  }

  if (!jwk) {
    throw new JwtValidationError('JWT signing key was not found.');
  }

  if (jwk.use && jwk.use !== 'sig') {
    throw new JwtValidationError('JWT signing key is not meant for signatures.');
  }

  if (jwk.alg && jwk.alg !== header.alg) {
    throw new JwtValidationError('JWT algorithm does not match the signing key.');
  }

  try {
    return crypto.createPublicKey({
      key: getSafePublicJwk(jwk),
      format: 'jwk',
    });
  } catch {
    throw new JwtConfigurationError('JWT signing key from JWKS is not usable.');
  }
}

async function verifyJwtSignature(parsedJwt) {
  const { header, signature, signingInput } = parsedJwt;
  const algorithmName = header.alg;
  const algorithm = jwtAlgorithms.get(algorithmName);

  if (!algorithmName || algorithmName === 'none') {
    throw new JwtValidationError('JWT must be signed.');
  }

  if (!algorithm) {
    throw new JwtValidationError(`Unsupported JWT signing algorithm: ${algorithmName}`);
  }

  if (!getAllowedJwtAlgorithms().has(algorithmName)) {
    throw new JwtValidationError('JWT signing algorithm is not allowed.');
  }

  if (algorithm.type === 'hmac') {
    const secret = getRequiredConfig('JWT_SECRET');
    const expectedSignature = crypto
      .createHmac(algorithm.hash, secret)
      .update(signingInput)
      .digest();

    if (!timingSafeEqualBuffer(expectedSignature, signature)) {
      throw new JwtValidationError('JWT signature is invalid.');
    }

    return;
  }

  const publicKey = await getPublicKeyForJwt(header);
  const verifyOptions = { key: publicKey };

  if (algorithm.dsaEncoding) {
    verifyOptions.dsaEncoding = algorithm.dsaEncoding;
  }

  if (algorithm.padding) {
    verifyOptions.padding = algorithm.padding;
    verifyOptions.saltLength = algorithm.saltLength;
  }

  const isSignatureValid = crypto.verify(
    algorithm.hash,
    Buffer.from(signingInput),
    verifyOptions,
    signature,
  );

  if (!isSignatureValid) {
    throw new JwtValidationError('JWT signature is invalid.');
  }
}

function getTokenAudiences(payload) {
  if (typeof payload.aud === 'string') {
    return [payload.aud];
  }

  if (Array.isArray(payload.aud)) {
    return payload.aud.filter((audience) => typeof audience === 'string');
  }

  return [];
}

function getNumericJwtClaim(payload, claimName) {
  const value = Number(payload[claimName]);

  if (!Number.isFinite(value)) {
    throw new JwtValidationError(`JWT is missing ${claimName}.`);
  }

  return value;
}

function getOptionalNumericJwtClaim(payload, claimName) {
  if (payload[claimName] === undefined) {
    return null;
  }

  const value = Number(payload[claimName]);

  if (!Number.isFinite(value)) {
    throw new JwtValidationError(`JWT ${claimName} is invalid.`);
  }

  return value;
}

function verifyJwtClaims(payload) {
  const expectedIssuer = getRequiredConfig('JWT_ISSUER');
  const expectedAudiences = getCommaSeparatedConfig('JWT_AUDIENCE');
  const now = Math.floor(Date.now() / 1000);
  const clockSkewSeconds = getPositiveNumberConfig('JWT_CLOCK_SKEW_SECONDS', 60);

  if (expectedAudiences.length === 0) {
    throw new JwtConfigurationError('Server is missing JWT_AUDIENCE configuration.');
  }

  if (payload.iss !== expectedIssuer) {
    throw new JwtValidationError('JWT issuer is invalid.');
  }

  if (!getTokenAudiences(payload).some((audience) => expectedAudiences.includes(audience))) {
    throw new JwtValidationError('JWT audience is invalid.');
  }

  // A little clock skew prevents false failures when devices and servers differ by seconds.
  if (getNumericJwtClaim(payload, 'exp') <= now - clockSkewSeconds) {
    throw new JwtValidationError('JWT has expired.');
  }

  const notBefore = getOptionalNumericJwtClaim(payload, 'nbf');
  const issuedAt = getOptionalNumericJwtClaim(payload, 'iat');

  if (notBefore !== null && notBefore > now + clockSkewSeconds) {
    throw new JwtValidationError('JWT is not valid yet.');
  }

  if (issuedAt !== null && issuedAt > now + clockSkewSeconds) {
    throw new JwtValidationError('JWT was issued in the future.');
  }

  const maxAgeSeconds = process.env.JWT_MAX_AGE_SECONDS
    ? getPositiveNumberConfig('JWT_MAX_AGE_SECONDS', null)
    : null;

  if (maxAgeSeconds) {
    if (issuedAt === null) {
      throw new JwtValidationError('JWT is missing iat.');
    }

    if (now - issuedAt > maxAgeSeconds + clockSkewSeconds) {
      throw new JwtValidationError('JWT is too old.');
    }
  }

  if (typeof payload.sub !== 'string' || payload.sub.trim().length === 0) {
    throw new JwtValidationError('JWT subject is required.');
  }

  // The subject is the authenticated user ID. Routes compare it with any user_id input below.
  return payload.sub.trim();
}

function requireSharedSecret(req, res, next) {
  const expectedKey = process.env.API_SECRET_KEY;

  if (!expectedKey) {
    return res.status(500).json({
      error: 'Server is missing API_SECRET_KEY configuration.',
    });
  }

  if (
    process.env.NODE_ENV === 'production' &&
    !warnedAboutProductionSharedSecret
  ) {
    warnedAboutProductionSharedSecret = true;
    console.warn(
      'Shared-secret auth is development-only. Set AUTH_MODE=user-token in production.',
    );
  }

  if (process.env.NODE_ENV === 'production') {
    return res.status(500).json({
      error: 'Shared-secret auth is development-only. Set AUTH_MODE=user-token.',
    });
  }

  const providedKey = getBearerToken(req);

  if (!providedKey || !timingSafeEqualString(providedKey, expectedKey)) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  return next();
}

async function requireUserToken(req, res, next) {
  const token = getBearerToken(req);

  if (!token) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  try {
    const parsedJwt = parseJwt(token);

    await verifyJwtSignature(parsedJwt);
    req.authenticatedUserId = verifyJwtClaims(parsedJwt.payload);

    return next();
  } catch (error) {
    if (error instanceof JwtConfigurationError) {
      console.error(`JWT auth configuration error: ${error.message}`);
      return res.status(500).json({ error: 'Server authentication is not configured.' });
    }

    console.warn(`Rejected user JWT: ${error.message}`);
    return res.status(401).json({ error: 'Unauthorized' });
  }
}

function requireApiKey(req, res, next) {
  const authMode = getAuthMode();

  if (sharedSecretAuthModes.has(authMode)) {
    return requireSharedSecret(req, res, next);
  }

  if (authMode === 'user-token') {
    return requireUserToken(req, res, next);
  }

  return res.status(500).json({
    error: `Unsupported AUTH_MODE: ${authMode}`,
  });
}

function requireUserId(req, res, next) {
  const providedUserId = req.body?.user_id ?? req.query?.user_id;

  if (req.authenticatedUserId) {
    if (providedUserId && providedUserId !== req.authenticatedUserId) {
      return res.status(403).json({ error: 'Authenticated user does not match user_id.' });
    }

    req.userId = req.authenticatedUserId;
    return next();
  }

  if (typeof providedUserId !== 'string' || providedUserId.trim().length === 0) {
    return res.status(400).json({ error: 'user_id is required.' });
  }

  // Attach the validated user ID so route handlers do not re-read request fields.
  req.userId = providedUserId.trim();
  return next();
}

module.exports = {
  requireApiKey,
  requireUserId,
};
