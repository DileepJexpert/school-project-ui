-- Cloudflare D1 Initial Migration for School API runtime verification
CREATE TABLE IF NOT EXISTS schema_versions (
    version TEXT PRIMARY KEY,
    applied_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS tenants (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    domain TEXT,
    active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    tenant_id TEXT,
    email TEXT NOT NULL,
    full_name TEXT NOT NULL,
    role TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL,
    FOREIGN KEY (tenant_id) REFERENCES tenants(id)
);

CREATE TABLE IF NOT EXISTS auth_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    access_hash TEXT NOT NULL,
    refresh_hash TEXT NOT NULL,
    revoked_at TEXT,
    expires_at TEXT NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS test_ledger (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_name TEXT NOT NULL,
    amount_cents INTEGER NOT NULL,
    note TEXT NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_ledger_account_note ON test_ledger(account_name, note);

CREATE TABLE IF NOT EXISTS test_accounts (
    id TEXT PRIMARY KEY,
    balance_cents INTEGER NOT NULL,
    version INTEGER NOT NULL DEFAULT 1
);

INSERT OR IGNORE INTO schema_versions (version, applied_at)
VALUES ('0001_initial', CURRENT_TIMESTAMP);
