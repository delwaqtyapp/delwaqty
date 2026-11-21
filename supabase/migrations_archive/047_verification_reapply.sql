-- ============================================================
-- 047_verification_reapply.sql
-- Step 12 (Phase 12.4) — verification deep-linking + rejected
-- re-apply flow.
--
-- The 020/021 verification lifecycle is one-way today: admin flips
-- users.verification_status pending -> approved/rejected directly, and a
-- rejected user has no logged way back. This migration:
--
--   1. Adds rejection reason columns so the workflow is auditable.
--   2. Adds reapply_verification(p_id_card_url, p_profile_photo_url) —
--      the *only* path for a rejected user to resubmit documents: it flips
--      verification_status back to 'pending', clears the reason, and logs
--      the decision (write_audit + notification).
--   3. Adds decide_user_verification(p_user_id, p_decision, p_reason) —
--      the *only* admin path to approve/reject a member's verification,
--      replacing the raw authenticated UPDATE used by the current client.
--   4. Extends users_guard_account_fields so verification_status can no
--      longer be changed by a plain authenticated UPDATE (RPC-only);
--      SECURITY DEFINER RPCs (current_user = postgres/service_role) are
--      exempt via the existing role guard.
--
-- Security (035/046 lessons): REVOKE-before-GRANT, search_path scoped to
-- public,pg_temp, SECURITY DEFINER only where escalation is required, the
-- guard trigger stays BEFORE UPDATE with an explicit role guard.
-- ============================================================

-- ─── 1. REJECTION REASON COLUMNS ────────────────────────────────────────

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS rejection_reason_at TIMESTAMPTZ;

-- ─── 2. REAPPLY RPC (rejected member -> pending) ────────────────────────

CREATE OR REPLACE FUNCTION public.reapply_verification(
  p_id_card_url text,
  p_profile_photo_url text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_old_status text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF btrim(COALESCE(p_id_card_url, '')) = ''
     OR btrim(COALESCE(p_profile_photo_url, '')) = '' THEN
    RAISE EXCEPTION 'Both documents are required';
  END IF;

  SELECT verification_status INTO v_old_status
    FROM public.users WHERE id = v_uid FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found';
  END IF;

  IF v_old_status <> 'rejected' THEN
    RAISE EXCEPTION 'Verification can only be re-applied after a rejection';
  END IF;

  UPDATE public.users
    SET verification_status = 'pending',
        id_card_url = p_id_card_url,
        profile_photo_url = p_profile_photo_url,
        rejection_reason = NULL,
        rejection_reason_at = NULL,
        updated_at = now()
    WHERE id = v_uid;

  INSERT INTO public.notifications
    (user_id, title, body, type, data, deep_link, idempotency_key, send_push)
  VALUES (
    v_uid,
    'Verification re-submitted',
    'Your documents are under review again.',
    'verification',
    jsonb_build_object(
      'status', 'pending',
      'reapply', true
    ),
    '/pending-verification',
    'verification-reapply-' || v_uid::text || '-' || now()::timestamptz(3)::text,
    false
  );

  PERFORM public.write_audit(
    'VERIFICATION_REAPPLIED',
    'users',
    v_uid::text,
    jsonb_build_object(
      'previous_status', v_old_status,
      'new_status', 'pending'
    )
  );
END;
$function$;

-- ─── 3. ADMIN DECIDE RPC (approve / reject + reason) ────────────────────

CREATE OR REPLACE FUNCTION public.decide_user_verification(
  p_user_id uuid,
  p_decision text,
  p_reason text DEFAULT NULL::text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_current text;
  v_new text;
  v_has_docs boolean;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_decision NOT IN ('approve', 'reject') THEN
    RAISE EXCEPTION 'Invalid decision';
  END IF;
  IF p_decision = 'reject'
     AND btrim(COALESCE(p_reason, '')) = '' THEN
    RAISE EXCEPTION 'Rejection requires a reason';
  END IF;

  SELECT verification_status,
         id_card_url IS NOT NULL AND profile_photo_url IS NOT NULL
    INTO v_current, v_has_docs
    FROM public.users WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found';
  END IF;

  IF v_current NOT IN ('pending', 'rejected') THEN
    RAISE EXCEPTION 'Verification already decided';
  END IF;

  v_new := CASE WHEN p_decision = 'approve' THEN 'approved' ELSE 'rejected' END;

  UPDATE public.users
    SET verification_status = v_new,
        rejection_reason = CASE
          WHEN p_decision = 'reject' THEN btrim(p_reason)
          ELSE NULL
        END,
        rejection_reason_at = CASE
          WHEN p_decision = 'reject' THEN now()
          ELSE NULL
        END,
        updated_at = now()
    WHERE id = p_user_id;

  INSERT INTO public.notifications
    (user_id, title, body, type, data, deep_link, idempotency_key)
  VALUES (
    p_user_id,
    CASE WHEN p_decision = 'approve' THEN 'Verification approved'
         ELSE 'Verification rejected' END,
    CASE WHEN p_decision = 'approve'
         THEN 'You can now use the platform.'
         ELSE COALESCE(btrim(p_reason), 'Please review your documents.') END,
    'verification',
    jsonb_build_object(
      'status', v_new,
      'reason', p_reason
    ),
    CASE WHEN p_decision = 'approve' THEN '/profile' ELSE '/pending-verification' END,
    'verification-decide-' || p_user_id::text || '-' || gen_random_uuid()::text
  );

  PERFORM public.write_audit(
    'VERIFICATION_DECIDED',
    'users',
    p_user_id::text,
    jsonb_build_object(
      'decision', p_decision,
      'reason', p_reason,
      'had_documents', v_has_docs
    )
  );
END;
$function$;

-- ─── 4. GUARD: verification_status is RPC-managed ───────────────────────

CREATE OR REPLACE FUNCTION public.users_guard_account_fields()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $function$
BEGIN
  -- System context (trigger/service worker/cron, no JWT): allowed. SECURITY
  -- DEFINER RPCs run as the table owner (current_user = postgres/service_role)
  -- and are exempt via the role guard below.
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;
  IF current_user IN ('authenticated', 'anon') THEN
    IF NEW.role IS DISTINCT FROM OLD.role THEN
      RAISE EXCEPTION 'Role is managed by the admin lifecycle RPCs';
    END IF;
    IF NEW.account_status IS DISTINCT FROM OLD.account_status THEN
      RAISE EXCEPTION 'Account status is managed by the moderation RPCs';
    END IF;
    IF NEW.date_of_birth IS DISTINCT FROM OLD.date_of_birth THEN
      RAISE EXCEPTION 'Date of birth must be updated via update_member_dob';
    END IF;
    IF NEW.anonymized_at IS DISTINCT FROM OLD.anonymized_at THEN
      RAISE EXCEPTION 'Anonymization is managed by the member deletion RPC';
    END IF;
    IF NEW.verification_status IS DISTINCT FROM OLD.verification_status THEN
      RAISE EXCEPTION 'Verification status is managed by the verification RPCs';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS users_guard_account_fields ON public.users;

CREATE TRIGGER users_guard_account_fields
  BEFORE UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.users_guard_account_fields();

-- ─── 5. ACL: REVOKE-before-GRANT ────────────────────────────────────────

REVOKE ALL ON FUNCTION public.reapply_verification(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reapply_verification(text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.reapply_verification(text, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.reapply_verification(text, text)
  TO service_role;

REVOKE ALL ON FUNCTION public.decide_user_verification(uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.decide_user_verification(uuid, text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.decide_user_verification(uuid, text, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.decide_user_verification(uuid, text, text)
  TO service_role;

REVOKE ALL ON FUNCTION public.users_guard_account_fields() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.users_guard_account_fields() FROM anon;

-- ============================================================
-- END 047_verification_reapply.sql
-- ============================================================