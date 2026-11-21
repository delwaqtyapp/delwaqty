-- 165: Harden WhatsApp OTP (bughunt F8).
-- NOTE: the current UX has the app prefill the code and the user "send" it via
-- wa.me - verify_whatsapp_otp cannot confirm the message was ever sent, so the
-- flow is not true phone ownership proof until the Meta webhook confirms
-- inbound messages. otp_code must stay in the response for the shipped app.
-- This migration closes everything closable backend-only:
--   a) new request invalidates all older unexpired codes for the phone
--      (multi-code amplification closed);
--   b) request rate cap: max 3 codes per phone per 10 minutes;
--   c) verify attempt limiting: 5 failed attempts locks the phone for 15 min;
--   d) phone stamping on verify only for authenticated callers and only when
--      the phone is not already linked to a DIFFERENT account (stops stamping
--      a victim's phone onto an attacker's account).

alter table public.whatsapp_otp_verifications
  add column if not exists attempts int not null default 0,
  add column if not exists locked_until timestamptz;

create or replace function public.request_whatsapp_otp(p_phone text, p_purpose text default 'register')
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_norm text := public._normalize_egypt_phone(p_phone);
  v_otp text;
  v_support_phone text;
  v_recent int;
begin
  if length(v_norm) < 10 then
    return jsonb_build_object('ok', false, 'code', 'INVALID_PHONE');
  end if;

  -- c) request cap: 3 codes per phone per 10 minutes
  select count(*) into v_recent
    from public.whatsapp_otp_verifications
   where phone = v_norm
     and created_at > now() - interval '10 minutes';
  if v_recent >= 3 then
    return jsonb_build_object('ok', false, 'code', 'RATE_LIMITED');
  end if;

  -- a) invalidate all older unexpired codes for this phone
  update public.whatsapp_otp_verifications
     set expires_at = now()
   where phone = v_norm
     and expires_at > now()
     and verified = false;

  v_otp := lpad((floor(random() * 900000) + 100000)::int::text, 6, '0');

  insert into public.whatsapp_otp_verifications (phone, otp_code, purpose, verified, expires_at)
  values (v_norm, v_otp, coalesce(nullif(btrim(p_purpose), ''), 'register'), false, now() + interval '10 minutes');

  select coalesce(nullif(support_phone, ''), '+201000000000')
    into v_support_phone
    from public.platform_settings
   where id = 'default';

  return jsonb_build_object(
    'ok', true,
    'phone', v_norm,
    'otp_code', v_otp,
    'whatsapp_number', coalesce(v_support_phone, '+201000000000'),
    'expires_in_seconds', 600
  );
end;
$$;

create or replace function public.verify_whatsapp_otp(p_phone text, p_otp_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_norm text := public._normalize_egypt_phone(p_phone);
  v_code text := btrim(coalesce(p_otp_code, ''));
  v_row public.whatsapp_otp_verifications%rowtype;
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

  -- b) lockout: locked phone rejects even correct codes until lock expires
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
     set verified = true
   where id = v_row.id;

  -- d) stamp phone only for authenticated callers, and never onto an account
  --    when the phone already belongs to a DIFFERENT account
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

  return jsonb_build_object(
    'ok', true,
    'verified', true,
    'phone', v_norm
  );
end;
$$;
