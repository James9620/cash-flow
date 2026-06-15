function requireApiKey(req, res, next) {
  const expectedKey = process.env.API_SECRET_KEY;

  if (!expectedKey) {
    return res.status(500).json({
      error: 'Server is missing API_SECRET_KEY configuration.',
    });
  }

  const authHeader = req.headers.authorization;
  const providedKey = authHeader?.startsWith('Bearer ')
    ? authHeader.slice('Bearer '.length)
    : null;

  if (!providedKey || providedKey !== expectedKey) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  next();
}

function requireUserId(req, res, next) {
  const userId = req.body?.user_id ?? req.query?.user_id;

  if (typeof userId !== 'string' || userId.trim().length === 0) {
    return res.status(400).json({ error: 'user_id is required.' });
  }

  // Attach the validated user ID so route handlers do not re-read request fields.
  req.userId = userId.trim();
  next();
}

module.exports = {
  requireApiKey,
  requireUserId,
};
