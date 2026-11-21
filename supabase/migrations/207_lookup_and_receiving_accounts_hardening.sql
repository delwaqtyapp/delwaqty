-- 207: Security H1/H2/M3.
-- H1: lookup_email_by_phone / lookup_email_by_username must stay anon-executable
-- (pre-login identifier lookup), but their IP rate bucket read the FIRST
-- x-forwarded-for element, which the client controls. Use the LAST element,
-- appended by the platform edge. Also revoke direct EXECUTE on the internal
-- rate-limit helper (M3); the definer lookups call it as owner.
-- H2: get_active_receiving_accounts exposed platform cash settlement accounts
-- to anonymous callers; every real caller (topup page, admin financial center)
-- is authenticated.

CREATE OR REPLACE FUNCTION public._lookup_caller_ip()
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
declare
  v_headers text;
  v_parts text[];
begin
  v_headers := current_setting('request.headers', true);
  if v_headers is null then return 'unknown'; end if;
  v_parts := string_to_array(coalesce(v_headers::json ->> 'x-forwarded-for', ''), ',');
  -- The LAST entry is appended by the trusted edge; earlier ones are client input.
  return coalesce(nullif(btrim(v_parts[array_length(v_parts, 1)]), ''), 'unknown');
exception when others then
  return 'unknown';
end;
$function$;

REVOKE EXECUTE ON FUNCTION public._lookup_rate_allow(text, integer) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_active_receiving_accounts() FROM anon;

NOTIFY pgrst, 'reload schema';

-- PostgREST roles inherit the default PUBLIC EXECUTE grant; role-level REVOKEs
-- alone do not close internal helpers. Strip PUBLIC too.
REVOKE EXECUTE ON FUNCTION public._lookup_rate_allow(text, integer) FROM public;
REVOKE EXECUTE ON FUNCTION public._lookup_caller_ip() FROM public, anon, authenticated;

NOTIFY pgrst, 'reload schema';
