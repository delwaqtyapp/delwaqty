-- 028: Schema alignment — fix model-DB mismatches
-- Fixes: C3 (missing users columns) + C4 (admin_users CHECK constraint)

-- ─── C3: Add missing license URL columns to users ────────────

ALTER TABLE users ADD COLUMN IF NOT EXISTS trade_license_url TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS driving_license_url TEXT;

-- ─── C3: RPC for efficient row counting (replaces N+1 queries) ─
-- SECURITY INVOKER: page counts reflect the caller's RLS visibility,
-- never worse than the direct .select().count() calls it replaces.

CREATE OR REPLACE FUNCTION count_table_rows(table_name TEXT)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  row_count INTEGER;
BEGIN
  EXECUTE format('SELECT COUNT(*) FROM %I', table_name) INTO row_count;
  RETURN row_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION count_table_rows(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION count_table_rows(TEXT) TO authenticated;

-- ─── C4: Add 'moderator' to admin_users role CHECK ──────────

ALTER TABLE admin_users DROP CONSTRAINT IF EXISTS admin_users_role_check;

ALTER TABLE admin_users
  ADD CONSTRAINT admin_users_role_check
  CHECK (role IN ('super_admin', 'admin', 'moderator', 'support', 'finance'));