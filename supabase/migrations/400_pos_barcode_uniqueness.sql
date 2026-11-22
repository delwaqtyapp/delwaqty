-- 400 (owner GO 2026-11-23): barcode cashier hardening — one canonical
-- barcode per store, race-safe drug import, per-merchant sale idempotency.
--
-- Preflight (read-only, run before applying): duplicate barcodes would
-- abort the unique index build. Verified 2026-11-23: prod 12 product rows,
-- 0 with barcodes, 0 duplicates; staging likewise.
--   select merchant_id, barcode, count(*) from public.products
--   where barcode is not null and btrim(barcode) <> ''
--   group by 1, 2 having count(*) > 1;
-- Operational note: at 12 rows the index builds instantly, so a plain
-- CREATE INDEX is safe (CONCURRENTLY cannot run inside the migration
-- transaction and is unnecessary at this size).

-- #77: barcodes are stored trimmed-or-NULL so client lookup (trimmed
-- equality) and the unique index can never disagree. The trigger
-- canonicalizes EVERY write path: app form, POS quick-add,
-- pharmacy_import_drug, admin tools and future importers.
CREATE OR REPLACE FUNCTION public.products_barcode_canonicalize()
RETURNS trigger LANGUAGE plpgsql AS $fn$
BEGIN
  NEW.barcode := NULLIF(btrim(NEW.barcode), '');
  RETURN NEW;
END
$fn$;

DROP TRIGGER IF EXISTS products_barcode_canonicalize_trg ON public.products;
CREATE TRIGGER products_barcode_canonicalize_trg
  BEFORE INSERT OR UPDATE OF barcode ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.products_barcode_canonicalize();

-- Backfill existing rows to canonical form (no-op where already clean).
UPDATE public.products
SET barcode = NULLIF(btrim(barcode), '')
WHERE barcode IS NOT NULL
  AND barcode IS DISTINCT FROM NULLIF(btrim(barcode), '');

CREATE UNIQUE INDEX IF NOT EXISTS products_merchant_barcode_uq
  ON public.products (merchant_id, barcode)
  WHERE barcode IS NOT NULL AND btrim(barcode) <> '';

-- Security LOW-1: pos_sales idempotency was globally unique; scope it per
-- merchant so replay semantics are tenant-local. The global constraint is
-- replaced by an equivalent-or-stronger per-merchant partial index.
ALTER TABLE public.pos_sales DROP CONSTRAINT IF EXISTS pos_sales_idempotency_key_key;
CREATE UNIQUE INDEX IF NOT EXISTS pos_sales_merchant_idempotency_uq
  ON public.pos_sales (merchant_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

CREATE OR REPLACE FUNCTION public.pharmacy_import_drug(p_drug_id uuid, p_merchant_id uuid, p_price numeric DEFAULT NULL::numeric, p_stock integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_merchant public.merchants%ROWTYPE;
  v_drug public.drug_catalog%ROWTYPE;
  v_product_id uuid;
  v_price numeric;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF p_stock IS NULL OR p_stock < 0 THEN
    RAISE EXCEPTION 'INVALID_STOCK';
  END IF;

  SELECT * INTO v_merchant FROM public.merchants WHERE id = p_merchant_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'MERCHANT_NOT_FOUND';
  END IF;
  IF NOT public.is_merchant_owner(p_merchant_id) THEN
    RAISE EXCEPTION 'NOT_YOUR_STORE';
  END IF;

  SELECT * INTO v_drug FROM public.drug_catalog
    WHERE id = p_drug_id AND is_active;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'DRUG_NOT_FOUND';
  END IF;

  -- Default to the official retail price when the caller does not set one.
  v_price := COALESCE(p_price, v_drug.official_price_egp);
  IF v_price IS NULL OR v_price < 0 THEN
    RAISE EXCEPTION 'INVALID_PRICE';
  END IF;

  -- Duplicate guard: re-importing the same drug returns the existing product.
  SELECT id INTO v_product_id FROM public.products
   WHERE merchant_id = p_merchant_id
     AND ((v_drug.barcode IS NOT NULL AND barcode = btrim(v_drug.barcode))
          OR (v_drug.barcode IS NULL
              AND name = v_drug.name_en || COALESCE(' ' || v_drug.strength, '')))
   ORDER BY created_at
   LIMIT 1;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'product_id', v_product_id, 'duplicate', true);
  END IF;

  -- Two tills importing the same drug at the same moment: the loser of the
  -- unique-index race re-reads the winner's row and reports duplicate
  -- instead of failing the sale flow (400).
  BEGIN
    INSERT INTO public.products (
      merchant_id, name, name_ar, description, description_ar, price,
      category, stock_quantity, is_available, barcode
    ) VALUES (
      p_merchant_id,
      v_drug.name_en || COALESCE(' ' || v_drug.strength, ''),
      v_drug.name_ar,
      concat_ws(' · ', v_drug.active_ingredient, v_drug.strength,
                v_drug.dosage_form, v_drug.manufacturer),
      NULL,
      v_price,
      'pharmacy',
      p_stock,
      true,
      v_drug.barcode
    )
    RETURNING id INTO v_product_id;
  EXCEPTION WHEN unique_violation THEN
    SELECT id INTO v_product_id FROM public.products
     WHERE merchant_id = p_merchant_id
       AND ((v_drug.barcode IS NOT NULL AND barcode = btrim(v_drug.barcode))
            OR (v_drug.barcode IS NULL
                AND name = v_drug.name_en || COALESCE(' ' || v_drug.strength, '')))
     ORDER BY created_at
     LIMIT 1;
    RETURN jsonb_build_object('ok', true, 'product_id', v_product_id, 'duplicate', true);
  END;

  RETURN jsonb_build_object('ok', true, 'product_id', v_product_id);
END;
$function$;


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
  IF NOT public.is_merchant_owner(p_merchant_id) THEN
    RAISE EXCEPTION 'NOT_YOUR_STORE';
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    -- Replay lookup is scoped to the store: the idempotency key is unique
    -- per merchant (400), never globally across tenants.
    SELECT id INTO v_existing FROM public.pos_sales
      WHERE idempotency_key = p_idempotency_key
        AND merchant_id = p_merchant_id;
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
$function$;

