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

-- #77: ONE canonicalization rule shared by SQL and the Dart client
-- (normalizeBarcode in pos_product_lookup.dart): trim ASCII space, tab,
-- CR and LF from both ends; empty becomes NULL. Barcodes are stored
-- canonical so client lookup and the unique index can never disagree.
-- The trigger canonicalizes EVERY write path: app form, POS quick-add,
-- pharmacy_import_drug, admin tools and future importers.
CREATE OR REPLACE FUNCTION public.products_barcode_canonicalize()
RETURNS trigger LANGUAGE plpgsql AS $fn$
BEGIN
  NEW.barcode := NULLIF(btrim(NEW.barcode, E' \t\r\n'), '');
  RETURN NEW;
END;
$fn$;

-- Fixed search_path so the trigger body cannot resolve through a caller's
-- schema; trigger invocation does not need EXECUTE, so revoke it.
ALTER FUNCTION public.products_barcode_canonicalize() SET search_path = pg_catalog;
REVOKE EXECUTE ON FUNCTION public.products_barcode_canonicalize() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS products_barcode_canonicalize_trg ON public.products;
CREATE TRIGGER products_barcode_canonicalize_trg
  BEFORE INSERT OR UPDATE OF barcode ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.products_barcode_canonicalize();

-- Backfill existing rows to canonical form (no-op where already clean).
UPDATE public.products
SET barcode = NULLIF(btrim(barcode, E' \t\r\n'), '')
WHERE barcode IS NOT NULL
  AND barcode IS DISTINCT FROM NULLIF(btrim(barcode, E' \t\r\n'), '');

-- #76: executable preflight. Abort the migration if any store still holds
-- duplicate normalized barcodes (verified on prod 2026-11-23: 0 groups).
DO $$
DECLARE v_dupe_groups int;
BEGIN
  SELECT count(*) INTO v_dupe_groups FROM (
    SELECT merchant_id, NULLIF(btrim(barcode, E' \t\r\n'), '') AS b
    FROM public.products
    WHERE NULLIF(btrim(barcode, E' \t\r\n'), '') IS NOT NULL
    GROUP BY merchant_id, b
    HAVING count(*) > 1
  ) d;
  IF v_dupe_groups > 0 THEN
    RAISE EXCEPTION '400 abort: % merchant/barcode duplicate groups exist; resolve them before re-applying', v_dupe_groups;
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS products_merchant_barcode_uq
  ON public.products (merchant_id, barcode)
  WHERE barcode IS NOT NULL AND btrim(barcode, E' \t\r\n') <> '';

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
     AND ((v_drug.barcode IS NOT NULL AND barcode = btrim(v_drug.barcode, E' \t\r\n'))
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
       AND ((v_drug.barcode IS NOT NULL AND barcode = btrim(v_drug.barcode, E' \t\r\n'))
            OR (v_drug.barcode IS NULL
                AND name = v_drug.name_en || COALESCE(' ' || v_drug.strength, '')))
     ORDER BY created_at
     LIMIT 1;
    -- The losing insert only becomes a duplicate when the winner's row is
    -- actually there; otherwise this was a different unique_violation and
    -- must surface, never return ok:true with a NULL product_id.
    IF v_product_id IS NULL THEN
      RAISE;
    END IF;
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

  -- Security LOW-1: two tills with the same idempotency key can both pass
  -- the replay lookup above; the loser of the insert race re-reads the
  -- winner and returns the idempotent replay. No winner row means a
  -- different unique_violation happened: rethrow, never fake a replay.
  BEGIN
    INSERT INTO public.pos_sales
      (merchant_id, cashier_user_id, items, subtotal, discount, total_amount,
       payment_method, customer_name, notes, idempotency_key)
    VALUES
      (p_merchant_id, v_uid, v_lines, v_subtotal, v_discount, v_total,
       p_payment_method, NULLIF(btrim(COALESCE(p_customer_name, '')), ''),
       p_notes, p_idempotency_key)
    RETURNING id INTO v_sale_id;
  EXCEPTION WHEN unique_violation THEN
    IF p_idempotency_key IS NOT NULL THEN
      SELECT id INTO v_existing FROM public.pos_sales
        WHERE idempotency_key = p_idempotency_key
          AND merchant_id = p_merchant_id;
      IF v_existing IS NOT NULL THEN
        RETURN (
          SELECT jsonb_build_object(
            'ok', true, 'sale_id', s.id, 'idempotent', true,
            'subtotal', s.subtotal, 'discount', s.discount,
            'total', s.total_amount, 'items', s.items)
          FROM public.pos_sales s WHERE s.id = v_existing);
      END IF;
    END IF;
    RAISE;
  END;

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

-- Security HIGH: dropping the global pos_sales_idempotency_key_key would
-- break cashier_sync_push (latest body: 378_cashier_pro_enforcement), whose
-- offline-sale insert targeted ON CONFLICT (idempotency_key). Redefined
-- here against the per-merchant partial index, predicate included, so
-- offline sync keeps working after 400. Verified: the only other writers
-- of pos_sales are older, superseded pos_create_sale bodies (plain INSERT,
-- no conflict target) and the 400 body above.
CREATE OR REPLACE FUNCTION public.cashier_sync_push(p_merchant_id uuid, p_ops jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_op jsonb;
  v_type text;
  v_op_id uuid;
  v_results jsonb := '[]'::jsonb;
  v_sale_id uuid;
  v_shift_id uuid;
  v_merchant public.merchants%ROWTYPE;
  v_item jsonb;
  v_pay jsonb;
  v_deferred numeric;
  v_prod uuid;
  v_qty numeric;
  v_old_price numeric;
  v_new_price numeric;
  v_pct numeric;
  v_lines jsonb;
  v_subtotal numeric;
  v_rate numeric;
  v_primary_method text;
  v_company uuid;
  v_server_price numeric;
  v_unit numeric;
  v_line_disc numeric;
  v_discount numeric;
  v_total numeric;
  v_applied numeric;
  v_prev_stock integer;
  v_idx integer;
  v_foreign boolean;
  v_cp boolean;
  v_line_repriced boolean;
  v_client_priced integer;
  v_repriced integer;
  v_server_total numeric;
  v_mismatch boolean;
BEGIN
  IF v_uid IS NULL OR NOT public.is_merchant_owner(p_merchant_id) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF jsonb_typeof(p_ops) <> 'array' THEN RAISE EXCEPTION 'ops must be an array'; END IF;
  SELECT * INTO v_merchant FROM public.merchants WHERE id = p_merchant_id;

  FOR v_op IN SELECT * FROM jsonb_array_elements(p_ops) LOOP
    v_type := v_op->>'type';
    v_op_id := (v_op->>'op_id')::uuid;
    BEGIN
      CASE v_type
      WHEN 'customer' THEN
        INSERT INTO public.pos_customers (merchant_id, client_op_id, name, phone, notes)
        VALUES (p_merchant_id, v_op_id, v_op->'payload'->>'name', v_op->'payload'->>'phone', v_op->'payload'->>'notes')
        ON CONFLICT (merchant_id, client_op_id) DO NOTHING;
        v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true);
      WHEN 'shift_open' THEN
        v_shift_id := NULL;
        INSERT INTO public.pos_shifts (merchant_id, client_op_id, opened_by, opening_float, created_offline_at)
        VALUES (p_merchant_id, v_op_id, v_uid, COALESCE((v_op->'payload'->>'opening_float')::numeric, 0),
                (v_op->>'created_offline_at')::timestamptz)
        ON CONFLICT (merchant_id, client_op_id) DO NOTHING
        RETURNING id INTO v_shift_id;
        v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true, 'shift_id', v_shift_id);
      WHEN 'sale' THEN
        -- #36: reject any sale carrying a product id that belongs to another
        -- store; the stock writer below would otherwise decrement the foreign
        -- store's inventory. Unknown (deleted/offline-catalog) ids stay
        -- client-priced as before.
        v_foreign := false;
        FOR v_item IN SELECT * FROM jsonb_array_elements(v_op->'payload'->'items') LOOP
          v_prod := NULLIF(v_item->>'product_id','')::uuid;
          IF v_prod IS NOT NULL AND EXISTS (
            SELECT 1 FROM public.products fp
             WHERE fp.id = v_prod AND fp.merchant_id <> p_merchant_id
          ) THEN
            v_foreign := true;
            EXIT;
          END IF;
        END LOOP;
        IF v_foreign THEN
          v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', false,
            'reason', 'FOREIGN_PRODUCT');
          CONTINUE;
        END IF;
        -- Offline sale recorded as fact into the shared pos_sales table, but
        -- money is repriced SERVER-SIDE (review #26): any line whose
        -- product_id resolves is priced from public.products (through the
        -- shared _price_order_line helper for whole-number quantities), and
        -- commission is charged on the server total. Lines only the client
        -- could price (catalog-only offline drugs) are flagged client_priced
        -- and counted in the result for quarantine review.
        v_sale_id := NULL;
        v_lines := '[]'::jsonb;
        v_subtotal := 0;
        v_deferred := 0;
        v_primary_method := NULL;
        v_client_priced := 0;
        v_repriced := 0;
        FOR v_item IN SELECT * FROM jsonb_array_elements(v_op->'payload'->'items') LOOP
          v_prod := NULLIF(v_item->>'product_id','')::uuid;
          v_qty := (v_item->>'qty')::numeric;
          v_unit := NULL;
          v_cp := false;
          v_line_repriced := false;
          IF v_prod IS NOT NULL THEN
            SELECT p.price INTO v_server_price
              FROM public.products p
             WHERE p.id = v_prod AND p.merchant_id = p_merchant_id;
            IF FOUND THEN
              v_unit := v_server_price;
              IF v_qty = trunc(v_qty) AND v_qty BETWEEN 1 AND 50 THEN
                BEGIN
                  v_unit := (public._price_order_line(p_merchant_id,
                    jsonb_build_object('product_id', v_prod, 'quantity', v_qty::int),
                    false)->>'unit_price')::numeric;
                EXCEPTION WHEN OTHERS THEN
                  -- Delisted or edge product: fall back to its last known price.
                  v_unit := v_server_price;
                END;
              END IF;
              IF v_unit IS DISTINCT FROM (v_item->>'unit_price')::numeric THEN
                v_line_repriced := true;
                v_repriced := v_repriced + 1;
              END IF;
            END IF;
          END IF;
          IF v_unit IS NULL THEN
            -- Offline-only drug with no store product row: only the client
            -- could price it. Keep the claimed price, flag the line.
            v_unit := (v_item->>'unit_price')::numeric;
            v_cp := true;
            v_client_priced := v_client_priced + 1;
          END IF;
          v_line_disc := LEAST(GREATEST(COALESCE((v_item->>'discount_amount')::numeric, 0), 0),
                               v_unit * v_qty);
          v_lines := v_lines || jsonb_build_object(
            'product_id', v_prod,
            'drug_catalog_id', NULLIF(v_item->>'drug_catalog_id','')::uuid,
            'name', v_item->>'name',
            'qty', v_qty,
            'unit_price', v_unit,
            'discount', v_line_disc,
            'line_total', v_unit * v_qty - v_line_disc,
            'is_weight_based', COALESCE((v_item->>'is_weight_based')::boolean, false),
            'client_priced', v_cp,
            'repriced', v_line_repriced);
          v_subtotal := v_subtotal + (v_unit * v_qty - v_line_disc);
        END LOOP;
        v_discount := LEAST(GREATEST(COALESCE((v_op->'payload'->>'discount_amount')::numeric, 0), 0),
                            v_subtotal);
        v_total := v_subtotal - v_discount;
        INSERT INTO public.pos_sales
          (merchant_id, cashier_user_id, items, subtotal, discount, total_amount,
           payment_method, customer_name, notes, idempotency_key,
           shift_id, pos_customer_id, created_offline_at, created_at,
           client_priced_lines)
        VALUES
          (p_merchant_id, v_uid, v_lines,
           v_subtotal, v_discount, v_total,
           COALESCE(v_op->'payload'->'payments'->0->>'method', 'cash'),
           v_op->'payload'->>'customer_name',
           v_op->'payload'->>'notes', v_op_id::text,
           NULLIF(v_op->'payload'->>'shift_id','')::uuid,
           NULLIF(v_op->'payload'->>'customer_id','')::uuid,
           (v_op->>'created_offline_at')::timestamptz,
           now(),
           v_client_priced)
        ON CONFLICT (merchant_id, idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING
        RETURNING id INTO v_sale_id;
        IF v_sale_id IS NULL THEN
          v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true, 'duplicate', true);
          CONTINUE;
        END IF;
        -- Stock: best-effort decrement for tracked products. The APPLIED
        -- (clamped) decrement goes into the move so جرد reconciles, and the
        -- line carries stock_applied so a later void can't over-restore
        -- (review #31).
        FOR v_idx, v_item IN SELECT (t.ord - 1), t.value
              FROM jsonb_array_elements(v_op->'payload'->'items') WITH ORDINALITY AS t(value, ord) LOOP
          v_prod := NULLIF(v_item->>'product_id','')::uuid;
          v_qty := (v_item->>'qty')::numeric;
          IF v_prod IS NOT NULL THEN
            SELECT p.stock_quantity INTO v_prev_stock FROM public.products p
             WHERE p.id = v_prod AND p.merchant_id = p_merchant_id
             FOR UPDATE OF p;
            IF v_prev_stock IS NOT NULL THEN
              v_applied := LEAST(v_prev_stock, v_qty);
              UPDATE public.products
                 SET stock_quantity = GREATEST(0, stock_quantity - v_qty::int), updated_at = now()
               WHERE id = v_prod AND merchant_id = p_merchant_id;
              INSERT INTO public.pos_stock_moves (merchant_id, product_id, kind, qty, created_by, created_offline_at)
              VALUES (p_merchant_id, v_prod, 'sale', -v_applied, v_uid, (v_op->>'created_offline_at')::timestamptz);
              -- #37: stamp ONLY this line's ordinal; matching by product id
              -- stamped every unmarked duplicate line with the first line's
              -- applied amount, over-restoring on void.
              UPDATE public.pos_sales s
                 SET items = (SELECT jsonb_agg(CASE WHEN (t.ord - 1) = v_idx
                                                    THEN l || jsonb_build_object('stock_applied', v_applied)
                                                    ELSE l END ORDER BY t.ord)
                                FROM jsonb_array_elements(s.items) WITH ORDINALITY AS t(l, ord))
               WHERE s.id = v_sale_id;
            END IF;
          END IF;
        END LOOP;
        FOR v_pay IN SELECT * FROM jsonb_array_elements(v_op->'payload'->'payments') LOOP
          INSERT INTO public.pos_sale_payments (sale_id, method, amount)
          VALUES (v_sale_id, v_pay->>'method', (v_pay->>'amount')::numeric);
          IF v_pay->>'method' = 'deferred' THEN v_deferred := v_deferred + (v_pay->>'amount')::numeric; END IF;
        END LOOP;
        IF v_deferred > 0 AND NULLIF(v_op->'payload'->>'customer_id','') IS NOT NULL THEN
          INSERT INTO public.pos_debt_ledger (merchant_id, customer_id, sale_id, kind, amount, created_by, created_offline_at)
          VALUES (p_merchant_id, (v_op->'payload'->>'customer_id')::uuid,
                  v_sale_id, 'charge', v_deferred, v_uid, (v_op->>'created_offline_at')::timestamptz);
        END IF;
        -- Same commission posting as pos_create_sale, on the SERVER total.
        v_rate := COALESCE(public.get_commission_rate('merchant', v_merchant.type, v_merchant.owner_user_id), 0);
        IF v_rate > 0 THEN
          INSERT INTO public.platform_commissions
            (member_id, reference_type, reference_id, gross_amount, commission_rate,
             commission_amount, net_amount, currency, status)
          VALUES (v_merchant.owner_user_id, 'pos_sale', v_sale_id,
                  v_total, v_rate,
                  public.calculate_commission(v_total, v_rate),
                  v_total - public.calculate_commission(v_total, v_rate),
                  'EGP', 'computed')
          ON CONFLICT (reference_type, reference_id) DO NOTHING;
        END IF;
        v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true,
          'sale_id', v_sale_id, 'total', v_total,
          'repriced', v_repriced, 'client_priced', v_client_priced);
      WHEN 'sale_void' THEN
        SELECT id INTO v_sale_id FROM public.pos_sales
         WHERE merchant_id = p_merchant_id AND idempotency_key = (v_op->'payload'->>'sale_op_id')
           AND status = 'completed';
        IF v_sale_id IS NOT NULL THEN
          PERFORM public.pos_void_sale(v_sale_id, v_op->'payload'->>'reason');
          -- #28: reverse أجل charges with explicit reversal entries (the old
          -- code flipped charges to payments, driving the balance negative).
          INSERT INTO public.pos_debt_ledger (merchant_id, customer_id, sale_id, kind, amount, note, created_by)
          SELECT d.merchant_id, d.customer_id, d.sale_id, 'reversal', d.amount,
                 'عكس مديونية لإلغاء العملية', v_uid
            FROM public.pos_debt_ledger d
           WHERE d.sale_id = v_sale_id AND d.kind = 'charge'
             AND NOT EXISTS (SELECT 1 FROM public.pos_debt_ledger r
                              WHERE r.sale_id = d.sale_id AND r.kind = 'reversal');
          -- #37: pos_void_sale now restores each line's stamped
          -- stock_applied amount itself, so no post-void correction here.
          INSERT INTO public.pos_stock_moves (merchant_id, kind, qty, note, created_by)
          VALUES (p_merchant_id, 'void_restore', 0, 'void of sale ' || v_sale_id::text, v_uid);
        END IF;
        v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true, 'sale_id', v_sale_id);
      WHEN 'debt_payment' THEN
        INSERT INTO public.pos_debt_ledger (merchant_id, customer_id, client_op_id, kind, amount, note, created_by, created_offline_at)
        VALUES (p_merchant_id, (v_op->'payload'->>'customer_id')::uuid, v_op_id, 'payment',
                (v_op->'payload'->>'amount')::numeric, v_op->'payload'->>'note', v_uid,
                (v_op->>'created_offline_at')::timestamptz)
        ON CONFLICT (merchant_id, client_op_id) DO NOTHING;
        v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true);
      WHEN 'stock_count' THEN
        v_prod := (v_op->'payload'->>'product_id')::uuid;
        v_qty := (v_op->'payload'->>'counted')::numeric;
        INSERT INTO public.pos_stock_moves (merchant_id, product_id, client_op_id, kind, qty, note, created_by, created_offline_at)
        VALUES (p_merchant_id, v_prod, v_op_id, 'count_adjustment',
                v_qty - COALESCE((SELECT stock_quantity FROM public.products WHERE id = v_prod AND merchant_id = p_merchant_id), 0),
                v_op->'payload'->>'note', v_uid, (v_op->>'created_offline_at')::timestamptz)
        ON CONFLICT (merchant_id, client_op_id) DO NOTHING;
        UPDATE public.products SET stock_quantity = v_qty::int, updated_at = now()
         WHERE id = v_prod AND merchant_id = p_merchant_id;
        v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true);
      WHEN 'price_change' THEN
        v_prod := (v_op->'payload'->>'product_id')::uuid;
        v_new_price := (v_op->'payload'->>'new_price')::numeric;
        SELECT price INTO v_old_price FROM public.products WHERE id = v_prod AND merchant_id = p_merchant_id;
        UPDATE public.products SET price = v_new_price, updated_at = now()
         WHERE id = v_prod AND merchant_id = p_merchant_id;
        INSERT INTO public.pos_price_history (merchant_id, product_id, old_price, new_price, source, changed_by)
        VALUES (p_merchant_id, v_prod, v_old_price, v_new_price, COALESCE(v_op->'payload'->>'source','manual'), v_uid);
        v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true);
      WHEN 'bulk_price_pct' THEN
        v_pct := (v_op->'payload'->>'pct')::numeric;
        INSERT INTO public.pos_price_history (merchant_id, product_id, old_price, new_price, source, changed_by)
        SELECT p_merchant_id, id, price, round(price * (1 + v_pct / 100), 2), 'bulk_pct', v_uid
          FROM public.products WHERE merchant_id = p_merchant_id AND is_available;
        UPDATE public.products
           SET price = round(price * (1 + v_pct / 100), 2), updated_at = now()
         WHERE merchant_id = p_merchant_id AND is_available;
        v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true);
      WHEN 'insurance_sale' THEN
        IF NOT public._cashier_has_pro(p_merchant_id) THEN
          v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', false,
            'reason', 'PRO_REQUIRED');
          CONTINUE;
        END IF;
        -- Insured sale (تأمين): the insured part is billed to the company,
        -- the patient pays their share. Idempotent on the client op id.
        v_company := (v_op->'payload'->>'company_id')::uuid;
        v_sale_id := NULL;
        IF NULLIF(v_op->'payload'->>'sale_op_id','') IS NOT NULL THEN
          SELECT id INTO v_sale_id FROM public.pos_sales
           WHERE merchant_id = p_merchant_id
             AND idempotency_key = (v_op->'payload'->>'sale_op_id');
        END IF;
        -- Review #32: the shares are client-claimed and feed
        -- pos_insurance_statement. They must at least sum to the claimed
        -- total; otherwise the op is rejected.
        IF abs(COALESCE((v_op->'payload'->>'company_share')::numeric, 0)
             + COALESCE((v_op->'payload'->>'patient_share')::numeric, 0)
             - (v_op->'payload'->>'total')::numeric) > 0.01 THEN
          v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', false,
            'reason', 'INSURANCE_SHARE_MISMATCH');
          CONTINUE;
        END IF;
        -- Review #32: when the linked sale resolved, compare the claimed
        -- total with the SERVER-repriced pos_sales total. A mismatch is
        -- quarantined (recorded with total_mismatch + the server total),
        -- same pattern as client_priced, never silently trusted.
        v_server_total := NULL;
        v_mismatch := false;
        IF v_sale_id IS NOT NULL THEN
          SELECT s.total_amount INTO v_server_total
            FROM public.pos_sales s WHERE s.id = v_sale_id;
          IF v_server_total IS NOT NULL
             AND abs(v_server_total - (v_op->'payload'->>'total')::numeric) > 0.01 THEN
            v_mismatch := true;
          END IF;
        END IF;
        INSERT INTO public.pos_insurance_sales
          (merchant_id, company_id, sale_id, client_op_id, member_name, member_card_no,
           total, company_share, patient_share, created_by, created_offline_at,
           server_total, total_mismatch)
        VALUES
          (p_merchant_id, v_company, v_sale_id, v_op_id,
           v_op->'payload'->>'member_name', v_op->'payload'->>'member_card_no',
           (v_op->'payload'->>'total')::numeric,
           (v_op->'payload'->>'company_share')::numeric,
           (v_op->'payload'->>'patient_share')::numeric,
           v_uid, (v_op->>'created_offline_at')::timestamptz,
           v_server_total, v_mismatch)
        ON CONFLICT (merchant_id, client_op_id) DO NOTHING;
        v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true,
          'server_total', v_server_total, 'total_mismatch', v_mismatch);
      ELSE
        v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', false, 'reason', 'UNKNOWN_OP');
      END CASE;
    EXCEPTION WHEN OTHERS THEN
      v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', false, 'reason', SQLERRM);
    END;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'results', v_results);
END;
$function$
