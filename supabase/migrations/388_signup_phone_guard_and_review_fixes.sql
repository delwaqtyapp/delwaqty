-- 388: server-side signup phone guard + review fixes on the WhatsApp OTP
-- trust model (386/387 follow-up).
--
-- (1) before-user-created auth hook: a signup carrying a phone number is
--     only allowed when the client presents phone_verification_challenge
--     (the uuid returned by request_whatsapp_otp to THIS caller) and the
--     matching row is purpose='register', verified via webhook/service,
--     fresh (<1h) and unconsumed. The hook consumes it atomically: one
--     verification backs exactly one account creation. Signups without a
--     phone (Google OAuth) are untouched.
--     The hook must also be ENABLED in auth config per project (not a
--     migration): hook_before_user_created_enabled=true,
--     hook_before_user_created_uri=pg-functions://postgres/public/before_user_created_phone_guard
-- (2) verify_whatsapp_otp is revoked from anon/authenticated: clients can
--     no longer call the legacy verify path at all. The function (with its
--     failed-guess counter and lockout) stays for postgres/service_role
--     tooling only.
-- (3) consume_whatsapp_reset_challenge no longer picks a user by
--     created_at when several accounts share one normalized phone: an
--     ambiguous binding authorizes NOTHING (returns null).
-- (4) audit_normalized_phone_duplicates(): read-only helper that lists
--     normalized phones bound to more than one account, for the review's
--     uniqueness audit. postgres/service_role only.

-- (1) the hook ----------------------------------------------------------------
create or replace function public.before_user_created_phone_guard(event jsonb)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
declare
  v_phone text := coalesce(
    nullif(event #>> '{user,user_metadata,phone}', ''),
    nullif(event #>> '{user,phone}', '')
  );
  v_challenge_text text := nullif(event #>> '{user,user_metadata,phone_verification_challenge}', '');
  v_challenge uuid;
  v_norm text;
  v_row_id uuid;
begin
  -- No phone on the signup: nothing to enforce (Google sign-in etc.).
  if v_phone is null then
    return '{}'::jsonb;
  end if;

  v_norm := public._normalize_egypt_phone(v_phone);

  if v_challenge_text is not null then
    begin
      v_challenge := v_challenge_text::uuid;
    exception when others then
      v_challenge := null;
    end;
  end if;

  if v_challenge is not null then
    -- Atomic one-time consume: only an unconsumed, fresh, webhook/service
    -- verified register row for THIS phone and THIS challenge authorizes
    -- the signup, and it can never authorize a second one.
    update public.whatsapp_otp_verifications
       set consumed_at = now()
     where challenge = v_challenge
       and phone = v_norm
       and purpose = 'register'
       and verified = true
       and verified_via in ('webhook', 'service')
       and consumed_at is null
       and created_at > now() - interval '1 hour'
    returning id into v_row_id;

    if v_row_id is not null then
      return '{}'::jsonb;
    end if;

    -- Rejection reason, as a stable token the client switches on
    -- (AuthException.message). Only a row for THIS phone + purpose can
    -- produce CONSUMED/EXPIRED, so this never reveals other phones' state.
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

-- (3) ambiguous phone->account bindings authorize nothing ----------------------
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
     and verified_via in ('webhook', 'service')
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

-- (4) read-only uniqueness audit ------------------------------------------------
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
