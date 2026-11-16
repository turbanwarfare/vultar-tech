CREATE TABLE staff_ranks (
  user_id INTEGER PRIMARY KEY,
  rank TEXT NOT NULL,
  granted_by INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
