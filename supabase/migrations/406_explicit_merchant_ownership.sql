BEGIN;
CREATE OR REPLACE FUNCTION public.resolve_my_merchant()
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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

  select id, full_name, email, phone, role, user_type, verification_status,
         active_provider_category
    into v_user from public.users where id = v_uid;
  v_active_cat := v_user.active_provider_category;

  -- Provider app entry is a lookup only. Approval owns target provisioning.
  if v_user.role = 'provider' or v_user.user_type = 'provider' then
    if public._is_home_service_category(v_active_cat) then return null; end if;
    select m.id into v_owned
      from public.provider_business_profiles p
      join public.merchants m on m.id = p.merchant_id
     where p.user_id = v_uid and p.status = 'approved'
       and m.owner_user_id = v_uid
       and not public._is_home_service_category(p.category_type)
       and (nullif(btrim(v_active_cat), '') is null
            or lower(p.category_type) = lower(v_active_cat))
     order by p.created_at asc limit 1;
    return v_owned;
  end if;

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

  select id into v_owned
    from public.merchants
   where owner_user_id = v_uid
   order by (owner_user_id = v_uid) desc, created_at asc
   limit 1;

  if v_owned is not null then
    return v_owned;
  end if;

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

  return null;
end;
$function$
;
COMMIT;
