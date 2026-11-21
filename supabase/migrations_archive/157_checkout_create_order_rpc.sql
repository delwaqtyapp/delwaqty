-- Migration 157: server-side checkout.
--
-- Audit findings fixed here:
-- 1. Customer checkout was impossible: the app's createOrder does a direct
--    INSERT into orders, but orders has NO client INSERT policy (RLS).
--    Every checkout attempt fails. (Found in UI-layer audit.)
-- 2. Client-computed totals: the app sent subtotal/total/discount from the
--    client. Prices must come from the products table server-side.
-- 3. Coupons were display-only: the coupon code never reached the order,
--    and increment_coupon_usage was an invoker function updating a table
--    with no client UPDATE policy, so usage counting never worked.
--
-- create_order computes everything from the database: product prices,
-- merchant delivery fee, coupon discount, and inserts order + items +
-- coupon redemption atomically. Idempotent via p_idempotency_key.

CREATE OR REPLACE FUNCTION public.redeem_coupon(p_coupon_code text, p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_coupon public.coupons%ROWTYPE;
BEGIN
  SELECT * INTO v_coupon FROM public.coupons WHERE code = btrim(p_coupon_code);
  IF v_coupon.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'coupon_not_found');
  END IF;
  IF NOT v_coupon.is_active THEN
    RETURN jsonb_build_object('success', false, 'reason', 'coupon_inactive');
  END IF;
  IF v_coupon.expires_at IS NOT NULL AND v_coupon.expires_at < now() THEN
    RETURN jsonb_build_object('success', false, 'reason', 'coupon_expired');
  END IF;
  IF v_coupon.usage_limit IS NOT NULL AND COALESCE(v_coupon.used_count, 0) >= v_coupon.usage_limit THEN
    RETURN jsonb_build_object('success', false, 'reason', 'usage_limit_reached');
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.coupon_redemptions r
    WHERE r.coupon_id = v_coupon.id AND r.user_id = p_user_id
  ) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'already_redeemed');
  END IF;

  UPDATE public.coupons
  SET used_count = COALESCE(used_count, 0) + 1
  WHERE id = v_coupon.id;
  INSERT INTO public.coupon_redemptions (coupon_id, user_id)
  VALUES (v_coupon.id, p_user_id);

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
$$;

CREATE OR REPLACE FUNCTION public.create_order(
  p_merchant_id uuid,
  p_items jsonb,
  p_delivery_address text DEFAULT NULL,
  p_delivery_latitude numeric DEFAULT NULL,
  p_delivery_longitude numeric DEFAULT NULL,
  p_payment_method text DEFAULT 'cash',
  p_coupon_code text DEFAULT NULL,
  p_special_instructions text DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_merchant public.merchants%ROWTYPE;
  v_item jsonb;
  v_product public.products%ROWTYPE;
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
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_payment_method NOT IN ('cash', 'instapay', 'vodafone_cash') THEN
    RAISE EXCEPTION 'INVALID_PAYMENT_METHOD';
  END IF;

  -- idempotent replay: return the existing order for this key
  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_existing FROM public.orders
    WHERE user_id = v_uid AND idempotency_key = p_idempotency_key;
    IF v_existing IS NOT NULL THEN
      RETURN jsonb_build_object(
        'ok', true, 'order_id', v_existing, 'idempotent_replay', true
      );
    END IF;
  END IF;

  SELECT * INTO v_merchant FROM public.merchants WHERE id = p_merchant_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'MERCHANT_NOT_FOUND';
  END IF;

  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'EMPTY_CART';
  END IF;
  IF jsonb_array_length(p_items) > 100 THEN
    RAISE EXCEPTION 'TOO_MANY_ITEMS';
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_qty := COALESCE((v_item->>'quantity')::int, 0);
    IF v_qty < 1 OR v_qty > 50 THEN
      RAISE EXCEPTION 'INVALID_QUANTITY';
    END IF;

    SELECT * INTO v_product
    FROM public.products
    WHERE id = (v_item->>'product_id')::uuid
      AND merchant_id = p_merchant_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'PRODUCT_NOT_FOUND %', v_item->>'product_id';
    END IF;
    IF v_product.is_available IS NOT TRUE THEN
      RAISE EXCEPTION 'PRODUCT_UNAVAILABLE %', COALESCE(v_product.name_ar, v_product.name);
    END IF;
    IF v_product.stock_quantity IS NOT NULL AND v_product.stock_quantity < v_qty THEN
      RAISE EXCEPTION 'INSUFFICIENT_STOCK %', COALESCE(v_product.name_ar, v_product.name);
    END IF;

    v_subtotal := v_subtotal + (v_product.price * v_qty);
    v_lines := v_lines || jsonb_build_object(
      'product_id', v_product.id,
      'product_name', COALESCE(v_product.name_ar, v_product.name),
      'quantity', v_qty,
      'unit_price', v_product.price,
      'total_price', v_product.price * v_qty
    );
  END LOOP;

  v_delivery_fee := COALESCE(v_merchant.delivery_fee, 0);

  IF v_merchant.min_order IS NOT NULL AND v_subtotal < v_merchant.min_order THEN
    RAISE EXCEPTION 'BELOW_MIN_ORDER %', v_merchant.min_order;
  END IF;

  IF p_coupon_code IS NOT NULL AND btrim(p_coupon_code) <> '' THEN
    v_coupon := public.redeem_coupon(p_coupon_code, v_uid);
    IF NOT (v_coupon->>'success')::boolean THEN
      RAISE EXCEPTION 'COUPON_%', upper(v_coupon->>'reason');
    END IF;
    IF (v_coupon->>'merchant_id') IS NOT NULL
       AND (v_coupon->>'merchant_id')::uuid <> p_merchant_id THEN
      RAISE EXCEPTION 'COUPON_WRONG_MERCHANT';
    END IF;
    IF (v_coupon->>'minimum_order') IS NOT NULL
       AND v_subtotal < (v_coupon->>'minimum_order')::numeric THEN
      RAISE EXCEPTION 'COUPON_MIN_ORDER_NOT_MET';
    END IF;
    v_coupon_id := (v_coupon->>'coupon_id')::uuid;
    IF v_coupon->>'discount_type' = 'percentage' THEN
      v_discount := round(v_subtotal * (v_coupon->>'discount_value')::numeric / 100.0, 2);
    ELSE
      v_discount := (v_coupon->>'discount_value')::numeric;
    END IF;
    IF (v_coupon->>'maximum_discount') IS NOT NULL THEN
      v_discount := LEAST(v_discount, (v_coupon->>'maximum_discount')::numeric);
    END IF;
    v_discount := LEAST(v_discount, v_subtotal);
  END IF;

  v_total := v_subtotal + v_delivery_fee - v_discount;
  IF v_total < 0 THEN
    v_total := 0;
  END IF;

  INSERT INTO public.orders (
    user_id, merchant_id, merchant_name, status, payment_status,
    payment_method, subtotal, delivery_fee, discount, tax, total_amount,
    coupon_id, delivery_address, delivery_latitude, delivery_longitude,
    special_instructions, items, idempotency_key, dispatch_status
  ) VALUES (
    v_uid, p_merchant_id, v_merchant.name, 'pending', 'pending',
    p_payment_method, v_subtotal, v_delivery_fee, v_discount, 0, v_total,
    v_coupon_id, p_delivery_address, p_delivery_latitude, p_delivery_longitude,
    p_special_instructions, v_lines, p_idempotency_key, 'PENDING_DISPATCH'
  )
  RETURNING id INTO v_order_id;

  INSERT INTO public.order_items (order_id, product_id, product_name, quantity, unit_price, total_price)
  SELECT v_order_id,
         (l->>'product_id')::uuid,
         l->>'product_name',
         (l->>'quantity')::int,
         (l->>'unit_price')::numeric,
         (l->>'total_price')::numeric
  FROM jsonb_array_elements(v_lines) l;

  RETURN jsonb_build_object(
    'ok', true,
    'order_id', v_order_id,
    'subtotal', v_subtotal,
    'delivery_fee', v_delivery_fee,
    'discount', v_discount,
    'total_amount', v_total,
    'status', 'pending',
    'idempotent_replay', false
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_order(uuid, jsonb, text, numeric, numeric, text, text, text, text) TO authenticated;

-- unique idempotency per user (race-safe replay)
CREATE UNIQUE INDEX IF NOT EXISTS orders_user_idempotency_uniq
  ON public.orders (user_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- per-user coupon redemption ledger (coupons are separate from promo_codes,
-- whose promo_redemptions table FKs to promo_codes and cannot hold coupon ids)
CREATE TABLE IF NOT EXISTS public.coupon_redemptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coupon_id uuid NOT NULL REFERENCES public.coupons(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  order_id uuid REFERENCES public.orders(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (coupon_id, user_id)
);

ALTER TABLE public.coupon_redemptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS coupon_redemptions_owner_read ON public.coupon_redemptions;
CREATE POLICY coupon_redemptions_owner_read ON public.coupon_redemptions
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());
-- inserts happen only inside SECURITY DEFINER RPCs (redeem_coupon)
