-- 210: Security L1 - 91 SECURITY DEFINER functions were anon-executable via
-- the default PUBLIC grant. Strip PUBLIC + anon from every public definer
-- function, then re-grant narrowly:
--   anon: only the pre-login auth flow (identifier lookup + WhatsApp OTP)
--   authenticated: all non-internal, non-trigger definer functions
-- Internal helpers (_-prefixed) and trigger functions keep owner-only EXECUTE;
-- SECURITY DEFINER callers (RPCs, triggers, cron) are unaffected because they
-- execute as the function owner.

DO $$
DECLARE
  f record;
BEGIN
  FOR f IN
    SELECT p.oid::regprocedure::text AS sig, p.proname, p.prorettype = 'trigger'::regtype AS is_trigger
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.prosecdef
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM public, anon', f.sig);
    IF f.proname NOT LIKE '\_%' ESCAPE '\' AND NOT f.is_trigger THEN
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', f.sig);
    END IF;
  END LOOP;
END $$;

GRANT EXECUTE ON FUNCTION public.lookup_email_by_phone(text) TO anon;
GRANT EXECUTE ON FUNCTION public.lookup_email_by_username(text) TO anon;
GRANT EXECUTE ON FUNCTION public.request_whatsapp_otp(text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.verify_whatsapp_otp(text, text) TO anon;

NOTIFY pgrst, 'reload schema';
