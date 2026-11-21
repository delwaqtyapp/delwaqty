-- 171: Real stock enforcement in create_order + restore on cancel (bughunt F13).
-- products.stock_quantity is the app-managed stock column (merchant app writes
-- it). NULL stock_quantity = unlimited (no tracking). Atomic decrement closes
-- the concurrent-oversell race; orders.stock_decremented marks orders whose
-- items were decremented so cancel_order restores exactly once.

alter table public.orders add column if not exists stock_decremented boolean not null default false;

create or replace function public.create_order(
  p_merchant_id uuid, p_items jsonb, p_delivery_address text default null,
  p_delivery_latitude numeric default null, p_delivery_longitude numeric default null,
  p_payment_method text default 'cash', p_coupon_code text default null,
  p_special_instructions text default null, p_idempotency_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if p_payment_method not in ('cash', 'instapay', 'vodafone_cash') then
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

    -- Atomic stock check + decrement (NULL stock = unlimited)
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

    v_subtotal := v_subtotal + (v_product.price * v_qty);
    v_lines := v_lines || jsonb_build_object(
      'product_id', v_product.id,
      'product_name', coalesce(v_product.name_ar, v_product.name),
      'quantity', v_qty,
      'unit_price', v_product.price,
      'total_price', v_product.price * v_qty
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
      v_discount := round(v_subtotal * (v_coupon->>'discount_value')::numeric / 100.0, 2);
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

  insert into public.order_items (order_id, product_id, product_name, quantity, unit_price, total_price)
  select v_order_id,
         (l->>'product_id')::uuid,
         l->>'product_name',
         (l->>'quantity')::int,
         (l->>'unit_price')::numeric,
         (l->>'total_price')::numeric
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
$$;

create or replace function public.cancel_order(p_order_id uuid, p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
  v_uid uuid := auth.uid();
  v_refunded boolean := false;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED');
  end if;

  select * into v_order from public.orders where id = p_order_id for update;
  if v_order.id is null then
    return jsonb_build_object('ok', false, 'code', 'NOT_FOUND');
  end if;

  if v_order.user_id is distinct from v_uid and not public.is_admin() then
    return jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  end if;

  if v_order.status in ('delivered', 'cancelled') then
    return jsonb_build_object('ok', false, 'code', 'NOT_CANCELLABLE', 'status', v_order.status);
  end if;

  -- Restore stock exactly once (only orders that decremented)
  if v_order.stock_decremented then
    update public.products p
       set stock_quantity = p.stock_quantity + oi.quantity
      from public.order_items oi
     where oi.order_id = v_order.id
       and p.id = oi.product_id
       and p.stock_quantity is not null;
  end if;

  if v_order.payment_status = 'paid' then
    perform public.wallet_refund(
      p_user_id := v_order.user_id,
      p_amount := v_order.total_amount,
      p_description := 'Order cancellation refund for order ' || p_order_id::text,
      p_reference_type := 'refund',
      p_reference_id := p_order_id
    );
    v_refunded := true;
  end if;

  update public.orders
     set status = 'cancelled',
         cancelled_reason = coalesce(p_reason, v_order.cancelled_reason),
         cancelled_at = now(),
         payment_status = case when v_order.payment_status = 'paid' then 'refunded' else v_order.payment_status end,
         stock_decremented = false,
         updated_at = now()
   where id = v_order.id;

  return jsonb_build_object('ok', true, 'code', 'OK', 'status', 'cancelled', 'refunded', v_refunded);
end;
$$;
