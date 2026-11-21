-- Migration 117: Fix Member Deletion Overload Ambiguity and Cascade Suspension
--
-- 1. Drops the redundant 1-arg `owner_delete_member(uuid)` overload which triggers
--    PostgREST PGRST203 (HTTP 300 Multiple Candidates) because the 2-arg
--    `owner_delete_member(uuid, text DEFAULT 'Deleted by owner')` already covers
--    both 1-arg and 2-arg calls via its DEFAULT value.
--
-- 2. Upgrades `_member_exec_delete` so that upon member soft-deletion/deactivation:
--    - Sets `account_status = 'deactivated'` and anonymizes private fields in `public.users`
--    - Cascades deactivation to `public.drivers` (is_online = false, is_active = false, status = 'suspended')
--    - Cascades deactivation to `public.merchants` (is_open = false, status = 'suspended')
--    - Deactivates any registered push tokens in `public.notification_tokens`
--    - Writes audit and timeline event

DROP FUNCTION IF EXISTS public.owner_delete_member(uuid);

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

  -- If member is an admin, deactivate them through the admin hierarchy first
  IF EXISTS (
    SELECT 1 FROM public.admin_management
    WHERE admin_id = p_member_id AND is_active
  ) THEN
    PERFORM public._admin_exec_deactivate(auth.uid(), p_member_id, COALESCE(p_reason, 'Deleted by owner'));
  END IF;

  PERFORM public._member_exec_delete(auth.uid(), p_member_id, COALESCE(p_reason, 'Deleted by owner'));
END;
$$;

REVOKE ALL ON FUNCTION public.owner_delete_member(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.owner_delete_member(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.owner_delete_member(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.owner_delete_member(uuid, text) TO service_role;

CREATE OR REPLACE FUNCTION public._member_exec_delete(
  p_actor uuid,
  p_member_id uuid,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_status text;
BEGIN
  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'Reason is required';
  END IF;
  SELECT account_status INTO v_status FROM public.users WHERE id = p_member_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found';
  END IF;
  IF public._is_active_admin_uid(p_member_id) THEN
    RAISE EXCEPTION 'Admins are managed through the admin lifecycle';
  END IF;
  IF v_status = 'deactivated' THEN
    RAISE EXCEPTION 'Member account is already deactivated';
  END IF;

  -- 1. Soft-delete and anonymize user record
  UPDATE public.users SET
    account_status = 'deactivated',
    anonymized_at = now(),
    email = 'deleted-' || p_member_id::text || '@anonymized.invalid',
    full_name = NULL,
    phone = NULL,
    username = NULL,
    avatar_url = NULL,
    id_card_url = NULL,
    profile_photo_url = NULL,
    trade_license_url = NULL,
    driving_license_url = NULL
  WHERE id = p_member_id;

  -- 2. Cascade driver deactivation (if driver profile exists)
  IF EXISTS (SELECT 1 FROM public.drivers WHERE user_id = p_member_id) THEN
    UPDATE public.drivers SET
      is_online = false,
      is_active = false,
      status = 'suspended',
      updated_at = now()
    WHERE user_id = p_member_id;
  END IF;

  -- 3. Cascade merchant deactivation (if merchant profile exists)
  IF EXISTS (SELECT 1 FROM public.merchants WHERE owner_user_id = p_member_id) THEN
    UPDATE public.merchants SET
      is_open = false,
      status = 'suspended',
      updated_at = now()
    WHERE owner_user_id = p_member_id;
  END IF;

  -- 4. Deactivate all notification tokens for this user
  IF to_regclass('public.notification_tokens') IS NOT NULL THEN
    UPDATE public.notification_tokens SET
      is_active = false,
      updated_at = now()
    WHERE user_id = p_member_id;
  END IF;

  -- 5. Record timeline event & audit log
  INSERT INTO public.member_events (user_id, event_type, title, payload)
  VALUES (p_member_id, 'account_deactivated', 'Account deleted',
          jsonb_build_object('reason', p_reason));

  PERFORM public.write_audit(
    'MEMBER_DELETED', 'users', p_member_id::text,
    jsonb_build_object('actor', p_actor::text, 'reason', p_reason));
END;
$$;

NOTIFY pgrst, 'reload schema';
