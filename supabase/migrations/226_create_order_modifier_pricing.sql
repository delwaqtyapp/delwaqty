-- 226 (MEDIUM-3): create_order priced only the base product. The app folds
-- modifier price adjustments into the displayed unit price client-side, so a
-- +10 EGP modifier was shown to the customer but never charged (or, with a
-- tampered client, any price could be implied). The server now prices each
-- selected modifier option from product_modifier_options.price_adjustment
-- and stores the selection on the order line.
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
  v_existing uuid;
  v_stock_touched boolean := false;
  v_unit_price numeric;
  v_modifier_id text;
  v_modifier record;
  v_modifiers jsonb;
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
    v_qty := coalesce((v_item->>'quantity')::int, 0);
    if v_qty < 1 or v_qty > 50 then
      raise exception 'INVALID_QUANTITY';
    end if;

    select * into v_product
    from public.products
    where id = (v_item->>'product_id')::uuid
      and merchant_id = p_merchant_id;
    if not found then
      raise exception 'PRODUCT_NOT_FOUND %', v_item->>'product_id';
    end if;
    if v_product.is_available is not true then
      raise exception 'PRODUCT_UNAVAILABLE %', coalesce(v_product.name_ar, v_product.name);
    end if;

    if v_product.stock_quantity is not null then
      update public.products
         set stock_quantity = stock_quantity - v_qty
       where id = v_product.id
         and stock_quantity >= v_qty;
      if not found then
        raise exception 'INSUFFICIENT_STOCK %', coalesce(v_product.name_ar, v_product.name);
      end if;
      v_stock_touched := true;
    end if;

    -- Modifier pricing (MEDIUM-3): every selected option must belong to a
    -- modifier group of THIS product; its price_adjustment is added to the
    -- server-side unit price. Client-supplied prices are ignored.
    v_unit_price := v_product.price;
    v_modifiers := '[]'::jsonb;
    if v_item ? 'modifier_option_ids'
       and jsonb_typeof(v_item->'modifier_option_ids') = 'array' then
      if jsonb_array_length(v_item->'modifier_option_ids') > 20 then
        raise exception 'TOO_MANY_MODIFIERS';
      end if;
      for v_modifier_id in select value #>> '{}' from jsonb_array_elements(v_item->'modifier_option_ids')
      loop
        select o.id, o.name, coalesce(o.name_ar, o.name) as display_name, o.price_adjustment
          into v_modifier
          from public.product_modifier_options o
          join public.product_modifier_groups g on g.id = o.group_id
         where o.id = v_modifier_id::uuid
           and g.product_id = v_product.id;
        if not found then
          raise exception 'INVALID_MODIFIER %', v_modifier_id;
        end if;
        v_unit_price := v_unit_price + coalesce(v_modifier.price_adjustment, 0);
        v_modifiers := v_modifiers || jsonb_build_object(
          'option_id', v_modifier.id,
          'name', v_modifier.display_name,
          'price_adjustment', coalesce(v_modifier.price_adjustment, 0)
        );
      end loop;
    end if;

    v_subtotal := v_subtotal + (v_unit_price * v_qty);
    v_lines := v_lines || jsonb_build_object(
      'product_id', v_product.id,
      'product_name', coalesce(v_product.name_ar, v_product.name),
      'quantity', v_qty,
      'unit_price', v_unit_price,
      'total_price', v_unit_price * v_qty,
      'modifiers', v_modifiers
    );
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
CREATE OR REPLACE FUNCTION public.create_order_idempotent(p_idempotency_key text, p_merchant_id uuid, p_merchant_name text, p_items jsonb, p_subtotal numeric, p_delivery_fee numeric, p_discount numeric, p_total numeric, p_delivery_address text, p_payment_method text, p_payment_status text, p_payment_provider text, p_payment_provider_order_id text, p_delivery_latitude numeric DEFAULT NULL::numeric, p_delivery_longitude numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_items jsonb;
  v_lines jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED');
  END IF;
  IF p_idempotency_key IS NULL OR p_idempotency_key = '' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'MISSING_IDEMPOTENCY_KEY');
  END IF;
  IF jsonb_typeof(p_items) = 'string' THEN
    BEGIN
      v_items := (p_items #>> '{}')::jsonb;
    EXCEPTION WHEN OTHERS THEN
      RETURN jsonb_build_object('ok', false, 'code', 'INVALID_ITEMS');
    END;
  ELSE
    v_items := p_items;
  END IF;
  IF v_items IS NULL OR jsonb_typeof(v_items) <> 'array' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_ITEMS');
  END IF;
  -- Only ids, quantities and modifier selections cross the wire; the
  -- server prices everything (base product + modifier adjustments).
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'product_id', COALESCE(e.item ->> 'product_id', e.item ->> 'productId'),
           'quantity', COALESCE((e.item ->> 'quantity')::int, 1),
           'modifier_option_ids', COALESCE(e.item -> 'modifier_option_ids', '[]'::jsonb)
         )), '[]'::jsonb)
    INTO v_lines
    FROM jsonb_array_elements(v_items) AS e(item);
  RETURN public.create_order(
    p_merchant_id,
    v_lines,
    p_delivery_address,
    p_delivery_latitude,
    p_delivery_longitude,
    COALESCE(NULLIF(p_payment_method, ''), 'cash'),
    NULL,
    NULL,
    p_idempotency_key
  );
END;
$function$
;
REVOKE EXECUTE ON FUNCTION public.create_order_idempotent(text,uuid,text,jsonb,numeric,numeric,numeric,numeric,text,text,text,text,text,numeric,numeric) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.create_order_idempotent(text,uuid,text,jsonb,numeric,numeric,numeric,numeric,text,text,text,text,text,numeric,numeric) FROM anon;
GRANT EXECUTE ON FUNCTION public.create_order_idempotent(text,uuid,text,jsonb,numeric,numeric,numeric,numeric,text,text,text,text,text,numeric,numeric) TO authenticated;
