-- 162: Rate-limit the email-lookup RPCs (bughunt F7).
-- lookup_email_by_phone / lookup_email_by_username must stay anonymous for the
-- shipped login flow, which makes them enumeration oracles. Full closure needs
-- an app-side move to Supabase phone sign-in; until then, cap attempts per
-- identifier (10/hour) and per caller IP (30/hour). Over-limit returns NULL,
-- indistinguishable from "not found".

create table if not exists public.identifier_lookup_attempts (
  k text primary key,
  window_start timestamptz not null default now(),
  n int not null default 0
);

create or replace function public._lookup_rate_allow(p_k text, p_max int)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_n int;
begin
  insert into public.identifier_lookup_attempts (k, window_start, n)
  values (p_k, now(), 1)
  on conflict (k) do update set
    n = case
          when identifier_lookup_attempts.window_start < now() - interval '1 hour'
          then 1 else identifier_lookup_attempts.n + 1 end,
    window_start = case
          when identifier_lookup_attempts.window_start < now() - interval '1 hour'
          then now() else identifier_lookup_attempts.window_start end
  returning n into v_n;
  return v_n <= p_max;
end;
$$;

create or replace function public._lookup_caller_ip()
returns text
language plpgsql
stable
as $$
declare
  v_headers text;
begin
  v_headers := current_setting('request.headers', true);
  if v_headers is null then return 'unknown'; end if;
  return coalesce(
    split_part((v_headers::json ->> 'x-forwarded-for'), ',', 1),
    'unknown'
  );
exception when others then
  return 'unknown';
end;
$$;

create or replace function public.lookup_email_by_phone(p_phone text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_norm text := public._normalize_egypt_phone(p_phone);
  v_digits text := regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');
  v_last10 text;
  v_email text;
begin
  if length(v_digits) < 9 then
    return null;
  end if;

  if not public._lookup_rate_allow('phone:' || coalesce(v_norm, v_digits), 10) then
    return null;
  end if;
  if not public._lookup_rate_allow('ip:' || public._lookup_caller_ip(), 30) then
    return null;
  end if;

  v_last10 := right(v_digits, 10);

  select email into v_email
    from public.users
   where account_status <> 'deactivated'
     and email is not null
     and email <> ''
     and email not like '%@anonymized.invalid'
     and (
       public._normalize_egypt_phone(phone) = v_norm
       or right(regexp_replace(coalesce(phone, ''), '[^0-9]', '', 'g'), 10) = v_last10
     )
   order by created_at desc
   limit 1;

  return v_email;
end;
$$;

create or replace function public.lookup_email_by_username(p_username text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text;
  v_uname text := lower(btrim(coalesce(p_username, '')));
begin
  if v_uname = '' then
    return null;
  end if;

  if not public._lookup_rate_allow('uname:' || v_uname, 10) then
    return null;
  end if;
  if not public._lookup_rate_allow('ip:' || public._lookup_caller_ip(), 30) then
    return null;
  end if;

  select email into v_email
    from public.users
  where username is not null
    and lower(username) = v_uname
    and account_status <> 'deactivated'
    and email not like '%@anonymized.invalid'
  limit 1;

  return v_email;
end;
$$;
