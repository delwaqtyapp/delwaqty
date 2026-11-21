-- 079_delete_my_account.sql
-- Self-service account deletion (customer app "Delete Account").
--
-- Reuses the existing moderation engine soft-delete/anonymization
-- (`_member_exec_delete`, migration 035) so the public.users row stays FK-safe
-- (rides/orders/etc. still reference users(id)) with PII anonymized and
-- account_status = 'deactivated'. Then the auth row is removed, which revokes
-- the login immediately and releases the email for re-registration.
--
-- Security model:
--   * SECURITY DEFINER (owner executes as postgres) so we may touch auth.users.
--   * The function only ever affects auth.uid() — no actor parameter.
--   * Admins are refused (handled by the admin lifecycle, same as moderation).
--   * RLS on public.users has no direct UPDATE path for clients (035 enforces
--     account_status via moderation RPCs); this function is the sanctioned path.

CREATE OR REPLACE FUNCTION public.delete_my_account(
  p_reason text DEFAULT 'user_requested'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Soft-delete + anonymize the public profile (D4 semantics, FK-safe),
  -- raising for admins / deactivated / missing member as the engine does.
  PERFORM public._member_exec_delete(v_uid, v_uid, COALESCE(NULLIF(btrim(p_reason), ''), 'user_requested'));

  -- Revoke the login: removes the auth row (triggers a client 401 on next call).
  DELETE FROM auth.users WHERE id = v_uid;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_my_account(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_my_account(text) TO authenticated;