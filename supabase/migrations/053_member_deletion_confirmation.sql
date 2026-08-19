-- MIGRATION 053: Member deletion confirmation wrapper (STEP 18)
--
-- The Admin app delete button previously called a NON-EXISTENT RPC
-- (`delete_user_account`). The real RPC `delete_member_account` (035)
-- requires a confirmation token derived from the member's email:
--   'DELETE-' || sha256(lower(email))
--
-- Keeping that hash server-side (single source of truth) instead of
-- re-implementing it with a client crypto dependency. This wrapper lets the
-- app confirm deletion by having the admin TYPE the member's email — the
-- same human-proves-knowledge control the token scheme enforces — and then
-- submits the always-owner-decided approval request.

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
  SELECT email INTO v_email FROM public.users WHERE id = p_member_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found';
  END IF;
  IF lower(btrim(COALESCE(p_confirmation_email, ''))) <> lower(btrim(v_email)) THEN
    RAISE EXCEPTION 'Email does not match this member';
  END IF;
  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'Reason is required';
  END IF;
  v_token := 'DELETE-' || encode(sha256(lower(v_email)::bytea), 'hex');
  RETURN public.delete_member_account(p_member_id, v_token, p_reason);
END;
$$;

REVOKE ALL ON FUNCTION public.request_member_deletion(uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.request_member_deletion(uuid, text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.request_member_deletion(uuid, text, text) TO authenticated;