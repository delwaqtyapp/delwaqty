-- 114: drop the identity-document path view, pin search_path, close the RLS gaps
--
-- Verified live, not assumed. Each item below was checked against the running
-- database before being written here.
--
-- (1) public.legacy_identity_document_paths - DROP
--   SELECT bucket_id, name, folder, created_at FROM storage.objects
--    WHERE bucket_id = 'profiles' AND folder[1] IN ('id_cards',
--           'trade_licenses', 'driving_licenses', 'verification')
--
--   It is a plain view (relrowsecurity = false) over storage.objects, so it
--   bypasses the storage RLS policies entirely, and `anon` held SELECT on it:
--
--     anon_select        = true
--     authenticated_select = true
--     relrowsecurity     = false
--
--   That is an inventory of every identity document in the platform - national
--   ID cards, trade licences, driving licences and provider verification scans -
--   with the exact object path for each, readable without an account.
--
--   Migration 103 moved those documents to a PRIVATE bucket precisely to stop
--   this, and left the old view behind as an artifact of the migration itself.
--   The application never reads it (zero references in lib/, zero dependent
--   objects in the database), so it is Production Dead Code: it has no consumer
--   and its only effect is exposure. Dropped rather than locked down, because a
--   view over a private bucket has no legitimate remaining purpose.
--
--   The private-bucket replacement is unaffected: identity documents are read
--   through create_signed_url from the client, never through this view.
--
-- (2) search_path pinning on SECURITY DEFINER functions
--   A SECURITY DEFINER function without `SET search_path` resolves unqualified
--   names using the caller's search_path. If any role the function runs as can
--   create objects in a schema that appears earlier in its path, a caller can
--   shadow a table or function name and have the definer's privileges applied to
--   the attacker's object. Pinning to `public, pg_temp` removes that.
--
-- (3) RLS enabled with zero policies
--   A table with RLS on and no policy denies every row to every non-owner role,
--   which is the safe state, but it is an accidental one: the table is
--   unreachable for reads AND writes, and the next migration that adds a policy
--   without noticing the table was already "protected" can widen access without
--   anyone reading the diff. The list below is recorded so the intent is
--   explicit rather than implied.
--
-- Re-run safe: every statement is IF EXISTS.

DROP VIEW IF EXISTS public.legacy_identity_document_paths;

-- (2) search_path. Only functions that are actually exposed to a client role
-- are touched, and only where it is currently unset.
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS sig
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.prosecdef
       AND p.proconfig IS NULL
       AND (has_function_privilege('anon', p.oid, 'EXECUTE')
         OR has_function_privilege('authenticated', p.oid, 'EXECUTE'))
       AND p.proname NOT LIKE 'st\_%'
       AND p.proname NOT LIKE '\_st%'
       AND p.proname NOT LIKE 'geometry%'
       AND p.proname NOT LIKE 'pgis%'
       AND p.proname NOT LIKE 'geography%'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public, pg_temp', r.sig);
  END LOOP;
END $$;

-- (3) the intent, stated. These tables are reachable only through their
-- SECURITY DEFINER RPCs, which is the documented design: the console reads
-- commission data through get_commission_rate / platform_revenue_overview and
-- writes it through set_commission_rate / admin_*. Direct table access is not
-- part of the contract.
COMMENT ON TABLE public.commission_rules IS
  'No direct client access by design. Read via get_commission_rate(); write via set_commission_rate(). RLS is enabled with no policy, which denies anon and authenticated.';
COMMENT ON TABLE public.platform_commissions IS
  'No direct client access by design. Written by the settlement functions; read via platform_commission_for_reference(). RLS is enabled with no policy, which denies anon and authenticated.';
COMMENT ON TABLE public.driver_earnings IS
  'No direct client access by design. Written by the delivery/ride completion paths; read via the driver financial RPCs. RLS is enabled with no policy, which denies anon and authenticated.';

-- Verification: the view must be gone, and no client-facing SECURITY DEFINER
-- function may be left without a pinned search_path.
DO $$
DECLARE
  v_left integer;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
              WHERE n.nspname = 'public' AND c.relname = 'legacy_identity_document_paths') THEN
    RAISE EXCEPTION 'legacy_identity_document_paths still exists';
  END IF;

  SELECT count(*) INTO v_left
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.prosecdef AND p.proconfig IS NULL
     AND (has_function_privilege('anon', p.oid, 'EXECUTE')
       OR has_function_privilege('authenticated', p.oid, 'EXECUTE'))
     AND p.proname NOT LIKE 'st\_%' AND p.proname NOT LIKE '\_st%'
     AND p.proname NOT LIKE 'geometry%' AND p.proname NOT LIKE 'pgis%'
     AND p.proname NOT LIKE 'geography%';
  IF v_left > 0 THEN
    RAISE EXCEPTION '% client-facing SECURITY DEFINER functions still lack search_path', v_left;
  END IF;

  RAISE NOTICE 'view dropped; every client-facing SECURITY DEFINER function has a pinned search_path';
END $$;
