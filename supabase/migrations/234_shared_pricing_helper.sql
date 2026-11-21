-- 234 (reviewer #21): ONE pricing loop for all order paths.
-- create_order, add_order_items and pos_create_sale each carried a
-- copy-pasted product+stock+modifier loop and had diverged: 226/229
-- modifier pricing and group rules existed only in create_order, so
-- add_order_items silently ignored modifier selections (unpriced,
-- unrecorded). All three now call _price_order_line.
-- pos_create_sale keeps its POS-specific codes (INVALID_QTY) and stored
-- line shape; stock decrements there no longer touch products.updated_at.

CREATE OR REPLACE FUNCTION public._price_order_line(p_merchant_id uuid, p_item jsonb, p_decrement_stock boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_product public.products%ROWTYPE;
  v_qty int;
  v_unit_price numeric;
  v_modifiers jsonb := '[]'::jsonb;
  v_modifier_id text;
  v_modifier record;
  v_selected_groups uuid[] := '{}'::uuid[];
  v_group record;
  v_stock_decremented boolean := false;
BEGIN
  v_qty := coalesce((p_item->>'quantity')::int, 0);
  IF v_qty < 1 OR v_qty > 50 THEN
    RAISE EXCEPTION 'INVALID_QUANTITY';
  END IF;

  SELECT * INTO v_product FROM public.products
   WHERE id = (p_item->>'product_id')::uuid AND merchant_id = p_merchant_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'PRODUCT_NOT_FOUND %', p_item->>'product_id';
  END IF;
  IF v_product.is_available IS NOT TRUE THEN
    RAISE EXCEPTION 'PRODUCT_UNAVAILABLE %', coalesce(v_product.name_ar, v_product.name);
  END IF;
  IF p_decrement_stock AND v_product.stock_quantity IS NOT NULL THEN
    UPDATE public.products SET stock_quantity = stock_quantity - v_qty
     WHERE id = v_product.id AND stock_quantity >= v_qty;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'INSUFFICIENT_STOCK %', coalesce(v_product.name_ar, v_product.name);
    END IF;
    v_stock_decremented := true;
  END IF;

  -- Modifier pricing + group rules (226/229): options must belong to
  -- this product's groups; required groups need a pick; max_selections
  -- is enforced; duplicate option ids are deduped.
  v_unit_price := v_product.price;
  IF p_item ? 'modifier_option_ids'
     AND jsonb_typeof(p_item->'modifier_option_ids') = 'array' THEN
    IF jsonb_array_length(p_item->'modifier_option_ids') > 20 THEN
      RAISE EXCEPTION 'TOO_MANY_MODIFIERS';
    END IF;
    FOR v_modifier_id IN SELECT DISTINCT value #>> '{}' FROM jsonb_array_elements(p_item->'modifier_option_ids')
    LOOP
      SELECT o.id, coalesce(o.name_ar, o.name) AS display_name, o.price_adjustment, g.id AS group_id
        INTO v_modifier
        FROM public.product_modifier_options o
        JOIN public.product_modifier_groups g ON g.id = o.group_id
       WHERE o.id = v_modifier_id::uuid
         AND g.product_id = v_product.id;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'INVALID_MODIFIER %', v_modifier_id;
      END IF;
      v_selected_groups := v_selected_groups || v_modifier.group_id;
      v_unit_price := v_unit_price + coalesce(v_modifier.price_adjustment, 0);
      v_modifiers := v_modifiers || jsonb_build_object(
        'option_id', v_modifier.id,
        'name', v_modifier.display_name,
        'price_adjustment', coalesce(v_modifier.price_adjustment, 0)
      );
    END LOOP;
  END IF;

  FOR v_group IN
    SELECT g.id, coalesce(g.name_ar, g.name) AS gname, g.is_required,
           g.max_selections,
           (SELECT count(*) FROM unnest(v_selected_groups) AS s(gid)
             WHERE s.gid = g.id) AS picked
      FROM public.product_modifier_groups g
     WHERE g.product_id = v_product.id
  LOOP
    IF v_group.is_required AND v_group.picked = 0 THEN
      RAISE EXCEPTION 'REQUIRED_MODIFIER_MISSING %', v_group.gname;
    END IF;
    IF coalesce(v_group.max_selections, 0) > 0
       AND v_group.picked > v_group.max_selections THEN
      RAISE EXCEPTION 'MODIFIER_MAX_EXCEEDED %', v_group.gname;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'product_id', v_product.id,
    'product_name', coalesce(v_product.name_ar, v_product.name),
    'name', v_product.name,
    'name_ar', v_product.name_ar,
    'quantity', v_qty,
    'unit_price', v_unit_price,
    'total_price', v_unit_price * v_qty,
    'modifiers', v_modifiers,
    'stock_decremented', v_stock_decremented
  );
END;
$function$
;
-- Internal helper: only SECURITY DEFINER callers (owned by postgres) use it.
REVOKE EXECUTE ON FUNCTION public._price_order_line(uuid, jsonb, boolean) FROM PUBLIC, anon, authenticated;

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
$function$
;
REVOKE EXECUTE ON FUNCTION public.create_order(uuid,jsonb,text,numeric,numeric,text,text,text,text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.create_order(uuid,jsonb,text,numeric,numeric,text,text,text,text) FROM anon;
GRANT EXECUTE ON FUNCTION public.create_order(uuid,jsonb,text,numeric,numeric,text,text,text,text) TO authenticated;

-- The idempotent wrapper rebuilds item objects; it must forward modifier
-- selections or they would be silently dropped on that path.

CREATE OR REPLACE FUNCTION public.add_order_items(p_order_id uuid, p_items jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_order public.orders%rowtype;
  v_item jsonb;
  v_product public.products%rowtype;
  v_qty int;
  v_added numeric := 0;
  v_lines jsonb := '[]'::jsonb;
  v_line jsonb;
  v_stock_touched boolean := false;
  v_coupon public.coupons%rowtype;
  v_new_subtotal numeric;
  v_discount numeric := 0;
  v_total numeric;
  v_merchant_uid uuid;
begin
  if v_uid is null then
    raise exception 'UNAUTHENTICATED';
  end if;
  select * into v_order from public.orders where id = p_order_id for update;
  if not found then
    raise exception 'ORDER_NOT_FOUND';
  end if;
  if v_order.user_id is distinct from v_uid and not public.is_admin() then
    raise exception 'FORBIDDEN';
  end if;
  if v_order.status not in ('pending','confirmed','preparing') then
    raise exception 'ORDER_NOT_EDITABLE %', v_order.status;
  end if;
  if v_order.payment_status = 'paid' then
    raise exception 'ORDER_ALREADY_PAID';
  end if;
  -- Monthly edit allowance (mig 185): 3 edits per calendar month (UTC).
  if v_uid = v_order.user_id and not public.is_admin() then
    if (select count(*) from public.order_edit_events
         where user_id = v_uid
           and created_at >= date_trunc('month', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo') >= 3 then
      raise exception 'EDIT_ALLOWANCE_EXHAUSTED';
    end if;
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'EMPTY_ITEMS';
  end if;
  if jsonb_array_length(p_items) > 100 then
    raise exception 'TOO_MANY_ITEMS';
  end if;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    -- #21: same shared pricing as create_order; modifier selections are
    -- now priced, validated against group rules and recorded on the item.
    v_line := public._price_order_line(v_order.merchant_id, v_item, true);
    v_stock_touched := v_stock_touched or (v_line->>'stock_decremented')::boolean;
    v_added := v_added + (v_line->>'total_price')::numeric;
    v_lines := v_lines || (v_line - 'stock_decremented' - 'name' - 'name_ar');
  end loop;

  v_new_subtotal := v_order.subtotal + v_added;

  if v_order.coupon_id is not null then
    select * into v_coupon from public.coupons where id = v_order.coupon_id;
    if found then
      if v_coupon.discount_type = 'percentage' then
        v_discount := round(v_new_subtotal * v_coupon.discount_value / 100.0, 2);
      else
        v_discount := v_coupon.discount_value;
      end if;
      if v_coupon.maximum_discount is not null then
        v_discount := least(v_discount, v_coupon.maximum_discount);
      end if;
      v_discount := least(v_discount, v_new_subtotal);
    else
      v_discount := v_order.discount;
    end if;
  else
    v_discount := coalesce(v_order.discount, 0);
  end if;

  v_total := greatest(v_new_subtotal + coalesce(v_order.delivery_fee,0) - v_discount, 0);

  insert into public.order_items (order_id, product_id, product_name, quantity, unit_price, total_price, modifiers)
  select p_order_id, (l->>'product_id')::uuid, l->>'product_name',
         (l->>'quantity')::int, (l->>'unit_price')::numeric, (l->>'total_price')::numeric,
         coalesce(l->'modifiers', '[]'::jsonb)
    from jsonb_array_elements(v_lines) l;

  update public.orders
     set subtotal = v_new_subtotal,
         discount = v_discount,
         total_amount = v_total,
         items = coalesce(items, '[]'::jsonb) || v_lines,
         stock_decremented = stock_decremented or v_stock_touched,
         updated_at = now()
   where id = p_order_id;

  insert into public.order_edit_events (order_id, user_id, added_subtotal)
  values (p_order_id, v_order.user_id, v_added);

  select owner_user_id into v_merchant_uid from public.merchants where id = v_order.merchant_id;
  if v_merchant_uid is not null then
    insert into public.notifications (user_id, title, body, type, data, send_push)
    values (v_merchant_uid,
            'تعديل على طلب قيد التجهيز',
            'أضاف العميل منتجات إلى الطلب رقم ' || right(p_order_id::text, 6) ||
              '. الإجمالي الجديد: ' || v_total::text || ' جنيه.',
            'order',
            jsonb_build_object('order_id', p_order_id, 'event', 'items_added',
                               'added_subtotal', v_added, 'total_amount', v_total),
            true);
  end if;

  return jsonb_build_object(
    'ok', true, 'order_id', p_order_id,
    'added_subtotal', v_added,
    'subtotal', v_new_subtotal,
    'discount', v_discount,
    'total_amount', v_total);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.pos_create_sale(p_merchant_id uuid, p_items jsonb, p_discount numeric DEFAULT 0, p_payment_method text DEFAULT 'cash'::text, p_customer_name text DEFAULT NULL::text, p_notes text DEFAULT NULL::text, p_idempotency_key text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_merchant public.merchants%ROWTYPE;
  v_item jsonb;
  v_product public.products%ROWTYPE;
  v_qty int;
  v_subtotal numeric := 0;
  v_total numeric;
  v_discount numeric := 0;
  v_lines jsonb := '[]'::jsonb;
  v_line jsonb;
  v_sale_id uuid;
  v_existing uuid;
  v_rate numeric;
  v_commission numeric;
  v_touched int;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_payment_method NOT IN ('cash', 'instapay', 'vodafone_cash') THEN
    RAISE EXCEPTION 'INVALID_PAYMENT_METHOD';
  END IF;

  SELECT * INTO v_merchant FROM public.merchants WHERE id = p_merchant_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'MERCHANT_NOT_FOUND';
  END IF;
  IF v_merchant.owner_user_id <> v_uid AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'NOT_YOUR_STORE';
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_existing FROM public.pos_sales
      WHERE idempotency_key = p_idempotency_key;
    IF FOUND THEN
      RETURN (
        SELECT jsonb_build_object(
          'ok', true, 'sale_id', s.id, 'idempotent', true,
          'subtotal', s.subtotal, 'discount', s.discount,
          'total', s.total_amount, 'items', s.items)
        FROM public.pos_sales s WHERE s.id = v_existing);
    END IF;
  END IF;

  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array'
     OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'EMPTY_CART';
  END IF;

  -- Price every line from the live products table; stock-check and decrement
  -- atomically so two tills cannot sell the same last unit.
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_qty := COALESCE((v_item->>'qty')::int, 0);
    IF v_qty <= 0 THEN
      RAISE EXCEPTION 'INVALID_QTY';
    END IF;
    -- #21: same shared pricing as the order flow (modifiers priced and
    -- group-validated when the till sends modifier_option_ids).
    v_line := public._price_order_line(
      p_merchant_id,
      jsonb_build_object(
        'product_id', v_item->>'product_id',
        'quantity', v_qty,
        'modifier_option_ids', COALESCE(v_item->'modifier_option_ids', '[]'::jsonb)),
      true);
    v_subtotal := v_subtotal + (v_line->>'total_price')::numeric;
    v_lines := v_lines || jsonb_build_object(
      'product_id', v_line->>'product_id',
      'name', v_line->>'name',
      'name_ar', v_line->>'name_ar',
      'qty', v_qty,
      'unit_price', (v_line->>'unit_price')::numeric,
      'line_total', (v_line->>'total_price')::numeric,
      'modifiers', v_line->'modifiers'
    );
  END LOOP;

  v_discount := LEAST(GREATEST(COALESCE(p_discount, 0), 0), v_subtotal);
  v_total := v_subtotal - v_discount;

  INSERT INTO public.pos_sales
    (merchant_id, cashier_user_id, items, subtotal, discount, total_amount,
     payment_method, customer_name, notes, idempotency_key)
  VALUES
    (p_merchant_id, v_uid, v_lines, v_subtotal, v_discount, v_total,
     p_payment_method, NULLIF(btrim(COALESCE(p_customer_name, '')), ''),
     p_notes, p_idempotency_key)
  RETURNING id INTO v_sale_id;

  -- Same commission posting as orders/bookings: merchant owes the platform
  -- its rate on the walk-in gross, once.
  v_rate := COALESCE(
    public.get_commission_rate('merchant', v_merchant.type, v_merchant.owner_user_id), 0);
  IF v_rate > 0 THEN
    v_commission := public.calculate_commission(v_total, v_rate);
    INSERT INTO public.platform_commissions
      (member_id, reference_type, reference_id, gross_amount, commission_rate,
       commission_amount, net_amount, currency, status)
    VALUES (v_merchant.owner_user_id, 'pos_sale', v_sale_id, v_total, v_rate,
            v_commission, v_total - v_commission, 'EGP', 'computed')
    ON CONFLICT (reference_type, reference_id) DO NOTHING;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'sale_id', v_sale_id,
    'subtotal', v_subtotal,
    'discount', v_discount,
    'total', v_total,
    'items', v_lines
  );
END;
$function$
;
