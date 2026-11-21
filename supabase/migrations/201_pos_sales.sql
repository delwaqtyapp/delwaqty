-- 201: POS / cashier backend - walk-in over-the-counter sales.
--
-- create_order() is customer-bound (auth.uid() is the buyer, delivery
-- pipeline attached). A store cashier ringing up an in-person buyer has no
-- path: this adds pos_sales + pos_create_sale(). Server-side pricing from
-- the products table (client prices never trusted), atomic stock decrement,
-- idempotency, and the same platform_commissions posting the order and
-- booking flows use (kind 'merchant', merchant's type as category).

-- POS sales are commissionable; extend the commission reference vocabulary.
ALTER TABLE public.platform_commissions
  DROP CONSTRAINT IF EXISTS platform_commissions_reference_type_check;
ALTER TABLE public.platform_commissions
  ADD CONSTRAINT platform_commissions_reference_type_check
  CHECK (reference_type IN ('order', 'order_driver', 'ride', 'service_booking', 'pos_sale'));

CREATE TABLE IF NOT EXISTS public.pos_sales (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id uuid NOT NULL REFERENCES public.merchants(id),
  cashier_user_id uuid NOT NULL,
  items jsonb NOT NULL,
  subtotal numeric NOT NULL,
  discount numeric NOT NULL DEFAULT 0,
  total_amount numeric NOT NULL,
  payment_method text NOT NULL DEFAULT 'cash'
    CHECK (payment_method IN ('cash', 'instapay', 'vodafone_cash')),
  customer_name text,
  notes text,
  status text NOT NULL DEFAULT 'completed' CHECK (status IN ('completed', 'voided')),
  idempotency_key text UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.pos_sales ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pos_sales_select_merchant ON public.pos_sales;
CREATE POLICY pos_sales_select_merchant ON public.pos_sales
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.merchants m
            WHERE m.id = pos_sales.merchant_id
              AND m.owner_user_id = auth.uid())
  );

DROP POLICY IF EXISTS pos_sales_admin ON public.pos_sales;
CREATE POLICY pos_sales_admin ON public.pos_sales
  FOR ALL USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE OR REPLACE FUNCTION public.pos_create_sale(
  p_merchant_id uuid,
  p_items jsonb,
  p_discount numeric DEFAULT 0,
  p_payment_method text DEFAULT 'cash',
  p_customer_name text DEFAULT NULL,
  p_notes text DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
)
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
      RETURN jsonb_build_object('ok', true, 'sale_id', v_existing, 'idempotent', true);
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
    SELECT * INTO v_product FROM public.products
      WHERE id = (v_item->>'product_id')::uuid
        AND merchant_id = p_merchant_id
        AND is_available;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'PRODUCT_UNAVAILABLE';
    END IF;

    UPDATE public.products
       SET stock_quantity = stock_quantity - v_qty,
           updated_at = now()
     WHERE id = v_product.id
       AND stock_quantity >= v_qty;
    GET DIAGNOSTICS v_touched = ROW_COUNT;
    IF v_touched = 0 THEN
      RAISE EXCEPTION 'INSUFFICIENT_STOCK';
    END IF;

    v_subtotal := v_subtotal + (v_product.price * v_qty);
    v_lines := v_lines || jsonb_build_object(
      'product_id', v_product.id,
      'name', v_product.name,
      'name_ar', v_product.name_ar,
      'qty', v_qty,
      'unit_price', v_product.price,
      'line_total', v_product.price * v_qty
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
$function$;
