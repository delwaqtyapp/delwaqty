-- 455: retire the long DLWQ1 cashier license keys (owner order 2026-11-26
-- 15:54: "delete the old key, I have not tried any key yet").
-- From now on the only accepted key is the 12 digit code (short_code).
--
-- How: license_key is rewritten to equal short_code on every row, and a
-- trigger keeps it that way for any insert or update. The RPCs from 454 look
-- up "short_code = normalized OR license_key = normalized"; a long DLWQ1 string
-- no longer matches anything, so it answers UNKNOWN_KEY like any wrong key.
-- No RPC body changes. No license is deleted, expired or re-bound; the
-- license id, plan, expiry and device binding are untouched, only the key
-- text changes. Re-runnable.

CREATE OR REPLACE FUNCTION public._cashier_license_fill_short_code()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE c text; n integer := 0;
BEGIN
  IF NEW.short_code IS NULL THEN
    LOOP
      n := n + 1;
      c := lpad((('x' || substr(replace(gen_random_uuid()::text, '-', ''), 14, 15))::bit(60)::bigint
                 % 1000000000000)::text, 12, '0');
      EXIT WHEN NOT EXISTS (SELECT 1 FROM public.cashier_licenses WHERE short_code = c OR license_key = c);
      IF n >= 5 THEN RAISE EXCEPTION 'KEY_GENERATION_FAILED'; END IF;
    END LOOP;
    NEW.short_code := c;
  END IF;
  -- Only the 12 digit code is a key (455): no long token can be stored again.
  NEW.license_key := NEW.short_code;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public._cashier_license_fill_short_code() FROM public, anon, authenticated;

DROP TRIGGER IF EXISTS cashier_licenses_fill_short_code ON public.cashier_licenses;
CREATE TRIGGER cashier_licenses_fill_short_code
  BEFORE INSERT OR UPDATE OF license_key, short_code ON public.cashier_licenses
  FOR EACH ROW EXECUTE FUNCTION public._cashier_license_fill_short_code();

-- Rewrite existing rows (the trigger sets license_key := short_code).
UPDATE public.cashier_licenses SET license_key = short_code WHERE license_key IS DISTINCT FROM short_code;
