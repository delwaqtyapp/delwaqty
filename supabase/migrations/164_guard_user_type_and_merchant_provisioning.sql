-- 164: Close self-serve unvetted merchant storefronts (bughunt F16).
-- a) users.user_type joins the guarded columns (signup metadata path via
--    handle_new_user is SECURITY DEFINER and stays exempt).
-- b) resolve_my_merchant no longer mints ACTIVE storefronts for
--    merchant/provider users: approved verification -> active; otherwise the
--    row is provisioned as pending + closed so onboarding can continue
--    but the storefront is not live. Platform staff (owner/admin role) keep
--    the old active auto-provision for tooling.

create or replace function public.users_guard_account_fields()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
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
  end if;
  return NEW;
end;
$$;

create or replace function public.resolve_my_merchant()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_active_cat text;
  v_owned uuid;
  v_user record;
  v_seeded uuid;
  v_seeded_count integer;
  v_is_staff boolean;
  v_approved boolean;
begin
  if v_uid is null then
    return null;
  end if;

  select active_provider_category into v_active_cat from public.users where id = v_uid;

  -- 1. If user has an active_provider_category that is a merchant store type, match it first
  if v_active_cat is not null and btrim(v_active_cat) <> '' and not public._is_home_service_category(v_active_cat) then
    select id into v_owned
      from public.merchants
     where owner_user_id = v_uid and lower(type) = lower(v_active_cat)
     order by created_at asc
     limit 1;
    if v_owned is not null then
      return v_owned;
    end if;
  end if;

  -- 2. Otherwise check any merchant owned by this user
  select id into v_owned
    from public.merchants
   where owner_user_id = v_uid or id = v_uid
   order by (owner_user_id = v_uid) desc, created_at asc
   limit 1;

  if v_owned is not null then
    return v_owned;
  end if;

  -- 3. Provision a merchant row. Staff get an active row (tooling); everyone
  --    else gets pending + closed until verification is approved.
  select id, full_name, email, phone, role, user_type, verification_status
    into v_user
    from public.users
   where id = v_uid;

  v_is_staff := v_user.role in ('owner', 'admin');
  v_approved := v_user.verification_status = 'approved';

  if v_user.id is not null and (
    v_is_staff
    or v_user.role in ('merchant', 'provider')
    or v_user.user_type in ('merchant', 'provider')
  ) then
    insert into public.merchants (
      owner_user_id, name, email, phone, type, status, is_open,
      delivery_fee, min_order, delivery_time_min, rating
    )
    values (
      v_uid,
      coalesce(nullif(btrim(v_user.full_name), ''), 'Delwaqty Store'),
      coalesce(v_user.email, ''),
      v_user.phone,
      case
        when v_active_cat is not null and not public._is_home_service_category(v_active_cat) then v_active_cat
        when v_user.user_type = 'provider' or v_user.role = 'provider' then 'service'
        else 'restaurant'
      end,
      case when v_is_staff or v_approved then 'active' else 'pending' end,
      case when v_is_staff or v_approved then true else false end,
      15,
      0,
      30,
      0
    )
    returning id into v_owned;

    return v_owned;
  end if;

  -- 4. Fallback to single unowned seeded merchant
  select count(*) into v_seeded_count
    from public.merchants
   where owner_user_id is null;

  if v_seeded_count = 1 then
    select id into v_seeded
      from public.merchants
     where owner_user_id is null
     limit 1;
    return v_seeded;
  end if;

  return null;
end;
$$;
