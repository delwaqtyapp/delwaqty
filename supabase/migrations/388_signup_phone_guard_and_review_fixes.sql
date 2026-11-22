-- 388 (v2): server-side signup phone guard + review fixes on the WhatsApp
-- OTP trust model (386/387 follow-up). Amended in place per builder review;
-- never applied to prod as v1.
--
-- (1) before-user-created auth hook. Signup paths and their rules:
--       - OAuth (app_metadata.provider <> 'email': Google etc.) -> exempt,
--         untouched.
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
  -- OAuth signups (Google etc.): exempt, untouched.
  if v_provider is not null and v_provider <> 'email' then
    return '{}'::jsonb;
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
