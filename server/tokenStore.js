const fs = require('fs/promises');
const path = require('path');

const tokensFilePath = path.join(__dirname, 'tokens.json');
const configuredBackend = process.env.TOKEN_STORE_BACKEND?.trim().toLowerCase();
const databaseUrl = process.env.DATABASE_URL || process.env.POSTGRES_URL;
const shouldUsePostgres =
  configuredBackend === 'postgres' || (!configuredBackend && Boolean(databaseUrl));
const shouldUseJson = configuredBackend === 'json' || !shouldUsePostgres;

let pgPool;
let postgresReadyPromise;
let didTryJsonMigration = false;

function emptyStore() {
  return { users: {} };
}

function normalizeStore(parsed) {
  if (!parsed || typeof parsed !== 'object') {
    return emptyStore();
  }

  // Older deployments stored a single global access_token at the root.
  // This keeps that install usable until its data has been migrated.
  if (parsed.access_token && !parsed.users) {
    return {
      users: {
        'legacy-user': {
          access_token: parsed.access_token,
          item_id: parsed.item_id ?? null,
          sync_cursor: parsed.sync_cursor ?? null,
          transactions_refresh_needed: Boolean(parsed.transactions_refresh_needed),
        },
      },
    };
  }

  if (!parsed.users || typeof parsed.users !== 'object') {
    return emptyStore();
  }

  return parsed;
}

async function readJsonStore() {
  try {
    const fileContents = await fs.readFile(tokensFilePath, 'utf8');
    return normalizeStore(JSON.parse(fileContents));
  } catch (error) {
    if (error.code !== 'ENOENT') {
      console.warn(`Could not read local token store: ${error.message}`);
    }

    return emptyStore();
  }
}

async function writeJsonStore(store) {
  const tempFilePath = `${tokensFilePath}.tmp`;
  await fs.writeFile(tempFilePath, JSON.stringify(store, null, 2));
  await fs.rename(tempFilePath, tokensFilePath);
}

function getPostgresPool() {
  if (pgPool) {
    return pgPool;
  }

  if (!databaseUrl) {
    throw new Error('DATABASE_URL or POSTGRES_URL is required when TOKEN_STORE_BACKEND=postgres.');
  }

  let Pool;

  try {
    ({ Pool } = require('pg'));
  } catch {
    throw new Error(
      'Postgres token storage requires the pg package. Run npm install in server after adding pg to package.json.',
    );
  }

  // Railway exposes a DATABASE_URL. pg understands sslmode in that URL when present.
  pgPool = new Pool({ connectionString: databaseUrl });
  return pgPool;
}

async function ensurePostgresReady() {
  if (!postgresReadyPromise) {
    postgresReadyPromise = (async () => {
      const pool = getPostgresPool();

      await pool.query(`
        CREATE TABLE IF NOT EXISTS plaid_items (
          user_id TEXT PRIMARY KEY,
          access_token TEXT NOT NULL,
          item_id TEXT UNIQUE,
          sync_cursor TEXT,
          transactions_refresh_needed BOOLEAN NOT NULL DEFAULT FALSE,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
      `);

      await pool.query(`
        CREATE INDEX IF NOT EXISTS plaid_items_item_id_idx
        ON plaid_items (item_id)
        WHERE item_id IS NOT NULL
      `);

      await migrateJsonStoreToPostgres();
    })();
  }

  return postgresReadyPromise;
}

async function migrateJsonStoreToPostgres() {
  if (didTryJsonMigration || process.env.TOKEN_STORE_MIGRATE_JSON === 'false') {
    return;
  }

  didTryJsonMigration = true;
  const store = await readJsonStore();
  const users = Object.entries(store.users).filter(([, record]) => record?.access_token);

  if (users.length === 0) {
    return;
  }

  const pool = getPostgresPool();

  for (const [userId, record] of users) {
    await pool.query(
      `
        INSERT INTO plaid_items (
          user_id,
          access_token,
          item_id,
          sync_cursor,
          transactions_refresh_needed
        )
        VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT DO NOTHING
      `,
      [
        userId,
        record.access_token,
        record.item_id ?? null,
        record.sync_cursor ?? null,
        Boolean(record.transactions_refresh_needed),
      ],
    );
  }

  console.log(`Migrated ${users.length} local Plaid token record(s) into Postgres.`);
}

async function getJsonUserRecord(userId) {
  const store = await readJsonStore();
  return store.users[userId] ?? null;
}

async function saveJsonAccessToken(userId, accessToken, itemId) {
  const store = await readJsonStore();

  store.users[userId] = {
    access_token: accessToken,
    item_id: itemId ?? store.users[userId]?.item_id ?? null,
    sync_cursor: null,
    transactions_refresh_needed: false,
  };

  await writeJsonStore(store);
}

async function getPostgresUserRecord(userId) {
  await ensurePostgresReady();

  const result = await getPostgresPool().query(
    `
      SELECT
        user_id,
        access_token,
        item_id,
        sync_cursor,
        transactions_refresh_needed
      FROM plaid_items
      WHERE user_id = $1
    `,
    [userId],
  );

  return result.rows[0] ?? null;
}

async function saveAccessToken(userId, accessToken, itemId) {
  if (shouldUseJson) {
    await saveJsonAccessToken(userId, accessToken, itemId);
    return true;
  }

  await ensurePostgresReady();

  await getPostgresPool().query(
    `
      INSERT INTO plaid_items (
        user_id,
        access_token,
        item_id,
        sync_cursor,
        transactions_refresh_needed
      )
      VALUES ($1, $2, $3, NULL, FALSE)
      ON CONFLICT (user_id) DO UPDATE SET
        access_token = EXCLUDED.access_token,
        item_id = COALESCE(EXCLUDED.item_id, plaid_items.item_id),
        sync_cursor = NULL,
        transactions_refresh_needed = FALSE,
        updated_at = NOW()
    `,
    [userId, accessToken, itemId ?? null],
  );

  return true;
}

async function getAccessToken(userId) {
  const record = shouldUseJson
    ? await getJsonUserRecord(userId)
    : await getPostgresUserRecord(userId);

  return record?.access_token ?? null;
}

async function getSyncCursor(userId) {
  const record = shouldUseJson
    ? await getJsonUserRecord(userId)
    : await getPostgresUserRecord(userId);

  return record?.sync_cursor ?? null;
}

async function getTransactionsRefreshNeeded(userId) {
  const record = shouldUseJson
    ? await getJsonUserRecord(userId)
    : await getPostgresUserRecord(userId);

  return record?.transactions_refresh_needed ?? false;
}

async function getUserIdForItemId(itemId) {
  if (shouldUseJson) {
    const store = await readJsonStore();

    for (const [userId, record] of Object.entries(store.users)) {
      if (record.item_id === itemId) {
        return userId;
      }
    }

    return null;
  }

  await ensurePostgresReady();

  const result = await getPostgresPool().query(
    'SELECT user_id FROM plaid_items WHERE item_id = $1',
    [itemId],
  );

  return result.rows[0]?.user_id ?? null;
}

async function markTransactionsRefreshNeeded(userId, isNeeded) {
  if (shouldUseJson) {
    const store = await readJsonStore();
    const existing = store.users[userId];

    if (!existing?.access_token) {
      return false;
    }

    store.users[userId] = {
      ...existing,
      transactions_refresh_needed: isNeeded,
    };

    await writeJsonStore(store);
    return true;
  }

  await ensurePostgresReady();

  const result = await getPostgresPool().query(
    `
      UPDATE plaid_items
      SET transactions_refresh_needed = $2,
          updated_at = NOW()
      WHERE user_id = $1
        AND access_token IS NOT NULL
    `,
    [userId, isNeeded],
  );

  return result.rowCount > 0;
}

async function saveSyncCursor(userId, syncCursor) {
  if (shouldUseJson) {
    const store = await readJsonStore();
    const existing = store.users[userId];

    if (!existing?.access_token) {
      return false;
    }

    store.users[userId] = {
      ...existing,
      sync_cursor: syncCursor,
      transactions_refresh_needed: false,
    };

    await writeJsonStore(store);
    return true;
  }

  await ensurePostgresReady();

  const result = await getPostgresPool().query(
    `
      UPDATE plaid_items
      SET sync_cursor = $2,
          transactions_refresh_needed = FALSE,
          updated_at = NOW()
      WHERE user_id = $1
        AND access_token IS NOT NULL
    `,
    [userId, syncCursor],
  );

  return result.rowCount > 0;
}

module.exports = {
  getAccessToken,
  getSyncCursor,
  getTransactionsRefreshNeeded,
  getUserIdForItemId,
  markTransactionsRefreshNeeded,
  saveAccessToken,
  saveSyncCursor,
};
