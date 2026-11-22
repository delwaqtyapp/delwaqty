-- Prevent home-service signup from polluting the merchant catalog.
-- No backfill, data deletion, grants, or policy changes.
CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$;
DECLARE
  v_user_type TEXT := COALESCE(
    NULLIF(NEW.raw_user_meta_data->>'user_type', ''),
    'customer'
  );
  v_require_docs BOOLEAN := false;
  v_verification TEXT;
  v_full_name TEXT := COALESCE(
    NULLIF(NEW.raw_user_meta_data->>'full_name', ''),
    'User'
  );
  v_phone TEXT := COALESCE(
    NULLIF(NEW.phone, ''),
    NULLIF(NEW.raw_user_meta_data->>'phone', '')
  );
  v_language TEXT := COALESCE(
    NULLIF(NEW.raw_user_meta_data->>'language', ''),
    'ar'
  );
BEGIN
  SELECT COALESCE(require_provider_documents, false)
    INTO v_require_docs
    FROM public.platform_settings
   WHERE id = 'default';

  -- SECURITY: never trust verification_status from client-supplied signup
  -- metadata (anyone with the public anon key can set it). Derive it here.
  v_verification := CASE
    WHEN v_user_type = 'customer' THEN 'approved'
    WHEN v_user_type IN ('merchant', 'provider') AND NOT COALESCE(v_require_docs, false) THEN 'approved'
    ELSE 'pending'
  END;

  INSERT INTO public.users (
    id, email, full_name, phone, language, is_onboarded,
    role, user_type, verification_status, created_at, updated_at
  )
  VALUES (
    NEW.id,
    COALESCE(NEW.email, ''),
    v_full_name,
    v_phone,
    v_language,
    true,
    v_user_type,
    v_user_type,
    v_verification,
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE
    SET phone = COALESCE(EXCLUDED.phone, public.users.phone),
        full_name = CASE
          WHEN public.users.full_name IS NULL OR public.users.full_name = '' OR public.users.full_name = 'User'
          THEN EXCLUDED.full_name
          ELSE public.users.full_name
        END,
        verification_status = CASE
          WHEN v_user_type IN ('merchant', 'provider') AND NOT COALESCE(v_require_docs, false)
          THEN 'approved'
          ELSE public.users.verification_status
        END,
        updated_at = NOW();

  -- Merchant signup creates its storefront. Provider targets are created only
  -- by the category-aware business approval/provisioning flow.
  IF v_user_type = 'merchant' THEN
    IF NOT EXISTS (SELECT 1 FROM public.merchants WHERE owner_user_id = NEW.id) THEN
      INSERT INTO public.merchants (
        owner_user_id, name, email, phone, type, status, is_open,
        delivery_fee, min_order, delivery_time_min, rating
      )
      VALUES (
        NEW.id,
        v_full_name,
        COALESCE(NEW.email, ''),
        v_phone,
        'restaurant',
        'active',
        true,
        15,
        0,
        30,
        5.0
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;


-- Provider app entry must not recreate a storefront.
CREATE OR REPLACE FUNCTION public.resolve_my_merchant()
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$;
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
   where owner_user_id = v_uid or id = v_uid
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
$function$;

