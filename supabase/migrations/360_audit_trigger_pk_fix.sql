-- 360_audit_trigger_pk_fix.sql
-- Blocker: _audit_admin_table_write referenced OLD.id/NEW.id directly, which
-- fails (42703) on delivery_pricing (PK service_type). Use to_jsonb with PK
-- fallbacks; verified all 12 admin-managed tables, only delivery_pricing
-- lacks an id column.

BEGIN;

CREATE OR REPLACE FUNCTION public._audit_admin_table_write()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE
  v_row jsonb;
  v_id text;
BEGIN
  IF public._is_active_admin_uid(auth.uid()) THEN
    v_row := CASE TG_OP WHEN 'DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END;
    v_id := COALESCE(
      v_row ->> 'id',
      v_row ->> 'service_type',
      md5(v_row::text)
    );
    PERFORM public.write_audit(
      'ADMIN_TABLE_' || TG_OP, TG_TABLE_NAME, v_id,
      jsonb_build_object('actor', auth.uid()::text)
    );
  END IF;
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$fn$;

COMMIT;
