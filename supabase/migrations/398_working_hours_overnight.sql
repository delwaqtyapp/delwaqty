-- 398: provider weekly hours support overnight windows end to end.
--
-- A restaurant that opens at noon and closes at 01:00 could not save its
-- schedule at all: provider_set_working_hours rejected any window whose
-- closing time was not after its opening time. This migration defines the
-- storage semantics (day_of_week is the OPENING day; close_time <= open_time
-- means the window closes on the next calendar day; open_time = close_time
-- means open 24 hours), relaxes the writer's validation accordingly, adds
-- public.working_hours_open_at (Africa/Cairo local time) as the single
-- schedule-aware open/closed computation, and makes checkout honor it.
--
-- working_hours_open_at returns NULL when the merchant has no schedule at
-- all, so create_order's `is false` check leaves schedule-less merchants
-- exactly as before (manual merchants.is_open flag only).

CREATE OR REPLACE FUNCTION public.working_hours_open_at(p_merchant_id uuid, p_at timestamp with time zone DEFAULT now())
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- Schedule-only answer in Africa/Cairo local time:
  --   NULL  -> the merchant has no working_hours rows (unconstrained);
  --   true/false -> whether the schedule allows service at p_at.
  -- working_hours.day_of_week follows the apps' convention 0=Sunday..6=Saturday
  -- and records the OPENING day. An overnight row (close_time < open_time)
  -- covers [open_time, 24:00) on its own day and [00:00, close_time) on the
  -- next day; a 24h row (open_time = close_time, is_closed false) covers its
  -- whole opening day, from midnight to midnight.
  WITH local AS (
    SELECT (p_at AT TIME ZONE 'Africa/Cairo')::date AS d,
           (p_at AT TIME ZONE 'Africa/Cairo')::time AS t
  ),
  relevant AS (
    SELECT wh.day_of_week, wh.open_time, wh.close_time, wh.is_closed,
           (extract(isodow FROM local.d)::int % 7)     AS today,
           (extract(isodow FROM (local.d - 1))::int % 7) AS yesterday,
           local.t
    FROM public.working_hours wh
    CROSS JOIN local
    WHERE wh.merchant_id = p_merchant_id
      AND wh.day_of_week IN ((extract(isodow FROM local.d)::int % 7),
                             (extract(isodow FROM (local.d - 1))::int % 7))
  )
  SELECT CASE
           WHEN NOT EXISTS (SELECT 1 FROM public.working_hours
                            WHERE merchant_id = p_merchant_id) THEN NULL
           ELSE COALESCE(bool_or(
             CASE
               WHEN is_closed THEN false
               WHEN open_time = close_time THEN day_of_week = today
               WHEN open_time < close_time THEN
                 day_of_week = today AND t >= open_time AND t < close_time
               ELSE
                 (day_of_week = today AND t >= open_time)
                 OR (day_of_week = yesterday AND t < close_time)
             END
           ), false)
         END
  FROM relevant;
$function$;

REVOKE ALL ON FUNCTION public.working_hours_open_at(uuid, timestamp with time zone) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.working_hours_open_at(uuid, timestamp with time zone) TO authenticated;
GRANT EXECUTE ON FUNCTION public.working_hours_open_at(uuid, timestamp with time zone) TO service_role;

CREATE OR REPLACE FUNCTION public.provider_set_working_hours(p_schedule jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_merchant uuid;
  v_entry jsonb;
  v_day int;
  v_open text;
  v_close text;
  v_closed boolean;
  v_stored int := 0;
BEGIN
  v_merchant := public.resolve_my_merchant();
  IF v_merchant IS NULL THEN
    RAISE EXCEPTION 'No merchant store for this account';
  END IF;

  IF p_schedule IS NULL OR jsonb_typeof(p_schedule) <> 'array' THEN
    RAISE EXCEPTION 'Schedule must be a JSON array';
  END IF;

  -- Replace the whole schedule atomically so a partial failure can never
  -- leave the store with half a week defined.
  DELETE FROM public.working_hours WHERE merchant_id = v_merchant;

  FOR v_entry IN SELECT * FROM jsonb_array_elements(p_schedule) LOOP
    v_day := COALESCE((v_entry->>'day')::int, -1);
    v_open := v_entry->>'open';
    v_close := v_entry->>'close';
    v_closed := COALESCE((v_entry->>'closed')::boolean, false);

    IF v_day < 0 OR v_day > 6 THEN
      RAISE EXCEPTION 'Invalid day of week: %', v_day;
    END IF;

    IF NOT v_closed
       AND (v_open IS NULL OR v_close IS NULL
            OR v_open !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
            OR v_close !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$') THEN
      RAISE EXCEPTION 'Invalid time format for day % (expected HH:MM)', v_day;
    END IF;

    -- 398: window semantics. open < close  -> same-day window.
    -- close < open -> overnight window: opens on `day`, closes at `close`
    -- on the next calendar day (restaurants open past midnight).
    -- open = close  -> open 24 hours on `day`.
    -- All three are valid; the old close-after-open rule is removed.

    INSERT INTO public.working_hours
      (merchant_id, day_of_week, open_time, close_time, is_closed)
    VALUES
      (v_merchant, v_day, v_open::time, v_close::time, v_closed);

    v_stored := v_stored + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'ok', true,
    'rows', v_stored,
    'merchant_id', v_merchant
  );
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
