-- ─────────────────────────────────────────────────────────────
-- 017: Add editable username to users profile
-- Applies to the users table created in 002_complete_schema.sql
-- ─────────────────────────────────────────────────────────────

ALTER TABLE users ADD COLUMN IF NOT EXISTS username TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS users_username_unique_idx
  ON users (username)
  WHERE username IS NOT NULL;
