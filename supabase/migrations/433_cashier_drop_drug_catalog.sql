-- Cashier drug-catalog removal (owner decision 2026-11-24: no pharmacy
-- anywhere). The Windows cashier purge PR removed every client reference:
-- sale line items no longer carry drug_catalog_id and the app never calls
-- the drug RPCs. This migration removes the server side.
--
-- NUMBERING: assigned 433 by the builder (432 is reserved for the
-- overhaul agent's #16). Moved from pos/docs/server-migrations/.
--
-- ORDERING: independent of the UI keeper's pharmacy purge PR. Dependent
-- objects that PR also removes (pharmacy network column, MoH/PRO price
-- RPCs, import RPC) are dropped here with IF EXISTS guards so either
-- landing order applies cleanly. Both PRs must land before publish.
--
-- DATA: drug_catalog holds the MoH reference dataset. The UI keeper dumps
-- it to backup before this runs (their stated pre-destructive step).
--
-- Verified against origin/master 7d4eb2ac: cashier_sync_push body is
-- exactly 420's (the latest), with the drug_catalog_id line-item key
-- removed and two comments reworded. Grants on the function survive
-- CREATE OR REPLACE.

BEGIN;

-- 1. cashier_sync_push: no drug_catalog_id in stored line items.
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
  v_license_code text;
  v_cust uuid;
BEGIN
  IF v_uid IS NULL OR NOT public.is_merchant_owner(p_merchant_id) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  -- 419 v2 (review #128): license state is computed ONCE per call and
  -- enforced per op below; recovery ops (sale_void, debt_payment) stay
  -- allowed while locked so a locked merchant can still reverse/collect.
  v_license_code := public.cashier_license_check(p_merchant_id);
  IF jsonb_typeof(p_ops) <> 'array' THEN RAISE EXCEPTION 'ops must be an array'; END IF;
  SELECT * INTO v_merchant FROM public.merchants WHERE id = p_merchant_id;

  FOR v_op IN SELECT * FROM jsonb_array_elements(p_ops) LOOP
    v_type := v_op->>'type';
    v_op_id := (v_op->>'op_id')::uuid;
    -- 419 v2: while locked, refuse everything except the recovery ops;
    -- the refusal is THIS op's result, never a batch-level abort.
    IF v_license_code IS NOT NULL AND v_type NOT IN ('sale_void','debt_payment') THEN
      v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', false, 'reason', v_license_code);
      CONTINUE;
    END IF;
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
        -- 420 (review #117b): on a duplicate, return the EXISTING shift id
        -- resolved by the same dedupe key, so a client that crashed before
        -- saving its local->server map recovers the mapping on retry.
        IF v_shift_id IS NULL THEN
          SELECT s.id INTO v_shift_id FROM public.pos_shifts s
           WHERE s.merchant_id = p_merchant_id AND s.client_op_id = v_op_id;
        END IF;
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
        -- 420 (review #118): a deferred sale to a customer created OFFLINE
        -- references the customer op's client id; resolve it to the server
        -- id (the customer op always arrives earlier in this batch/order).
        v_cust := NULLIF(v_op->'payload'->>'customer_id','')::uuid;
        IF v_cust IS NOT NULL THEN
          SELECT c.id INTO v_cust FROM public.pos_customers c
           WHERE c.merchant_id = p_merchant_id
             AND (c.id = v_cust OR c.client_op_id = v_cust);
        END IF;
        -- Offline sale recorded as fact into the shared pos_sales table, but
        -- money is repriced SERVER-SIDE (review #26): any line whose
        -- product_id resolves is priced from public.products (through the
        -- shared _price_order_line helper for whole-number quantities), and
        -- commission is charged on the server total. Lines only the client
        -- could price (offline quick lines) are flagged client_priced
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
            -- Offline quick line with no store product row: only the client
            -- could price it. Keep the claimed price, flag the line.
            v_unit := (v_item->>'unit_price')::numeric;
            v_cp := true;
            v_client_priced := v_client_priced + 1;
          END IF;
          v_line_disc := LEAST(GREATEST(COALESCE((v_item->>'discount_amount')::numeric, 0), 0),
                               v_unit * v_qty);
          v_lines := v_lines || jsonb_build_object(
            'product_id', v_prod,
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
           v_cust,
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
        -- 420 v2 (review #129): ANY deferred amount without a resolved
        -- customer fails the whole op (omitted, null, blank, unknown or
        -- foreign reference alike) - the subtransaction rolls the sale,
        -- payments, stock moves and commission back, and the op stays
        -- queued instead of writing debtor-less money rows.
        IF v_deferred > 0 AND v_cust IS NULL THEN
          RAISE EXCEPTION 'CUSTOMER_UNRESOLVED';
        END IF;
        IF v_deferred > 0 THEN
          INSERT INTO public.pos_debt_ledger (merchant_id, customer_id, sale_id, kind, amount, created_by, created_offline_at)
          VALUES (p_merchant_id, v_cust,
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
        -- 420: same client-id resolution as the sale arm; a payment with no
        -- resolvable debtor fails and stays queued.
        v_cust := NULLIF(v_op->'payload'->>'customer_id','')::uuid;
        IF v_cust IS NOT NULL THEN
          SELECT c.id INTO v_cust FROM public.pos_customers c
           WHERE c.merchant_id = p_merchant_id
             AND (c.id = v_cust OR c.client_op_id = v_cust);
        END IF;
        IF v_cust IS NULL THEN
          RAISE EXCEPTION 'CUSTOMER_UNRESOLVED';
        END IF;
        INSERT INTO public.pos_debt_ledger (merchant_id, customer_id, client_op_id, kind, amount, note, created_by, created_offline_at)
        VALUES (p_merchant_id, v_cust, v_op_id, 'payment',
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
$function$;

-- 2. pos_stock_moves: drop the drug reference column.
ALTER TABLE public.pos_stock_moves DROP COLUMN IF EXISTS drug_catalog_id;

-- 3. Drug catalog dependencies (client no longer calls any of these;
--    IF EXISTS so this composes with the keeper's pharmacy purge in
--    either order).
DROP FUNCTION IF EXISTS public.pharmacy_import_drug(uuid, uuid, numeric, integer);
DROP FUNCTION IF EXISTS public.drug_catalog_search(text, integer);
DROP FUNCTION IF EXISTS public.moh_price_import(jsonb);
DROP FUNCTION IF EXISTS public.cashier_apply_moh_prices(uuid);
-- The pharmacy network table carries a drug_catalog FK; the keeper's PR
-- drops that table - this guard makes the order irrelevant.
ALTER TABLE public.pharmacy_transfer_requests DROP COLUMN IF EXISTS drug_catalog_id;

-- 4. The MoH reference dataset itself. Its RLS policies
--    (drug_catalog_read, drug_catalog_admin) drop with the table.
DROP TABLE public.drug_catalog;

COMMIT;
