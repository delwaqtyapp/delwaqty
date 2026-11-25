-- 441: login identifiers are username or phone ONLY - the legacy email
-- bridge is removed.
--
-- Owner decision (2026-11-25): no real user has ever joined with an
-- email login, so email is dropped as a login identifier entirely.
-- Email stays where it belongs: signup, password reset and account
-- contact. For LOGIN, an email-shaped identifier now resolves to NULL
-- and the edge function answers it exactly like an unknown identifier
-- (same 401 status, same body, same dummy GoTrue password check for
-- timing), so the change reveals nothing about which emails exist.
--
-- Only auth_login_resolve_email changes (email pass-through removed);
-- auth_login_begin / auth_login_finish are untouched. Grants are
-- re-asserted idempotently: EXECUTE stays service-role only.

BEGIN;

CREATE OR REPLACE FUNCTION public.auth_login_resolve_email(p_identifier text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id text := btrim(coalesce(p_identifier, ''));
  v_email text;
  v_norm text;
  v_digits text;
  v_last10 text;
  v_uname text;
BEGIN
  IF v_id = '' OR length(v_id) > 254 THEN
    RETURN NULL;
  END IF;

  -- Email-shaped identifiers are NOT a login identifier (441): resolve
  -- to NULL so the edge function takes the unknown-identifier path.
  IF position('@' IN v_id) > 0 THEN
    RETURN NULL;
  END IF;

  v_digits := regexp_replace(v_id, '[^0-9]', '', 'g');

  -- Phone-shaped: same resolution as lookup_email_by_phone.
  IF length(v_digits) >= 9 AND v_id ~ '^[+0-9 ()-]+$' THEN
    v_norm := public._normalize_egypt_phone(v_id);
    v_last10 := right(v_digits, 10);
    SELECT email INTO v_email
      FROM public.users
     WHERE account_status <> 'deactivated'
       AND email IS NOT NULL
       AND email <> ''
       AND email NOT LIKE '%@anonymized.invalid'
       AND (
         public._normalize_egypt_phone(phone) = v_norm
         OR right(regexp_replace(coalesce(phone, ''), '[^0-9]', '', 'g'), 10) = v_last10
       )
     ORDER BY created_at DESC
     LIMIT 1;
    RETURN v_email;
  END IF;

  -- Username: same resolution as lookup_email_by_username.
  v_uname := lower(v_id);
  SELECT email INTO v_email
    FROM public.users
   WHERE username IS NOT NULL
     AND lower(username) = v_uname
     AND account_status <> 'deactivated'
     AND email NOT LIKE '%@anonymized.invalid'
   LIMIT 1;
  RETURN v_email;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.auth_login_resolve_email(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.auth_login_resolve_email(text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.auth_login_resolve_email(text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.auth_login_resolve_email(text) TO service_role;

COMMIT;
