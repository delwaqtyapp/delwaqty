-- MIGRATION 115: Bulletproof Member Deletion for Delwaqty Admin
--
-- 1. Ensure owner_delete_member supports both 1-param (p_member_id) and 2-param (p_member_id, p_reason) calls.
-- 2. Deactivation & soft-delete safely removes authority without FK violations.
-- 3. Support deletion for phone-only and non-email members in request_member_deletion & delete_member_account.

CREATE OR REPLACE FUNCTION public.owner_delete_member(
  p_member_id uuid,
  p_reason text DEFAULT 'Deleted by owner'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public._is_owner_uid(auth.uid()) THEN
    RAISE EXCEPTION 'Only the owner can delete accounts directly';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = p_member_id) THEN
    RAISE EXCEPTION 'Member not found';
  END IF;
  IF public._is_owner_uid(p_member_id) THEN
    RAISE EXCEPTION 'Cannot delete the owner account';
  END IF;

  -- Admins are managed through the admin lifecycle: revoke authority first
  -- (demotes role + deactivates the tree row), then soft-delete.
  IF EXISTS (
    SELECT 1 FROM public.admin_management
    WHERE admin_id = p_member_id AND is_active
  ) THEN
    PERFORM public._admin_exec_deactivate(auth.uid(), p_member_id, COALESCE(p_reason, 'Deleted by owner'));
  END IF;

  PERFORM public._member_exec_delete(auth.uid(), p_member_id, COALESCE(p_reason, 'Deleted by owner'));
END;
$$;

CREATE OR REPLACE FUNCTION public.owner_delete_member(
  p_member_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  PERFORM public.owner_delete_member(p_member_id, 'Deleted by owner');
END;
$$;

REVOKE ALL ON FUNCTION public.owner_delete_member(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.owner_delete_member(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.owner_delete_member(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_delete_member(uuid, text) TO service_role;

REVOKE ALL ON FUNCTION public.owner_delete_member(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.owner_delete_member(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.owner_delete_member(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_delete_member(uuid) TO service_role;

-- 2. Update delete_member_account to handle phone-only users (NULL email)
CREATE OR REPLACE FUNCTION public.delete_member_account(
  p_member_id uuid,
  p_confirmation_token text,
  p_reason text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_status text;
  v_email text;
  v_expected_token text;
  v_request_id uuid;
BEGIN
  SELECT account_status, email INTO v_status, v_email FROM public.users WHERE id = p_member_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found';
  END IF;
  IF public._is_active_admin_uid(p_member_id) THEN
    RAISE EXCEPTION 'Admins are managed through the admin lifecycle';
  END IF;
  IF v_status = 'deactivated' THEN
    RAISE EXCEPTION 'Member account is already deactivated';
  END IF;
  IF NOT public.has_permission('MEMBER_DELETE', public._member_region_id(p_member_id))
     AND NOT public._is_owner_uid(auth.uid()) THEN
    RAISE EXCEPTION 'Not authorized for this member';
  END IF;

  IF v_email IS NOT NULL AND btrim(v_email) <> '' THEN
    v_expected_token := 'DELETE-' || encode(sha256(lower(btrim(v_email))::bytea), 'hex');
  ELSE
    v_expected_token := 'DELETE-' || encode(sha256(p_member_id::text::bytea), 'hex');
  END IF;

  IF p_confirmation_token IS NULL OR p_confirmation_token <> v_expected_token THEN
    RAISE EXCEPTION 'Invalid confirmation token';
  END IF;

  v_request_id := public.submit_approval_request(
    'member_delete', 'member', p_member_id,
    jsonb_build_object('member_id', p_member_id::text, 'reason', p_reason),
    p_reason);
  RETURN v_request_id;
END;
$$;

-- 3. Update request_member_deletion to match phone-only users or email
CREATE OR REPLACE FUNCTION public.request_member_deletion(
  p_member_id uuid,
  p_confirmation_email text,
  p_reason text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_email text;
  v_token text;
BEGIN
  IF auth.uid() IS NOT NULL AND p_member_id <> auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT email INTO v_email FROM public.users WHERE id = p_member_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found';
  END IF;

  IF v_email IS NOT NULL AND btrim(v_email) <> '' THEN
    IF lower(btrim(COALESCE(p_confirmation_email, ''))) <> lower(btrim(v_email)) THEN
      RAISE EXCEPTION 'Email does not match this member';
    END IF;
    v_token := 'DELETE-' || encode(sha256(lower(btrim(v_email))::bytea), 'hex');
  ELSE
    v_token := 'DELETE-' || encode(sha256(p_member_id::text::bytea), 'hex');
  END IF;

  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'Reason is required';
  END IF;

  RETURN public.delete_member_account(p_member_id, v_token, p_reason);
END;
$$;

-- 4. Ensure lookup_email_by_username is defined
CREATE OR REPLACE FUNCTION public.lookup_email_by_username(p_username text)
RETURNS text
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT email FROM public.users
  WHERE username IS NOT NULL
    AND lower(username) = lower(btrim(p_username))
    AND account_status <> 'deactivated'
    AND email NOT LIKE '%@anonymized.invalid'
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.lookup_email_by_username(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.lookup_email_by_username(text) TO anon, authenticated, service_role;

