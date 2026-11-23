-- 424a: hardening ACL convergence + cash-audit helpers (BOTH environments).
--
-- Revoke spec (security-reviewer triage 2026-11-23): trigger guard
-- functions must not be client-callable. Revokes are idempotent; one file
-- converges prod (service_providers_guard_sensitive_fields had leaked to
-- authenticated) and staging (the other eight had anon+authenticated from
-- the 000_baseline.sql GRANT lines they were bootstrapped with).
--
-- Helpers _audit_cash_collection / _audit_cash_pair_mismatch: verbatim
-- from staging, write to public.audit_log (exists on both envs, columns
-- verified on prod 2026-11-23). ACL: service_role only.
--
-- RERUNNABLE: REVOKE / GRANT / CREATE OR REPLACE are all idempotent.
-- The five RPC body backports live in 424b (prod-only, md5-guarded).

BEGIN;

-- ── audit helpers ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public._audit_cash_collection(p_resource text, p_resource_id uuid, p_amount numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- Idempotent: one CASH_COLLECTED audit row per resource, however many
  -- times the confirmation is replayed (double tap, retry, order+ride pair).
  INSERT INTO public.audit_log (actor, actor_role, scope, action, resource, resource_id, after)
  SELECT auth.uid(),
         COALESCE((SELECT u.role FROM public.users u WHERE u.id = auth.uid()), 'unknown'),
         'GLOBAL',
         'CASH_COLLECTED',
         p_resource,
         p_resource_id::text,
         jsonb_build_object('amount', p_amount, 'collected_by', auth.uid())
  WHERE NOT EXISTS (
    SELECT 1 FROM public.audit_log a
     WHERE a.action = 'CASH_COLLECTED'
       AND a.resource = p_resource
       AND a.resource_id = p_resource_id::text
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public._audit_cash_pair_mismatch(p_resource text, p_reference_id uuid, p_warnings jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF p_warnings IS NULL OR jsonb_array_length(p_warnings) = 0 THEN
    RETURN;
  END IF;
  IF EXISTS (SELECT 1 FROM public.audit_log a
              WHERE a.action = 'CASH_PAIR_MISMATCH'
                AND a.resource = p_resource
                AND a.resource_id = p_reference_id::text) THEN
    UPDATE public.audit_log
       SET after = jsonb_build_object('pair_warnings', p_warnings, 'reported_by', auth.uid()),
           created_at = now()
     WHERE action = 'CASH_PAIR_MISMATCH'
       AND resource = p_resource
       AND resource_id = p_reference_id::text;
  ELSE
    INSERT INTO public.audit_log (actor, actor_role, scope, action, resource, resource_id, after, reason)
    VALUES (auth.uid(),
            COALESCE((SELECT u.role FROM public.users u WHERE u.id = auth.uid()), 'unknown'),
            'GLOBAL',
            'CASH_PAIR_MISMATCH',
            p_resource,
            p_reference_id::text,
            jsonb_build_object('pair_warnings', p_warnings, 'reported_by', auth.uid()),
            'cash_handoff_pair_mismatch');
  END IF;
END;
$function$;

REVOKE ALL ON FUNCTION public._audit_cash_collection(text,uuid,numeric) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._audit_cash_pair_mismatch(text,uuid,jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public._audit_cash_collection(text,uuid,numeric) TO service_role;
GRANT EXECUTE ON FUNCTION public._audit_cash_pair_mismatch(text,uuid,jsonb) TO service_role;

-- ── trigger guard revoke spec ────────────────────────────────────────
REVOKE EXECUTE ON FUNCTION public.orders_guard_sensitive() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.rides_guard_client_writes() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.service_bookings_guard_client_writes() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.reservations_guard_customer_updates() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.freeze_review_identity() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.freeze_service_review_identity() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.complaints_guard_admin_fields() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.guard_vehicle_verification() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.service_providers_guard_sensitive_fields() FROM PUBLIC, anon, authenticated;

COMMIT;

NOTIFY pgrst, 'reload schema';
