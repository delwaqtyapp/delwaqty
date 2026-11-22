-- Forward integration: preserve 395 credit, live checkout guards, and 398 Cairo schedule enforcement.
-- No money is moved by this function definition.
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
  v_credit numeric := 0;
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
  if v_merchant.is_open is distinct from true
     or public.working_hours_open_at(p_merchant_id) is false then
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

  -- 395: a same-key twin that loses the check-then-insert race blocks on
  -- idx_orders_idempotency_key until the winner commits, then raises
  -- unique_violation; convert it into the same clean replay the sequential
  -- path returns instead of an error.
  begin
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
  exception
    when unique_violation then
      if p_idempotency_key is null then
        raise;
      end if;
      select id into v_existing from public.orders
      where user_id = v_uid and idempotency_key = p_idempotency_key;
      if v_existing is null then
        raise;
      end if;
      return jsonb_build_object(
        'ok', true, 'order_id', v_existing, 'idempotent_replay', true
      );
  end;

  insert into public.order_items (order_id, product_id, product_name, quantity, unit_price, total_price, modifiers)
  select v_order_id,
         (l->>'product_id')::uuid,
         l->>'product_name',
         (l->>'quantity')::int,
         (l->>'unit_price')::numeric,
         (l->>'total_price')::numeric,
         coalesce(l->'modifiers', '[]'::jsonb)
  from jsonb_array_elements(v_lines) l;

  -- 395: the delay-apology gift is spendable here as platform credit. The
  -- server recomputes the amount due; the credit covers up to that amount,
  -- never more than the gift balance, never below zero. The credit ledger
  -- and audit rows are written inside _platform_credit_spend under the
  -- credit-account row lock, so concurrent checkouts cannot double-spend.
  v_credit := public._platform_credit_spend(v_uid, v_order_id, v_total);
  if v_credit > 0 then
    update public.orders
       set total_amount = total_amount - v_credit,
           platform_credit_applied = v_credit,
           updated_at = now()
     where id = v_order_id;
    v_total := v_total - v_credit;
  end if;

  return jsonb_build_object(
    'ok', true,
    'order_id', v_order_id,
    'subtotal', v_subtotal,
    'delivery_fee', v_delivery_fee,
    'discount', v_discount,
    'platform_credit_applied', v_credit,
    'total_amount', v_total,
    'status', 'pending',
    'idempotent_replay', false
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.cancel_order(p_order_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_order public.orders%rowtype;
  v_uid uuid := auth.uid();
  v_suspend_after boolean := false;
  v_refunded boolean := false;
  v_actor uuid;
  v_driver_uid uuid;
  v_merchant_uid uuid;
  v_short text;
  v_suspension_days integer;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED');
  end if;

  select * into v_order from public.orders where id = p_order_id for update;
  if v_order.id is null then
    return jsonb_build_object('ok', false, 'code', 'NOT_FOUND');
  end if;

  if v_order.user_id is distinct from v_uid and not public._admin_write_scope(public._ops_scope_region(public._merchant_region_id(v_order.merchant_id))) then
    return jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  end if;

  if v_order.status in ('delivered', 'cancelled') then
    return jsonb_build_object('ok', false, 'code', 'NOT_CANCELLABLE', 'status', v_order.status);
  end if;

  -- Customer self-cancel policy (owner-confirmed 2026-11-21, mig 185):
  -- no solo-cancel once the order is out for delivery, and a MONTHLY
  -- allowance of 2 customer cancels (Cairo calendar month; further cancels
  -- go through merchant/support).
  if v_uid = v_order.user_id and not public._admin_write_scope(public._ops_scope_region(public._merchant_region_id(v_order.merchant_id))) then
    if v_order.status = 'delivering' then
      return jsonb_build_object('ok', false, 'code', 'OUT_FOR_DELIVERY', 'status', v_order.status);
    end if;
    -- 188: the 3rd monthly cancel EXECUTES and triggers a suspension
    -- (length configurable by the owner since 393); it is not blocked.
    if (select count(*) from public.orders
         where user_id = v_uid and cancelled_by = 'customer'
           and cancelled_at >= date_trunc('month', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo') >= 2 then
      v_suspend_after := true;
    end if;
  end if;

  -- 194: shared finalizer owns stock/coupon/refund/order+ride cancellation.
  v_refunded := v_order.payment_status = 'paid';
  perform public._finalize_order_cancel(
    p_order_id,
    case when v_uid = v_order.user_id then 'customer' else 'admin' end,
    coalesce(p_reason, v_order.cancelled_reason, 'Order cancelled'),
    true, true, true,
    case when v_uid is distinct from v_order.user_id then 'system' else 'rider' end);

  -- Notify the assigned driver: stop heading to pickup.
  if v_order.driver_id is not null then
    select user_id into v_driver_uid from public.drivers where id = v_order.driver_id;
    if v_driver_uid is not null then
      insert into public.notifications (user_id, title, body, type, data, send_push)
      values (v_driver_uid,
              'تم إلغاء الطلب',
              'ألغى العميل الطلب. لا تتوجه للاستلام.',
              'order',
              jsonb_build_object('order_id', v_order.id, 'status', 'cancelled',
                                 'reason', p_reason),
              true);
    end if;
  end if;

  -- Notify the merchant owner.
  if v_order.merchant_id is not null then
    select owner_user_id into v_merchant_uid from public.merchants where id = v_order.merchant_id;
    if v_merchant_uid is not null then
      v_short := right(v_order.id::text, 6);
      insert into public.notifications (user_id, title, body, type, data, send_push)
      values (v_merchant_uid,
              'تم إلغاء طلب',
              'ألغى العميل الطلب رقم ' || v_short || '.',
              'order',
              jsonb_build_object('order_id', v_order.id, 'status', 'cancelled',
                                 'reason', p_reason),
              true);
    end if;
  end if;

  -- 188/393: suspension after the 3rd monthly cancel. The duration comes
  -- from platform_settings.cancel_suspension_days (owner-only, default 5);
  -- the moderation engine owns account_status. The message routes the
  -- customer to in-app support to understand the repeated cancellations.
  if v_suspend_after then
    v_actor := coalesce(
      (select id from public.users where role = 'owner' order by created_at limit 1),
      v_order.user_id);
    v_suspension_days := coalesce(
      (select ps.cancel_suspension_days
         from public.platform_settings ps
        where ps.id = 'default'),
      5);
    perform public._member_exec_sanction(
      v_actor, v_order.user_id, 'suspension',
      'تجاوز سماحية الإلغاء الشهرية (إلغاء ثالث خلال شهر واحد)', v_suspension_days);
    insert into public.notifications (user_id, title, body, type, data, deep_link, send_push)
    values (v_order.user_id,
            'تم إيقاف حسابك ' || v_suspension_days || ' يوم',
            'تم تنفيذ إلغاء الطلب، لكن ده ثالث إلغاء ليك هذا الشهر (السماحية: 2). اتوقف حسابك ' || v_suspension_days || ' يوم. تواصل مع الدعم من التطبيق عشان تفهم سبب تكرار الإلغاء وإزاي تتجنب الإيقاف مرة تانية.',
            'account',
            jsonb_build_object('event', 'cancel_suspension', 'order_id', v_order.id,
                               'duration_days', v_suspension_days),
            '/support',
            true);
    return jsonb_build_object('ok', true, 'code', 'OK', 'status', 'cancelled',
                              'refunded', v_refunded, 'suspended', true,
                              'suspension_days', v_suspension_days);
  end if;

  return jsonb_build_object('ok', true, 'code', 'OK', 'status', 'cancelled', 'refunded', v_refunded);
end;
$function$;

CREATE OR REPLACE FUNCTION public._finalize_order_cancel(p_order_id uuid, p_actor text, p_reason text, p_restock boolean DEFAULT true, p_refund boolean DEFAULT true, p_release_coupon boolean DEFAULT true, p_ride_cancelled_by text DEFAULT 'system'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_order public.orders%rowtype;
begin
  select * into v_order from public.orders where id = p_order_id for update;
  if not found then
    raise exception 'ORDER_NOT_FOUND';
  end if;
  if v_order.status in ('delivered','cancelled') then
    return; -- already closed: nothing to finalize
  end if;

  if p_restock and v_order.stock_decremented then
    update public.products p
       set stock_quantity = p.stock_quantity + s.qty
      from (select oi.product_id, sum(oi.quantity) as qty
              from public.order_items oi
             where oi.order_id = p_order_id
             group by oi.product_id) s
     where p.id = s.product_id
       and p.stock_quantity is not null;
  end if;

  if p_release_coupon and v_order.coupon_id is not null then
    delete from public.coupon_redemptions
     where coupon_id = v_order.coupon_id
       and user_id = v_order.user_id;
    if found then
      update public.coupons
         set used_count = greatest(used_count - 1, 0)
       where id = v_order.coupon_id;
    end if;
  end if;

  -- 395: an order cancelled or rejected before delivery returns the
  -- platform credit it consumed, so the gift survives the failed order.
  -- The terminal-state early return above plus the order row lock make
  -- this fire once; the ledger partial-unique index backstops it.
  if coalesce(v_order.platform_credit_applied, 0) > 0 then
    perform public._platform_credit_restore(
      v_order.user_id, v_order.platform_credit_applied, p_order_id);
  end if;

  if p_refund and v_order.payment_status = 'paid' then
    perform public._wallet_credit(
      p_user_id := v_order.user_id,
      p_amount := v_order.total_amount,
      p_description := 'Refund for cancelled order ' || p_order_id::text,
      p_reference_type := 'refund',
      p_reference_id := p_order_id
    );
  end if;

  update public.orders
     set status = 'cancelled',
         cancelled_reason = p_reason,
         cancelled_by = p_actor,
         cancelled_at = now(),
         payment_status = case when p_refund and payment_status = 'paid' then 'refunded' else payment_status end,
         stock_decremented = false,
         driver_id = null,
         updated_at = now()
   where id = p_order_id;

  -- 196: release the driver and close open offers on every ride of the order.
  update public.driver_locations
     set ride_id = null
   where ride_id in (select id from public.rides where order_id = p_order_id);
  update public.ride_requests
     set status = 'expired', responded_at = now()
   where ride_id in (select id from public.rides where order_id = p_order_id)
     and status = 'offered';
  update public.ride_requests
     set status = 'cancelled', responded_at = now()
   where ride_id in (select id from public.rides where order_id = p_order_id)
     and status = 'accepted';

  update public.rides
     set status = 'cancelled',
         cancelled_at = now(),
         cancelled_by = p_ride_cancelled_by,
         cancellation_reason = p_reason
   where order_id = p_order_id
     and status not in ('completed', 'cancelled');
end;
$function$
;

-- Preserve 399 category-specific targets and 397 live category pricing.
CREATE OR REPLACE FUNCTION public._provision_business_target(p_user_id uuid, p_category_type text, p_display_name text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_user record;
  v_cat text := lower(btrim(COALESCE(p_category_type, 'restaurant')));
  v_name text;
  v_merchant_id uuid;
  v_sp_id uuid;
  v_sp_cat text;
BEGIN
  SELECT id, full_name, email, phone, avatar_url, profile_photo_url
    INTO v_user
    FROM public.users
   WHERE id = p_user_id;

  v_name := COALESCE(
    NULLIF(btrim(p_display_name), ''),
    NULLIF(btrim(v_user.full_name), ''),
    'Delwaqty ' || initcap(v_cat)
  );

  IF public._is_home_service_category(v_cat) THEN
    -- Canonical service_categories.type spelling (camelCase for multi-word
    -- types such as acMaintenance), so customer-app category matching works.
    IF v_cat IN ('service', 'home_services', 'homeservices') THEN
      v_sp_cat := 'plumbing';
    ELSE
      SELECT type INTO v_sp_cat
        FROM public.service_categories
       WHERE lower(replace(type, '_', '')) = replace(v_cat, '_', '')
       ORDER BY is_active DESC, created_at ASC
       LIMIT 1;
      v_sp_cat := COALESCE(v_sp_cat, v_cat);
    END IF;
    SELECT id INTO v_sp_id
      FROM public.service_providers
     WHERE user_id = p_user_id
       AND lower(replace(category_type, '_', '')) = lower(replace(v_sp_cat, '_', ''))
     LIMIT 1;

    -- No fallback to the user's first service row: a second category must get
    -- its own service_providers row, never share the first one.

    IF v_sp_id IS NULL THEN
      INSERT INTO public.service_providers (
        user_id, name, category_type, description, profile_image_url,
        rating, rating_count, is_verified, is_available, hourly_rate
      )
      VALUES (
        p_user_id,
        v_name,
        v_sp_cat,
        '',
        COALESCE(v_user.profile_photo_url, v_user.avatar_url),
        5.0,
        0,
        true,
        true,
        NULL -- use live category defaults, preserve provider override semantics (397)
      )
      RETURNING id INTO v_sp_id;
    END IF;
  ELSE
    SELECT id INTO v_merchant_id
      FROM public.merchants
     WHERE owner_user_id = p_user_id AND lower(type) = v_cat
     ORDER BY created_at ASC
     LIMIT 1;

    IF v_merchant_id IS NULL THEN
      INSERT INTO public.merchants (
        owner_user_id, name, email, phone, type, status, is_open,
        delivery_fee, min_order, delivery_time_min, rating
      )
      VALUES (
        p_user_id,
        v_name,
        COALESCE(v_user.email, ''),
        v_user.phone,
        v_cat,
        'active',
        true,
        15,
        0,
        30,
        5.0
      )
      RETURNING id INTO v_merchant_id;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'merchant_id', v_merchant_id,
    'service_provider_id', v_sp_id
  );
END;
$function$
;
