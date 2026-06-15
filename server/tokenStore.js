const fs = require('fs');
const path = require('path');

const tokensFilePath = path.join(__dirname, 'tokens.json');

function emptyStore() {
  return { users: {} };
}

function readStore() {
  if (!fs.existsSync(tokensFilePath)) {
    return emptyStore();
  }

  try {
    const parsed = JSON.parse(fs.readFileSync(tokensFilePath, 'utf8'));

    // Older deployments stored a single global access_token at the root.
    // Migrate that shape into per-user storage so existing links keep working.
    if (parsed.access_token && !parsed.users) {
      return {
        users: {
          'legacy-user': {
            access_token: parsed.access_token,
            sync_cursor: null,
          },
        },
      };
    }

    if (!parsed.users || typeof parsed.users !== 'object') {
      return emptyStore();
    }

    return parsed;
  } catch {
    return emptyStore();
  }
}

function writeStore(store) {
  const tempFilePath = `${tokensFilePath}.tmp`;
  fs.writeFileSync(tempFilePath, JSON.stringify(store, null, 2));
  fs.renameSync(tempFilePath, tokensFilePath);
}

function getUserRecord(userId) {
  const store = readStore();
  return store.users[userId] ?? null;
}

function saveAccessToken(userId, accessToken) {
  const store = readStore();
  store.users[userId] = {
    access_token: accessToken,
    sync_cursor: store.users[userId]?.sync_cursor ?? null,
  };
  writeStore(store);
}

function getAccessToken(userId) {
  return getUserRecord(userId)?.access_token ?? null;
}

function getSyncCursor(userId) {
  return getUserRecord(userId)?.sync_cursor ?? null;
}

function saveSyncCursor(userId, syncCursor) {
  const store = readStore();
  const existing = store.users[userId];

  if (!existing?.access_token) {
    return false;
  }

  store.users[userId] = {
    ...existing,
    sync_cursor: syncCursor,
  };
  writeStore(store);
  return true;
}

module.exports = {
  getAccessToken,
  getSyncCursor,
  saveAccessToken,
  saveSyncCursor,
};
