-- 386: WhatsApp OTP cutover — close the cosmetic verification loop.
--
-- Before this migration a client could pass phone verification without
-- controlling the phone: request_whatsapp_otp returned the code to the
-- caller and verify_whatsapp_otp marked it verified. After this migration
-- the ONLY path that sets verified = true for client-facing flows is the
-- Meta webhook (whatsapp_webhook_mark_verified, service-role only), which
-- fires when the user sends the code from their own WhatsApp number.
--
-- 1) whatsapp_otp_verifications.verified_via records the verification path.
-- 2) verify_whatsapp_otp no longer marks codes verified for anon /
--    authenticated callers; it only confirms a webhook-verified code.
--    service_role keeps the legacy behavior for owner/admin test tooling.
-- 3) New whatsapp_otp_status(p_phone, p_purpose) lets the app poll the
--    verification state without ever seeing a code grant anything.
-- 4) whatsapp_webhook_mark_verified labels its rows verified_via='webhook'.

ALTER TABLE public.whatsapp_otp_verifications
  ADD COLUMN IF NOT EXISTS verified_via text;

-- (4) webhook marks verified AND labels the path
CREATE OR REPLACE FUNCTION public.whatsapp_webhook_mark_verified(p_phone text, p_otp_code text, p_message_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- Data minimization: react ONLY to messages carrying a
  -- code with a pending OTP row. Any other message (e.g. Maqboul customer
  -- chats on the shared number) is ignored: no idempotency row, no log,
  -- no storage of any kind.
  UPDATE public.whatsapp_otp_verifications
     SET verified = true,
         verified_via = 'webhook'
   WHERE phone = p_phone
     AND otp_code = p_otp_code
     AND verified = false
     AND expires_at > now()
     AND (locked_until IS NULL OR locked_until < now());
  IF NOT FOUND THEN
    RETURN false; -- not a platform code: store nothing.
  END IF;

  -- Only now claim the delivery id so Meta retries don't re-notify.
  INSERT INTO public.whatsapp_webhook_messages (message_id, phone)
  VALUES (p_message_id, p_phone)
  ON CONFLICT (message_id) DO NOTHING;
  RETURN true;
END;
$function$
;
REVOKE EXECUTE ON FUNCTION public.whatsapp_webhook_mark_verified(text, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.whatsapp_webhook_mark_verified(text, text, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.whatsapp_webhook_mark_verified(text, text, text) FROM authenticated;

-- (3) status polling: returns the state of the latest code for a phone.
-- Never returns the code itself. anon + authenticated: registration and
-- profile phone-change flows both run pre-auth or as a signed-in user.
CREATE OR REPLACE FUNCTION public.whatsapp_otp_status(p_phone text, p_purpose text DEFAULT 'register'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_norm text := public._normalize_egypt_phone(p_phone);
  v_row public.whatsapp_otp_verifications%rowtype;
begin
  if length(v_norm) < 10 then
    return jsonb_build_object('ok', false, 'code', 'INVALID_PHONE');
  end if;

  select * into v_row
    from public.whatsapp_otp_verifications
   where phone = v_norm
   order by created_at desc
   limit 1;

  if v_row.id is null then
    return jsonb_build_object('ok', true, 'status', 'none');
  end if;

  if v_row.verified then
    return jsonb_build_object('ok', true, 'status', 'verified', 'phone', v_norm);
  end if;

  if v_row.expires_at <= now() then
    return jsonb_build_object('ok', true, 'status', 'expired');
  end if;

  return jsonb_build_object(
    'ok', true,
    'status', 'pending',
    'expires_in_seconds', greatest(0, floor(extract(epoch from (v_row.expires_at - now())))::int)
  );
end;
$function$
;
REVOKE ALL ON FUNCTION public.whatsapp_otp_status(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.whatsapp_otp_status(text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.whatsapp_otp_status(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.whatsapp_otp_status(text, text) TO service_role;

-- (2) verify_whatsapp_otp: client roles can no longer CREATE verification.
-- For anon/authenticated it only succeeds when the row is already verified
-- (by the webhook) and the code matches — a no-op confirmation. The
-- phone-stamping for signed-in users is gated on that same verified state.
-- service_role/postgres keep the legacy mark-verified behavior for test
-- tooling only.
CREATE OR REPLACE FUNCTION public.verify_whatsapp_otp(p_phone text, p_otp_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_norm text := public._normalize_egypt_phone(p_phone);
  v_code text := btrim(coalesce(p_otp_code, ''));
  v_row public.whatsapp_otp_verifications%rowtype;
  v_client_role text := coalesce(auth.role(), '');
begin
  if length(v_norm) < 10 or length(v_code) < 4 then
    return jsonb_build_object('ok', false, 'code', 'INVALID_INPUT');
  end if;

  select * into v_row
    from public.whatsapp_otp_verifications
   where phone = v_norm
     and expires_at > now()
     and verified = false
   order by created_at desc
   limit 1
   for update;

  -- Client callers never flip a row to verified. If the latest code is
  -- still unverified, the user must send it from their own WhatsApp.
  if v_client_role in ('anon', 'authenticated') then
    if v_row.id is not null and v_row.locked_until is not null and v_row.locked_until > now() then
      return jsonb_build_object('ok', false, 'code', 'LOCKED');
    end if;

    -- Already webhook-verified (or service-verified) latest code matching?
    if exists (
      select 1 from public.whatsapp_otp_verifications
       where phone = v_norm
         and otp_code = v_code
         and verified = true
         and created_at > now() - interval '24 hours'
    ) then
      if auth.uid() is not null
         and not exists (
           select 1 from public.users
            where public._normalize_egypt_phone(phone) = v_norm
              and id <> auth.uid()
         ) then
        update public.users
           set phone = v_norm,
               updated_at = now()
         where id = auth.uid();
      end if;
      return jsonb_build_object('ok', true, 'verified', true, 'phone', v_norm);
    end if;

    -- Count the failed guess against the pending row, keep the lockout.
    if v_row.id is not null then
      update public.whatsapp_otp_verifications
         set attempts = attempts + 1,
             locked_until = case when attempts + 1 >= 5 then now() + interval '15 minutes' else locked_until end
       where id = v_row.id;
    end if;
    return jsonb_build_object('ok', false, 'code', 'SEND_CODE_VIA_WHATSAPP');
  end if;

  -- service_role / postgres: legacy behavior for owner/admin test tooling.
  if v_row.id is not null and v_row.locked_until is not null and v_row.locked_until > now() then
    return jsonb_build_object('ok', false, 'code', 'LOCKED');
  end if;

  if v_row.id is null or v_row.otp_code <> v_code then
    if v_row.id is not null then
      update public.whatsapp_otp_verifications
         set attempts = attempts + 1,
             locked_until = case when attempts + 1 >= 5 then now() + interval '15 minutes' else locked_until end
       where id = v_row.id;
    end if;
    return jsonb_build_object('ok', false, 'code', 'INVALID_OR_EXPIRED_OTP');
  end if;

  update public.whatsapp_otp_verifications
     set verified = true,
         verified_via = coalesce(verified_via, 'service')
   where id = v_row.id;

  if auth.uid() is not null
     and not exists (
       select 1 from public.users
        where public._normalize_egypt_phone(phone) = v_norm
          and id <> auth.uid()
     ) then
    update public.users
       set phone = v_norm,
           updated_at = now()
     where id = auth.uid();
  end if;

  return jsonb_build_object('ok', true, 'verified', true, 'phone', v_norm);
end;
$function$
;
REVOKE ALL ON FUNCTION public.verify_whatsapp_otp(p_phone text, p_otp_code text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.verify_whatsapp_otp(p_phone text, p_otp_code text) TO anon;
GRANT EXECUTE ON FUNCTION public.verify_whatsapp_otp(p_phone text, p_otp_code text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_whatsapp_otp(p_phone text, p_otp_code text) TO postgres;
GRANT EXECUTE ON FUNCTION public.verify_whatsapp_otp(p_phone text, p_otp_code text) TO service_role;
