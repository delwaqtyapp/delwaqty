-- 415: Fix coupon usage-limit race (HIGH, load-test finding #1) and reject
-- wallet + card payment methods at checkout (HIGH, load-test finding #2;
-- card rejected per owner decision 2026-11-23).
--
-- Applies AFTER 403_integrate_checkout_credit_hours.sql. create_order below
-- is the exact 403 body plus additive guards; nothing else in 403 is
-- changed. Delivered as a follow-on migration rather than an edit to 403 so
-- the reviewed 403 composition stays intact (same pattern as 350->349).
-- Builder owns final migration numbering; renumber freely if 410-414 land.
--
-- Rollback: run 415_rollback.sql, which restores all three function bodies
-- byte-identical to their pre-415 text (403 / 000_baseline).
--
-- Provenance of the payment-rails decisions: cash on delivery + InstaPay +
-- Vodafone Cash only was decided by the owner on 2026-11-20 in his own words
-- on his WhatsApp channel (rejecting Fawry and Paymob; decision recorded as
-- delwaqty-payments-cash-only), relayed by main 2026-11-22. Rejecting
-- 'wallet' at checkout was instructed by main 2026-11-22 and extending the
-- same rejection to 'card' by main 2026-11-23, both under the owner's
-- delegated-decisions grant for launch hardening.
--
-- CREATE OR REPLACE preserves existing grants, so the lockdowns from
-- 218/404 are unaffected; this migration adds no grants.

BEGIN;

CREATE OR REPLACE FUNCTION public.redeem_coupon(p_coupon_code text, p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_coupon public.coupons%ROWTYPE;
  v_coupon_id uuid;
BEGIN
  -- Self-only: a redemption binds the caller's identity; no anon or
  -- cross-account redemption (prevents usage burn, targeted blocking and
  -- the redeemed-or-not oracle).
  IF auth.uid() IS NULL OR p_user_id IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'reason', 'forbidden');
  END IF;

  SELECT * INTO v_coupon FROM public.coupons WHERE code = btrim(p_coupon_code);
  IF v_coupon.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'coupon_not_found');
  END IF;

  -- Fast-path calm duplicate; the definitive check is the ON CONFLICT below.
  IF EXISTS (
    SELECT 1 FROM public.coupon_redemptions r
    WHERE r.coupon_id = v_coupon.id AND r.user_id = p_user_id
  ) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'already_redeemed');
  END IF;

  -- 415 (load-test finding, review pass): atomic gate. ALL mutable
  -- conditions (is_active, expiry, usage limit) are evaluated inside this
  -- single guarded UPDATE while holding the row lock, so a concurrent
  -- deactivation or expiry change cannot slip a redemption through, and
  -- concurrent redemptions cannot overshoot usage_limit.
  v_coupon_id := v_coupon.id;

  UPDATE public.coupons
  SET used_count = COALESCE(used_count, 0) + 1
  WHERE id = v_coupon_id
    AND is_active
    AND (expires_at IS NULL OR expires_at >= now())
    AND (usage_limit IS NULL OR COALESCE(used_count, 0) < usage_limit)
  RETURNING * INTO v_coupon;
  IF NOT FOUND THEN
    -- No row matched: RETURNING leaves v_coupon all-NULL, so re-read by the
    -- saved id to report which condition failed, preserving the pre-415
    -- reason strings.
    SELECT * INTO v_coupon FROM public.coupons WHERE id = v_coupon_id;
    IF NOT v_coupon.is_active THEN
      RETURN jsonb_build_object('success', false, 'reason', 'coupon_inactive');
    END IF;
    IF v_coupon.expires_at IS NOT NULL AND v_coupon.expires_at < now() THEN
      RETURN jsonb_build_object('success', false, 'reason', 'coupon_expired');
    END IF;
    RETURN jsonb_build_object('success', false, 'reason', 'usage_limit_reached');
  END IF;

  -- 415 (review): calm same-user duplicate. A concurrent same-user call can
  -- pass the EXISTS pre-check; ON CONFLICT turns its 23505 into a calm
  -- already_redeemed, and its increment is compensated so used_count stays
  -- exact. UNIQUE(coupon_id, user_id) is unchanged. Discount metadata below
  -- comes from v_coupon as RETURNED by the locked-row UPDATE (review 7c336e7e),
  -- not from the pre-lock read.
  INSERT INTO public.coupon_redemptions (coupon_id, user_id)
  VALUES (v_coupon_id, p_user_id)
  ON CONFLICT (coupon_id, user_id) DO NOTHING;
  IF NOT FOUND THEN
    UPDATE public.coupons
    SET used_count = GREATEST(COALESCE(used_count, 0) - 1, 0)
    WHERE id = v_coupon_id;
    RETURN jsonb_build_object('success', false, 'reason', 'already_redeemed');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'coupon_id', v_coupon.id,
    'discount_type', v_coupon.discount_type,
    'discount_value', v_coupon.discount_value,
    'minimum_order', v_coupon.minimum_order,
    'maximum_discount', v_coupon.maximum_discount,
    'merchant_id', v_coupon.merchant_id
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.increment_coupon_usage(p_coupon_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- 415 (load-test finding): same check-then-update race as redeem_coupon.
  -- Single guarded UPDATE holds the row lock while evaluating the limit.
  -- EXECUTE stays restricted to postgres/service_role (218); 415 grants
  -- nothing new.
  UPDATE coupons
  SET used_count = COALESCE(used_count, 0) + 1
  WHERE code = p_coupon_code
    AND (usage_limit IS NULL OR COALESCE(used_count, 0) < usage_limit);

  IF NOT FOUND THEN
    -- Distinguish the two failure causes, preserving the old return shape.
    IF EXISTS (SELECT 1 FROM coupons WHERE code = p_coupon_code) THEN
      RETURN jsonb_build_object('success', false, 'reason', 'usage_limit_reached');
    END IF;
    RETURN jsonb_build_object('success', false, 'reason', 'coupon_not_found');
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$function$
;

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

  -- Same set as orders_payment_method_check. NULL is rejected explicitly:
  -- NOT IN over a NULL argument is UNKNOWN, not true, so without the IS NULL
  -- disjunct an explicit NULL would slip past this guard (415 review).
  if p_payment_method is null
     or p_payment_method not in ('cash', 'card', 'wallet', 'instapay', 'vodafone_cash') then
    raise exception 'INVALID_PAYMENT_METHOD';
  end if;

  -- 415 (load-test finding): launch rails are cash on delivery, InstaPay and
  -- Vodafone Cash only (decision provenance in the migration header).
  -- Neither wallet debit nor card charging is built, so wallet and card
  -- orders stayed payment_status 'pending' forever and delivered free.
  -- Reject both outright instead of creating unpaid orders.
  if p_payment_method = 'wallet' then
    raise exception 'WALLET_PAYMENT_NOT_AVAILABLE';
  end if;
  if p_payment_method = 'card' then
    raise exception 'CARD_PAYMENT_NOT_AVAILABLE';
  end if;

  -- F4a: an order without delivery coordinates is undispatchable. No
  -- pickup-only order type exists in create_order, so every order must
  -- carry an address and coordinates.
  if p_delivery_latitude is null or p_delivery_longitude is null
     or p_delivery_address is null or btrim(p_delivery_address) = '' then
    raise exception 'MISSING_DELIVERY_LOCATION';
  end if;

  if p_idempotency_key is not null then
    -- 395 (#89): serialize same-key checkouts BEFORE any pricing, stock
    -- decrement or coupon redemption. A concurrent loser waits here until
    -- the winner commits, then sees the order and replays cleanly, so it
    -- never commits its own stock/coupon side effects.
    perform pg_advisory_xact_lock(hashtext(v_uid::text || ':' || p_idempotency_key));
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

COMMIT;
