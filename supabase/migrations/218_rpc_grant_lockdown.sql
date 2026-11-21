-- 218: emergency RPC grant lockdown (security reviewer C4/C5, 00:11 EET)
--
-- DROP+CREATE in 217 reset create_order_idempotent's ACL, re-granting the
-- default PUBLIC EXECUTE; several money/adjacent SECURITY DEFINER functions
-- were again executable by authenticated. The app calls none of these RPCs
-- (checkout prices server-side via create_order; wallet top-up goes through
-- the payment-callback path), so revoke them outright.
-- admin_direct_topup / wallet_adjust stay: the admin web app calls them as
-- authenticated and both are owner-gated in-body.
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure::text AS sig
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname IN ('wallet_topup','wallet_refund','apply_coupon',
                         'run_member_engines','log_admin_action','write_audit',
                         'create_order_idempotent')
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM public, anon, authenticated', r.sig);
  END LOOP;
END $$;
NOTIFY pgrst, 'reload schema';

-- Prevent recurrence: future functions created by the postgres role (the
-- migration runner) must not inherit the built-in PUBLIC EXECUTE grant.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
