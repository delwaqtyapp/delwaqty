-- 388 (v3): server-side signup phone guard + review fixes on the WhatsApp
-- OTP trust model (386/387 follow-up). Amended in place per builder review;
-- never applied to prod as v1/v2.
-- v3: OAuth exemption is an explicit allow-list (google only, per
-- builder + security reviewer; other providers incl. anonymous are refused
-- with SIGNUP_PROVIDER_NOT_ALLOWED - NOTE: prod currently has Facebook
-- OAuth enabled with app buttons live, so shipping this to prod also
-- requires disabling Facebook or amending the list), and the phone must
-- match the canonical Egyptian mobile shape ^\+201[0-9]{9}$ in both the
-- hook (PHONE_INVALID) and request_whatsapp_otp (INVALID_PHONE).
--
-- (1) before-user-created auth hook. Signup paths and their rules:
--       - Google OAuth is exempt. Other non-email providers, including
--         native phone and anonymous signup, are refused.
--       - Email path with NO phone -> reject EMAIL_SIGNUP_NOT_ALLOWED (a
--         direct email-only API signup must not bypass phone-or-Google).
--       - Conflicting user.phone vs user_metadata.phone -> reject
--         PHONE_MISMATCH (never guess which is real).
--       - Phone signup: auth email must be exactly the canonical technical
--         email for the PROVEN phone (phone_<canonical digits>@delwaqty.app)
--         -> else PHONE_EMAIL_MISMATCH; the normalized phone must not
--         already be bound to an account -> else PHONE_ALREADY_REGISTERED;
--         and the one-time phone_verification_challenge must match a
--         webhook-verified, fresh (<1h), unconsumed register row for that
--         same phone -> else PHONE_NOT_VERIFIED / CHALLENGE_CONSUMED /
--         CHALLENGE_EXPIRED. Consumed atomically: one proof backs exactly
--         one account.
--     The hook must also be ENABLED in auth config per project (not a
--     migration): hook_before_user_created_enabled=true,
--     hook_before_user_created_uri=pg-functions://postgres/public/before_user_created_phone_guard
-- (2) verify_whatsapp_otp revoked from anon/authenticated: clients can no
--     longer call the legacy verify path at all. The function (with its
--     failed-guess counter and lockout) stays for postgres/service_role.
-- (3) consume_whatsapp_reset_challenge: webhook-verified proofs ONLY, and
--     an ambiguous normalized-phone binding authorizes NOTHING (no
--     created_at pick; challenge not burned on refusal).
-- (4) revoke_user_sessions(user_id): service-role session revocation used
--     by the password-reset edge function (GoTrue's documented logout
--     needs the user's own JWT; this deletes the user's auth.sessions and
--     refresh_tokens directly). Note: already-issued access JWTs stay
--     valid until they expire; refresh is cut immediately.
-- (5) Real unique binding: partial unique index on the normalized phone
--     so concurrent signups can never bind one phone to two accounts.
--     Prod audit (2026-11-22): zero duplicate normalized phones, so this
--     builds cleanly on the existing 4 phone-carrying users.
-- (6) audit_normalized_phone_duplicates(): read-only helper for the
--     uniqueness audit. postgres/service_role only.

-- (1) the hook ----------------------------------------------------------------
create or replace function public.before_user_created_phone_guard(event jsonb)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
declare
  v_provider text := nullif(event #>> '{user,app_metadata,provider}', '');
  v_meta_phone text := nullif(event #>> '{user,user_metadata,phone}', '');
  v_user_phone text := nullif(event #>> '{user,phone}', '');
  v_email text := lower(coalesce(event #>> '{user,email}', ''));
  v_challenge_text text := nullif(event #>> '{user,user_metadata,phone_verification_challenge}', '');
  v_challenge uuid;
  v_phone text;
  v_norm text;
  v_row_id uuid;
begin
  -- OAuth signups: explicit allow-list only (the providers enabled in
  -- auth config). Anything else - including anonymous - is refused.
  if v_provider is not null and v_provider <> 'email' then
    if v_provider in ('google') then
      return '{}'::jsonb;
    end if;
    return jsonb_build_object(
      'error', jsonb_build_object(
        'message', 'SIGNUP_PROVIDER_NOT_ALLOWED: this sign-in method is not available.',
        'http_code', 400
      )
    );
  end if;

  -- Conflicting phone fields: refuse rather than guess.
  if v_meta_phone is not null
     and v_user_phone is not null
     and public._normalize_egypt_phone(v_meta_phone) <> public._normalize_egypt_phone(v_user_phone) then
    return jsonb_build_object(
      'error', jsonb_build_object(
        'message', 'PHONE_MISMATCH: conflicting phone numbers in the signup request.',
        'http_code', 400
      )
    );
  end if;

  v_phone := coalesce(v_meta_phone, v_user_phone);

  -- Email path with no phone: would bypass the phone-or-Google rule.
  if v_phone is null then
    return jsonb_build_object(
      'error', jsonb_build_object(
        'message', 'EMAIL_SIGNUP_NOT_ALLOWED: sign up with Google or with a WhatsApp-verified phone number.',
        'http_code', 400
      )
    );
  end if;

  v_norm := public._normalize_egypt_phone(v_phone);

  -- Server-side shape enforcement: Egyptian mobile only, canonical form.
  if v_norm !~ '^\+201[0-9]{9}$' then
    return jsonb_build_object(
      'error', jsonb_build_object(
        'message', 'PHONE_INVALID: enter a valid Egyptian mobile number.',
        'http_code', 400
      )
    );
  end if;

  -- The auth email must be exactly the canonical technical email for the
  -- phone being proven, so the email can never point at a different
  -- identity than the verified phone.
  if v_email <> 'phone_' || substring(v_norm from 2) || '@delwaqty.app' then
    return jsonb_build_object(
      'error', jsonb_build_object(
        'message', 'PHONE_EMAIL_MISMATCH: the account identifier does not match the verified phone.',
        'http_code', 400
      )
    );
  end if;

  -- One account per normalized phone.
  if exists (
    select 1 from public.users
     where public._normalize_egypt_phone(phone) = v_norm
  ) then
    return jsonb_build_object(
      'error', jsonb_build_object(
        'message', 'PHONE_ALREADY_REGISTERED: this phone number already has an account. Log in instead.',
        'http_code', 400
      )
    );
  end if;

  if v_challenge_text is not null then
    begin
      v_challenge := v_challenge_text::uuid;
    exception when others then
      v_challenge := null;
    end;
  end if;

  if v_challenge is not null then
    -- Atomic one-time consume: only an unconsumed, fresh, webhook-verified
    -- register row for THIS phone and THIS challenge authorizes the
    -- signup, and it can never authorize a second one.
    update public.whatsapp_otp_verifications
       set consumed_at = now()
     where challenge = v_challenge
       and phone = v_norm
       and purpose = 'register'
       and verified = true
       and verified_via = 'webhook'
       and consumed_at is null
       and created_at > now() - interval '1 hour'
    returning id into v_row_id;

    if v_row_id is not null then
      return '{}'::jsonb;
    end if;

    -- Rejection reason as a stable token the client switches on
    -- (AuthException.message). Only a row for THIS phone + purpose can
    -- produce CONSUMED/EXPIRED, so this reveals nothing about others.
    if exists (
      select 1 from public.whatsapp_otp_verifications
       where challenge = v_challenge and phone = v_norm and purpose = 'register'
         and consumed_at is not null
    ) then
      return jsonb_build_object(
        'error', jsonb_build_object(
          'message', 'CHALLENGE_CONSUMED: this verification was already used. Request a new code.',
          'http_code', 400
        )
      );
    end if;

    if exists (
      select 1 from public.whatsapp_otp_verifications
       where challenge = v_challenge and phone = v_norm and purpose = 'register'
         and created_at <= now() - interval '1 hour'
    ) then
      return jsonb_build_object(
        'error', jsonb_build_object(
          'message', 'CHALLENGE_EXPIRED: this verification is older than one hour. Request a new code.',
          'http_code', 400
        )
      );
    end if;
  end if;

  return jsonb_build_object(
    'error', jsonb_build_object(
      'message', 'PHONE_NOT_VERIFIED: verify this phone number via WhatsApp before creating the account.',
      'http_code', 400
    )
  );
end;
$function$
;

-- GoTrue invokes the hook as supabase_auth_admin: it needs USAGE on the
-- schema to resolve the function and EXECUTE on it (missing schema USAGE
-- surfaced as a generic 500 'Error running hook URI').
grant usage on schema public to supabase_auth_admin;
grant execute on function public.before_user_created_phone_guard(jsonb) to supabase_auth_admin;
revoke execute on function public.before_user_created_phone_guard(jsonb) from authenticated, anon, public;

-- (2) legacy client verify path off -------------------------------------------
revoke execute on function public.verify_whatsapp_otp(text, text) from anon, authenticated;

-- (3) reset challenge consume: webhook-only, ambiguity refuses -----------------
create or replace function public.consume_whatsapp_reset_challenge(p_phone text, p_challenge uuid)
 returns uuid
 language plpgsql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
declare
  v_norm text := public._normalize_egypt_phone(p_phone);
  v_row public.whatsapp_otp_verifications%rowtype;
  v_user_id uuid;
  v_matches int;
begin
  select * into v_row
    from public.whatsapp_otp_verifications
   where phone = v_norm
     and purpose = 'password_reset'
     and challenge = p_challenge
     and verified = true
     and verified_via = 'webhook'
     and consumed_at is null
     and created_at > now() - interval '1 hour'
   order by created_at desc
   limit 1
   for update;

  if v_row.id is null then
    return null;
  end if;

  -- Exactly one account may hold this normalized phone. Zero: nothing to
  -- reset. More than one: ambiguous, refuse (never pick by created_at).
  select count(*) into v_matches
    from public.users
   where public._normalize_egypt_phone(phone) = v_norm;
  if v_matches <> 1 then
    return null;
  end if;

  select id into v_user_id
    from public.users
   where public._normalize_egypt_phone(phone) = v_norm;

  update public.whatsapp_otp_verifications
     set consumed_at = now()
   where id = v_row.id;

  return v_user_id;
end;
$function$
;
revoke all on function public.consume_whatsapp_reset_challenge(text, uuid) from public;
revoke all on function public.consume_whatsapp_reset_challenge(text, uuid) from anon, authenticated;
grant execute on function public.consume_whatsapp_reset_challenge(text, uuid) to service_role;

-- (4) server-side session revocation -------------------------------------------
create or replace function public.revoke_user_sessions(p_user_id uuid)
 returns void
 language plpgsql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
begin
  delete from auth.refresh_tokens
   where session_id in (select id from auth.sessions where user_id = p_user_id);
  delete from auth.sessions where user_id = p_user_id;
end;
$function$
;
revoke all on function public.revoke_user_sessions(uuid) from public;
revoke all on function public.revoke_user_sessions(uuid) from anon, authenticated;
grant execute on function public.revoke_user_sessions(uuid) to service_role;

-- (5) unique normalized-phone binding -------------------------------------------
create unique index if not exists users_normalized_phone_unique
  on public.users (public._normalize_egypt_phone(phone))
  where phone is not null and btrim(phone) <> '';

-- (6) read-only uniqueness audit -------------------------------------------------
create or replace function public.audit_normalized_phone_duplicates()
 returns table(phone_normalized text, user_count bigint, user_ids uuid[])
 language sql
 stable
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
  select v_norm, count(*), array_agg(id order by created_at)
    from (
      select id, created_at, public._normalize_egypt_phone(phone) as v_norm
        from public.users
       where phone is not null and btrim(phone) <> ''
    ) s
   group by v_norm
  having count(*) > 1
   order by count(*) desc;
$function$
;
revoke all on function public.audit_normalized_phone_duplicates() from public;
revoke all on function public.audit_normalized_phone_duplicates() from anon, authenticated;
grant execute on function public.audit_normalized_phone_duplicates() to postgres, service_role;

-- (7) request_whatsapp_otp: same Egyptian-mobile shape rule at the proof
-- entry point, so no OTP challenge can be requested for a number the hook
-- would reject at signup/reset time.
--
-- (8) #54: public.users.phone can no longer be changed by a direct client
--     UPDATE (users_guard_account_fields now guards it like role/status).
--     A reserved claim_phone_change(phone, challenge) RPC requires a
--     webhook-verified, one-time proof, purpose='phone_change', and checks
--     uniqueness, but is NOT granted to clients until identifier reassignment
--     is designed. The app keeps phone read-only in the meantime.
CREATE OR REPLACE FUNCTION public.request_whatsapp_otp(p_phone text, p_purpose text DEFAULT 'register'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_norm text := public._normalize_egypt_phone(p_phone);
  v_otp text;
  v_support_phone text;
  v_recent int;
  v_challenge uuid := gen_random_uuid();
begin
  -- Egyptian mobile only, canonical shape (same rule the signup hook
  -- enforces): no proof can ever be requested for a non-Egyptian or
  -- malformed number.
  if v_norm !~ '^\+201[0-9]{9}$' then
    return jsonb_build_object('ok', false, 'code', 'INVALID_PHONE');
  end if;

  select count(*) into v_recent
    from public.whatsapp_otp_verifications
   where phone = v_norm
     and created_at > now() - interval '10 minutes';
  if v_recent >= 3 then
    return jsonb_build_object('ok', false, 'code', 'RATE_LIMITED');
  end if;

  update public.whatsapp_otp_verifications
     set expires_at = now()
   where phone = v_norm
     and expires_at > now()
     and verified = false;

  v_otp := lpad((floor(random() * 900000) + 100000)::int::text, 6, '0');

  insert into public.whatsapp_otp_verifications (phone, otp_code, purpose, verified, expires_at, challenge)
  values (v_norm, v_otp, coalesce(nullif(btrim(p_purpose), ''), 'register'), false, now() + interval '10 minutes', v_challenge);

  select coalesce(nullif(support_phone, ''), '+201000000000')
    into v_support_phone
    from public.platform_settings
   where id = 'default';

  return jsonb_build_object(
    'ok', true,
    'phone', v_norm,
    'otp_code', v_otp,
    'challenge', v_challenge,
    'whatsapp_number', coalesce(v_support_phone, '+201000000000'),
    'expires_in_seconds', 600
  );
end;
$function$
;

-- (8a) guard: phone is proof-managed --------------------------------------
create or replace function public.users_guard_account_fields()
 returns trigger
 language plpgsql
 set search_path to 'public'
as $function$
begin
  if auth.uid() is null then
    return NEW;
  end if;
  if current_user in ('authenticated', 'anon') then
    if NEW.role is distinct from OLD.role then
      raise exception 'Role is managed by the admin lifecycle RPCs';
    end if;
    if NEW.account_status is distinct from OLD.account_status then
      raise exception 'Account status is managed by the moderation RPCs';
    end if;
    if NEW.date_of_birth is distinct from OLD.date_of_birth then
      raise exception 'Date of birth must be updated via update_member_dob';
    end if;
    if NEW.anonymized_at is distinct from OLD.anonymized_at then
      raise exception 'Anonymization is managed by the member deletion RPC';
    end if;
    if NEW.verification_status is distinct from OLD.verification_status then
      raise exception 'Verification status is managed by the verification RPCs';
    end if;
    if NEW.user_type is distinct from OLD.user_type then
      raise exception 'User type is managed by the account lifecycle RPCs';
    end if;
    if NEW.phone is distinct from OLD.phone then
      raise exception 'Phone number is managed by the WhatsApp-verified claim_phone_change RPC';
    end if;
  end if;
  return NEW;
end;
$function$;

-- (8b) challenge-bound phone change for signed-in users --------------------
create or replace function public.claim_phone_change(p_phone text, p_challenge uuid)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid uuid := auth.uid();
  v_norm text := public._normalize_egypt_phone(p_phone);
  v_row_id uuid;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'code', 'NOT_AUTHENTICATED');
  end if;
  if v_norm !~ '^\+201[0-9]{9}$' then
    return jsonb_build_object('ok', false, 'code', 'INVALID_PHONE');
  end if;
  if p_challenge is null then
    return jsonb_build_object('ok', false, 'code', 'CHALLENGE_REQUIRED');
  end if;

  -- Atomic one-time consume of a webhook-verified phone_change proof.
  update public.whatsapp_otp_verifications
     set consumed_at = now()
   where challenge = p_challenge
     and phone = v_norm
     and purpose = 'phone_change'
     and verified = true
     and verified_via = 'webhook'
     and consumed_at is null
     and created_at > now() - interval '1 hour'
  returning id into v_row_id;

  if v_row_id is null then
    return jsonb_build_object('ok', false, 'code', 'PHONE_NOT_VERIFIED');
  end if;

  -- One account per normalized phone.
  if exists (
    select 1 from public.users
     where public._normalize_egypt_phone(phone) = v_norm
       and id <> v_uid
  ) then
    return jsonb_build_object('ok', false, 'code', 'PHONE_ALREADY_REGISTERED');
  end if;

  update public.users
     set phone = v_norm,
         updated_at = now()
   where id = v_uid;

  return jsonb_build_object('ok', true, 'phone', v_norm);
end;
$function$
;
-- RESERVED INTERNAL FUNCTION, NOT A CLIENT PHONE-CHANGE PATH.
-- Changing public.users.phone alone leaves the former technical auth email
-- reserved. Identifier reassignment needs its own design, including Google
-- users whose real email must never be rewritten. Keep client execution
-- revoked until that work is complete; the app displays phone read-only.
revoke all on function public.claim_phone_change(text, uuid) from public;
revoke all on function public.claim_phone_change(text, uuid) from anon, authenticated;
grant execute on function public.claim_phone_change(text, uuid) to service_role;
