-- ============================================================================
-- 068_provider_verification.sql
-- Additive provider verification self-submission (PHASE 4).
-- Rejected re-submission remains owned by reapply_verification (047). This RPC
-- handles the initial / refresh submission (not_submitted / pending -> pending)
-- and refuses rejected (must use reapply_verification) so the single state
-- machine is preserved. Authz: owner-only via auth.uid(); SECURITY DEFINER,
-- search_path scoped. No destructive ops; reuses users.verification_status.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.provider_submit_verification(
  p_id_card_url text,
  p_profile_photo_url text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid    uuid := auth.uid();
  v_status text;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED');
  END IF;
  IF btrim(COALESCE(p_id_card_url, '')) = ''
     OR btrim(COALESCE(p_profile_photo_url, '')) = '' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'MISSING_DOCUMENTS');
  END IF;

  SELECT verification_status INTO v_status FROM public.users WHERE id = v_uid FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND');
  END IF;

  -- Rejected accounts must use reapply_verification (keeps one state machine).
  IF v_status = 'rejected' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'USE_REAPPLY');
  END IF;

  UPDATE public.users
    SET id_card_url = btrim(p_id_card_url),
        profile_photo_url = btrim(p_profile_photo_url),
        verification_status = 'pending',
        rejection_reason = NULL,
        rejection_reason_at = NULL,
        updated_at = now()
    WHERE id = v_uid;

  RETURN jsonb_build_object('ok', true, 'code', 'OK', 'status', 'pending');
END;
$$;

REVOKE ALL ON FUNCTION public.provider_submit_verification(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.provider_submit_verification(text, text) TO authenticated;
