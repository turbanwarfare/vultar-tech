DROP TRIGGER ledger_no_update;
DROP TRIGGER ledger_no_delete;

CREATE TABLE ledger_new (
  tx_id TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('credits', 'unlock', 'remove_unlock')),
  source TEXT NOT NULL CHECK (source IN ('purchase', 'crate', 'admin', 'match', 'match_private')),
  delta INTEGER NOT NULL DEFAULT 0,
  balance_after INTEGER,
  item_ids TEXT,
  detail TEXT NOT NULL,
  place_id TEXT,
  created_at INTEGER NOT NULL
);

INSERT INTO ledger_new (tx_id, user_id, kind, source, delta, balance_after, item_ids, detail, place_id, created_at)
SELECT tx_id, user_id, kind, source, delta, balance_after, item_ids, detail, place_id, created_at FROM ledger;

DROP TABLE ledger;
ALTER TABLE ledger_new RENAME TO ledger;

CREATE INDEX ledger_user_time ON ledger (user_id, created_at);
CREATE INDEX ledger_user_source_time ON ledger (user_id, source, created_at);

CREATE TRIGGER ledger_no_update BEFORE UPDATE ON ledger
BEGIN
  SELECT RAISE(ABORT, 'ledger is append-only');
END;

CREATE TRIGGER ledger_no_delete BEFORE DELETE ON ledger
BEGIN
  SELECT RAISE(ABORT, 'ledger is append-only');
END;
