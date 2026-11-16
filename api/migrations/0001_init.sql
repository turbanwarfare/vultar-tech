CREATE TABLE players (
  user_id INTEGER PRIMARY KEY,
  credits INTEGER NOT NULL DEFAULT 0 CHECK (credits >= 0),
  updated_at INTEGER NOT NULL
);

CREATE TABLE unlocks (
  user_id INTEGER NOT NULL,
  item_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (user_id, item_id)
);

CREATE TABLE ledger (
  tx_id TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('credits', 'unlock', 'remove_unlock')),
  source TEXT NOT NULL CHECK (source IN ('purchase', 'crate', 'admin')),
  delta INTEGER NOT NULL DEFAULT 0,
  balance_after INTEGER,
  item_ids TEXT,
  detail TEXT NOT NULL,
  place_id TEXT,
  created_at INTEGER NOT NULL
);

CREATE INDEX ledger_user_time ON ledger (user_id, created_at);

CREATE TRIGGER ledger_no_update BEFORE UPDATE ON ledger
BEGIN
  SELECT RAISE(ABORT, 'ledger is append-only');
END;

CREATE TRIGGER ledger_no_delete BEFORE DELETE ON ledger
BEGIN
  SELECT RAISE(ABORT, 'ledger is append-only');
END;
