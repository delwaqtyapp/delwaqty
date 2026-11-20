-- Run after migration 152. Every fixture and resulting row is rolled back.
-- Verifies: OTP codes and push config are unreadable/unwritable by clients,
-- promo redemptions and trip events are append-only, and complainants
-- cannot write the admin side of a complaint.
BEGIN;
DO $$
DECLARE
  u uuid := gen_random_uuid();
  complaint_id uuid := gen_random_uuid();
  redemption_id uuid := gen_random_uuid();
  v_count int;
  v_blocked boolean;
BEGIN
  INSERT INTO auth.users(id,email) VALUES (u,u::text||'@example.invalid');
  INSERT INTO public.users(id,email) VALUES (u,u::text||'@example.invalid')
    ON CONFLICT(id) DO NOTHING;

  INSERT INTO public.promo_codes(id, code, discount_value)
    VALUES (gen_random_uuid(), 'FIXTURE152', 10);

  -- fixture OTP row inserted as table owner, then proven invisible to clients
  INSERT INTO public.whatsapp_otp_verifications(phone, otp_code, purpose, verified, expires_at)
    VALUES ('+201099999999', '999999', 'login', false, now() + interval '5 minutes');

  PERFORM set_config('request.jwt.claim.sub', u::text, true);
  PERFORM set_config('role','authenticated',true);

  -- 1. OTP table: no read, no insert for clients.
  SELECT count(*) INTO v_count FROM public.whatsapp_otp_verifications;
  IF v_count <> 0 THEN RAISE EXCEPTION 'client can read OTP rows'; END IF;
  v_blocked := false;
  BEGIN
    INSERT INTO public.whatsapp_otp_verifications(phone, otp_code, purpose, verified, expires_at)
      VALUES ('+201000000000', '123456', 'login', true, now() + interval '5 minutes');
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'client inserted an OTP row'; END IF;

  -- 2. push config: no read, no insert for clients (grant-level denial).
  v_blocked := false;
  BEGIN
    PERFORM count(*) FROM public.notification_push_config;
  EXCEPTION WHEN insufficient_privilege THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'client can read push config'; END IF;
  v_blocked := false;
  BEGIN
    INSERT INTO public.notification_push_config(is_enabled) VALUES (false);
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'client wrote push config'; END IF;

  -- 3. promo redemptions: insert allowed, delete denied.
  INSERT INTO public.promo_redemptions(id, user_id, promo_id)
    SELECT redemption_id, u, id FROM public.promo_codes WHERE code = 'FIXTURE152';
  v_blocked := false;
  BEGIN
    DELETE FROM public.promo_redemptions WHERE id = redemption_id;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    IF v_count > 0 THEN RAISE EXCEPTION 'keep'; END IF;
  EXCEPTION WHEN insufficient_privilege THEN v_blocked := true;
  END;
  IF EXISTS (SELECT 1 FROM public.promo_redemptions WHERE id = redemption_id) THEN
    NULL; -- still there, good
  ELSE
    RAISE EXCEPTION 'user deleted own redemption';
  END IF;

  -- 4. complaints: complainant edits own text but not admin fields.
  INSERT INTO public.complaints(id, complainant_id, complaint_type, subject, description)
    VALUES (complaint_id, u, 'other', 'fixture complaint', 'initial detail');
  UPDATE public.complaints SET description = 'more detail' WHERE id = complaint_id;

  -- pre-existing fixup trigger silently neutralizes non-admin status writes:
  -- the attempt does not raise, but the value must not stick.
  UPDATE public.complaints SET status = 'resolved' WHERE id = complaint_id;
  IF (SELECT status FROM public.complaints WHERE id = complaint_id) = 'resolved' THEN
    RAISE EXCEPTION 'complainant resolved own complaint';
  END IF;

  v_blocked := false;
  BEGIN
    UPDATE public.complaints SET priority = 'urgent' WHERE id = complaint_id;
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  -- priority may be neutralized silently (fixup) or raise (guard): assert value
  UPDATE public.complaints SET priority = 'urgent' WHERE id = complaint_id;
  IF (SELECT priority FROM public.complaints WHERE id = complaint_id) = 'urgent' THEN
    RAISE EXCEPTION 'complainant raised own priority';
  END IF;

  v_blocked := false;
  BEGIN
    UPDATE public.complaints SET admin_notes = 'fake admin note' WHERE id = complaint_id;
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'complainant wrote admin notes'; END IF;

  PERFORM set_config('role','none',true);
END;
$$;
ROLLBACK;
