-- ─────────────────────────────────────────────────────────────
-- 022: Add biometric-login flag to users profile
-- Applies to the users table created in 002_complete_schema.sql
--
-- is_biometric_enabled only records that the account has biometric
-- login active. The credentials themselves never leave the device:
-- they live encrypted in flutter_secure_storage, keyed by user id
-- (auth_biometric_<userId>). Idempotent and safe to re-run.
-- ─────────────────────────────────────────────────────────────

ALTER TABLE users ADD COLUMN IF NOT EXISTS is_biometric_enabled BOOLEAN NOT NULL DEFAULT false;
