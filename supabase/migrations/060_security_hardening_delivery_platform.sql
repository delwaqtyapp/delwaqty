-- 060_security_hardening_delivery_platform.sql
-- Mission 7 / PHASE 9 security remediation.
-- Historical migration 011 created 6 SECURITY DEFINER delivery functions WITHOUT
-- an explicit search_path and without revoking PUBLIC EXECUTE. Per the project
-- security standard (set in 051) every privileged function MUST set
-- `search_path = public, pg_temp` and must not be executable by anon/PUBLIC.
-- Migration 050 additionally granted EXECUTE on all platform_* functions to anon,
-- which violates the ACL rule (authenticated + service_role only).
-- This migration hardens both, without rewriting history.

-- ============================================================
-- 1. Harden the 6 delivery functions from 011
-- ============================================================
ALTER FUNCTION public.dispatch_delivery(UUID, DECIMAL, INTEGER)
  SET search_path = public, pg_temp;
ALTER FUNCTION public.complete_delivery(UUID, UUID, TEXT, DECIMAL)
  SET search_path = public, pg_temp;
ALTER FUNCTION public.estimate_delivery_fee(TEXT, DECIMAL, DECIMAL, TEXT)
  SET search_path = public, pg_temp;
ALTER FUNCTION public.merchant_ready_for_dispatch(UUID, UUID)
  SET search_path = public, pg_temp;
ALTER FUNCTION public.get_merchant_deliveries(UUID, TEXT)
  SET search_path = public, pg_temp;
ALTER FUNCTION public.update_driver_capabilities(UUID, TEXT[], BOOLEAN, DECIMAL, DECIMAL)
  SET search_path = public, pg_temp;

DO $$
DECLARE fn RECORD;
BEGIN
  FOR fn IN
    VALUES
      ('dispatch_delivery(UUID, DECIMAL, INTEGER)'),
      ('complete_delivery(UUID, UUID, TEXT, DECIMAL)'),
      ('estimate_delivery_fee(TEXT, DECIMAL, DECIMAL, TEXT)'),
      ('merchant_ready_for_dispatch(UUID, UUID)'),
      ('get_merchant_deliveries(UUID, TEXT)'),
      ('update_driver_capabilities(UUID, TEXT[], BOOLEAN, DECIMAL, DECIMAL)')
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION public.%s FROM PUBLIC, anon', fn.column1);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO authenticated, service_role', fn.column1);
  END LOOP;
END $$;

-- ============================================================
-- 2. Remove anon EXECUTE grant on all platform_* intelligence RPCs (050)
-- ============================================================
DO $$
DECLARE fn RECORD;
BEGIN
  FOR fn IN
    SELECT p.proname AS name,
           pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.proname LIKE 'platform_%'
      AND p.prokind = 'f'
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION public.%I(%s) FROM anon', fn.name, fn.args);
  END LOOP;
END $$;
