-- 390: cached carts cannot order closed/suspended stores; status RPC honors lifecycle.
CREATE OR REPLACE FUNCTION public.create_order(p_merchant_id uuid, p_items jsonb, p_delivery_address text DEFAULT NULL::text, p_delivery_latitude numeric DEFAULT NULL::numeric, p_delivery_longitude numeric DEFAULT NULL::numeric, p_payment_method text DEFAULT 'cash'::text, p_coupon_code text DEFAULT NULL::text, p_special_instructions text DEFAULT NULL::text, p_idempotency_key text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_merchant public.merchants%rowtype;
  v_item jsonb;
  v_product public.products%rowtype;
  v_qty int;
  v_subtotal numeric := 0;
  v_delivery_fee numeric := 0;
  v_discount numeric := 0;
  v_total numeric;
  v_order_id uuid;
  v_coupon jsonb;
  v_coupon_id uuid;
  v_lines jsonb := '[]'::jsonb;
  v_line jsonb;
  v_existing uuid;
  v_stock_touched boolean := false;
  v_unit_price numeric;
  v_modifier_id text;
  v_modifier record;
  v_modifiers jsonb;
  v_selected_groups uuid[];
  v_group record;
  v_max_radius_km numeric;
  v_distance_km numeric;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if (select u.account_status from public.users u where u.id = v_uid) in ('suspended', 'banned') then
    raise exception 'ACCOUNT_SUSPENDED';
  end if;

  -- Same set as orders_payment_method_check. card/wallet orders are
  -- created with payment_status 'pending'; charging stays a separate flow.
  if p_payment_method not in ('cash', 'card', 'wallet', 'instapay', 'vodafone_cash') then
    raise exception 'INVALID_PAYMENT_METHOD';
  end if;

  -- F4a: an order without delivery coordinates is undispatchable. No
  -- pickup-only order type exists in create_order, so every order must
  -- carry an address and coordinates.
  if p_delivery_latitude is null or p_delivery_longitude is null
     or p_delivery_address is null or btrim(p_delivery_address) = '' then
    raise exception 'MISSING_DELIVERY_LOCATION';
  end if;

  if p_idempotency_key is not null then
    select id into v_existing from public.orders
    where user_id = v_uid and idempotency_key = p_idempotency_key;
    if v_existing is not null then
      return jsonb_build_object(
        'ok', true, 'order_id', v_existing, 'idempotent_replay', true
      );
    end if;
  end if;

  select * into v_merchant from public.merchants where id = p_merchant_id;
  if not found then
    raise exception 'MERCHANT_NOT_FOUND';
  end if;

  -- A cached cart is not permission to order from a closed/suspended store.
  if v_merchant.status is distinct from 'active' then
    raise exception 'MERCHANT_UNAVAILABLE';
  end if;
  if v_merchant.is_open is distinct from true then
    raise exception 'MERCHANT_CLOSED';
  end if;

  -- Reviewer batch 21: reject delivery addresses outside the store's
  -- delivery reach. delivery_zones.radius_km circles are centered on the
  -- merchant's own coordinates (the table carries no separate center). With
  -- no active zones configured, merchant_profiles.max_delivery_radius_km is
  -- the fallback. A merchant with neither declares no reach, so no limit is
  -- enforced for them.
  if v_merchant.latitude is not null and v_merchant.longitude is not null
     and p_delivery_latitude is not null and p_delivery_longitude is not null then
    select max(z.radius_km) into v_max_radius_km
    from public.delivery_zones z
    where z.merchant_id = p_merchant_id and z.is_active;
    if v_max_radius_km is null then
      select mp.max_delivery_radius_km into v_max_radius_km
      from public.merchant_profiles mp
      where mp.merchant_id = p_merchant_id and mp.is_active;
    end if;
    if v_max_radius_km is not null then
      v_distance_km := 6371.0 * 2.0 * asin(sqrt(
        pow(sin(radians((p_delivery_latitude - v_merchant.latitude)::double precision / 2.0)), 2.0) +
        cos(radians(v_merchant.latitude::double precision)) *
        cos(radians(p_delivery_latitude::double precision)) *
        pow(sin(radians((p_delivery_longitude - v_merchant.longitude)::double precision / 2.0)), 2.0)
      ));
      if v_distance_km > v_max_radius_km then
        raise exception 'DELIVERY_OUT_OF_ZONE';
      end if;
    end if;
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'EMPTY_CART';
  end if;
  if jsonb_array_length(p_items) > 100 then
    raise exception 'TOO_MANY_ITEMS';
  end if;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_line := public._price_order_line(p_merchant_id, v_item, true);
    v_stock_touched := v_stock_touched or (v_line->>'stock_decremented')::boolean;
    v_subtotal := v_subtotal + (v_line->>'total_price')::numeric;
    v_lines := v_lines || (v_line - 'stock_decremented' - 'name' - 'name_ar');
  end loop;

  v_delivery_fee := coalesce(v_merchant.delivery_fee, 0);

  if v_merchant.min_order is not null and v_subtotal < v_merchant.min_order then
    raise exception 'BELOW_MIN_ORDER %', v_merchant.min_order;
  end if;

  if p_coupon_code is not null and btrim(p_coupon_code) <> '' then
    v_coupon := public.redeem_coupon(p_coupon_code, v_uid);
    if not (v_coupon->>'success')::boolean then
      raise exception 'COUPON_%', upper(v_coupon->>'reason');
    end if;
    if (v_coupon->>'merchant_id') is not null
       and (v_coupon->>'merchant_id')::uuid <> p_merchant_id then
      raise exception 'COUPON_WRONG_MERCHANT';
    end if;
    if (v_coupon->>'minimum_order') is not null
       and v_subtotal < (v_coupon->>'minimum_order')::numeric then
      raise exception 'COUPON_MIN_ORDER_NOT_MET';
    end if;
    v_coupon_id := (v_coupon->>'coupon_id')::uuid;
    if v_coupon->>'discount_type' = 'percentage' then
      v_discount := round(v_subtotal * (v_coupon->'discount_value')::numeric / 100.0, 2);
    else
      v_discount := (v_coupon->>'discount_value')::numeric;
    end if;
    if (v_coupon->>'maximum_discount') is not null then
      v_discount := least(v_discount, (v_coupon->>'maximum_discount')::numeric);
    end if;
    v_discount := least(v_discount, v_subtotal);
  end if;

  v_total := v_subtotal + v_delivery_fee - v_discount;
  if v_total < 0 then
    v_total := 0;
  end if;

  insert into public.orders (
    user_id, merchant_id, merchant_name, status, payment_status,
    payment_method, subtotal, delivery_fee, discount, tax, total_amount,
    coupon_id, delivery_address, delivery_latitude, delivery_longitude,
    special_instructions, items, idempotency_key, dispatch_status,
    stock_decremented
  ) values (
    v_uid, p_merchant_id, v_merchant.name, 'pending', 'pending',
    p_payment_method, v_subtotal, v_delivery_fee, v_discount, 0, v_total,
    v_coupon_id, p_delivery_address, p_delivery_latitude, p_delivery_longitude,
    p_special_instructions, v_lines, p_idempotency_key, 'PENDING_DISPATCH',
    v_stock_touched
  )
  returning id into v_order_id;

  insert into public.order_items (order_id, product_id, product_name, quantity, unit_price, total_price, modifiers)
  select v_order_id,
         (l->>'product_id')::uuid,
         l->>'product_name',
         (l->>'quantity')::int,
         (l->>'unit_price')::numeric,
         (l->>'total_price')::numeric,
         coalesce(l->'modifiers', '[]'::jsonb)
  from jsonb_array_elements(v_lines) l;

  return jsonb_build_object(
    'ok', true,
    'order_id', v_order_id,
    'subtotal', v_subtotal,
    'delivery_fee', v_delivery_fee,
    'discount', v_discount,
    'total_amount', v_total,
    'status', 'pending',
    'idempotent_replay', false
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.update_order_status(p_order_id uuid, p_status text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid      uuid := auth.uid();
  v_order    public.orders;
  v_is_admin boolean;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED');
  END IF;

  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF v_order.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND');
  END IF;

  -- Authorize: merchant owner of the order, OR admin
  IF NOT public._admin_write_scope(public._ops_scope_region(public._merchant_region_id(v_order.merchant_id))) THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.merchants m
       WHERE m.id = v_order.merchant_id AND m.owner_user_id = v_uid
    ) THEN
      RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
    END IF;
  END IF;

  IF p_status NOT IN ('confirmed','preparing','ready','delivering','delivered','cancelled') THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_STATUS');
  END IF;

  v_is_admin := public._admin_write_scope(public._ops_scope_region(public._merchant_region_id(v_order.merchant_id)));
  IF v_order.status IN ('delivered','cancelled') THEN
    RETURN jsonb_build_object('ok', false, 'code', 'TERMINAL_STATE', 'status', v_order.status);
  END IF;
  IF p_status=v_order.status THEN
    RETURN jsonb_build_object('ok',true,'code','OK','status',p_status);
  END IF;
  -- Use the reviewed finalizers, not a bare status write that skips refunds,
  -- stock/coupon release or recipient handoff checks.
  IF p_status='cancelled' THEN
    IF v_is_admin THEN RETURN public.cancel_order(p_order_id,'Cancelled by admin');
    ELSE RETURN public.merchant_reject_order(p_order_id,NULL); END IF;
  END IF;
  IF p_status='delivered' THEN
    RETURN jsonb_build_object('ok',false,'code','USE_COMPLETION_FLOW');
  END IF;
  IF NOT (
    (v_order.status='pending' AND p_status='confirmed') OR
    (v_order.status='confirmed' AND p_status='preparing') OR
    (v_order.status='preparing' AND p_status='ready') OR
    (v_order.status='ready' AND p_status='delivering')
  ) THEN
    RETURN jsonb_build_object('ok',false,'code','INVALID_TRANSITION');
  END IF;
  IF p_status='delivering' THEN
    IF v_order.driver_id IS NULL THEN
      RETURN jsonb_build_object('ok',false,'code','DRIVER_REQUIRED');
    END IF;
    IF EXISTS(SELECT 1 FROM public.rides r WHERE r.order_id=p_order_id) THEN
      RETURN jsonb_build_object('ok',false,'code','USE_ASSIGNED_DELIVERY_FLOW');
    END IF;
  END IF;

  UPDATE public.orders
     SET status = p_status, updated_at = now()
   WHERE id = p_order_id;

  RETURN jsonb_build_object('ok', true, 'code', 'OK', 'status', p_status);
END;
$function$;

-- Read only the linkage bit through RLS for the order's own merchant/admin.
create or replace function public.order_has_linked_delivery(p_order_id uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select exists(select 1 from public.rides r join public.orders o on o.id=r.order_id
    where o.id=p_order_id and auth.uid() is not null
      and (public.is_merchant_owner(o.merchant_id)
        or public._admin_write_scope(public._ops_scope_region(public._merchant_region_id(o.merchant_id)))));
$$;
revoke all on function public.order_has_linked_delivery(uuid) from public,anon;
grant execute on function public.order_has_linked_delivery(uuid) to authenticated;

CREATE OR REPLACE FUNCTION public.orders_guard_sensitive()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare
  v_merchant_owner boolean;
begin
  -- DEFINER RPCs and backend run as the table owner.
  if current_user not in ('authenticated', 'anon') then
    return new;
  end if;
  if public._is_active_admin_uid(auth.uid()) then
    return new;
  end if;

  -- Freeze everything except status + updated_at for ALL direct client writes.
  if (to_jsonb(new) - 'status' - 'updated_at') is distinct from
     (to_jsonb(old) - 'status' - 'updated_at') then
    raise exception 'order fields are managed by the order RPCs';
  end if;

  v_merchant_owner := public.is_merchant_owner(old.merchant_id);

  if new.status is distinct from old.status then
    if not v_merchant_owner then
      raise exception 'order status is managed by the order RPCs';
    end if;
    if new.status='delivering' then
      if old.driver_id is null then raise exception 'DRIVER_REQUIRED'; end if;
      if public.order_has_linked_delivery(old.id) then
        raise exception 'USE_ASSIGNED_DELIVERY_FLOW';
      end if;
    end if;
    -- Forward-only kitchen pairs; delivered/cancelled are terminal here;
    -- completion via merchant_complete_order, cancellation via RPCs.
    if not (
      (old.status = 'pending'   and new.status = 'confirmed') or
      (old.status = 'confirmed' and new.status = 'preparing') or
      (old.status = 'preparing' and new.status = 'ready') or
      (old.status = 'ready'     and new.status = 'delivering')
    ) then
      raise exception 'unsupported order status transition: % -> %', old.status, new.status;
    end if;
  end if;

  return new;
end;
$function$;

