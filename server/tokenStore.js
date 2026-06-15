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

function saveAccessToken(userId, accessToken, itemId) {
  const store = readStore();
  store.users[userId] = {
    access_token: accessToken,
    item_id: itemId ?? store.users[userId]?.item_id ?? null,
    sync_cursor: null,
    transactions_refresh_needed: false,
  };
  writeStore(store);
}

function getAccessToken(userId) {
  return getUserRecord(userId)?.access_token ?? null;
}

function getSyncCursor(userId) {
  return getUserRecord(userId)?.sync_cursor ?? null;
}

function getUserIdForItemId(itemId) {
  const store = readStore();

  for (const [userId, record] of Object.entries(store.users)) {
    if (record.item_id === itemId) {
      return userId;
    }
  }

  return null;
}

function markTransactionsRefreshNeeded(userId, isNeeded) {
  const store = readStore();
  const existing = store.users[userId];

  if (!existing?.access_token) {
    return false;
  }

  store.users[userId] = {
    ...existing,
    transactions_refresh_needed: isNeeded,
  };
  writeStore(store);
  return true;
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
    transactions_refresh_needed: false,
  };
  writeStore(store);
  return true;
}

module.exports = {
  getAccessToken,
  getSyncCursor,
  getUserIdForItemId,
  markTransactionsRefreshNeeded,
  saveAccessToken,
  saveSyncCursor,
};
