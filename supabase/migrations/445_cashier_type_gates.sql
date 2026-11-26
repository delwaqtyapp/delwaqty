-- 445: cashier-type gates + per-type custom-line rule (PR-B part 1) ========
-- Dark/flagged, migrations first. Carries the PR-B DB conditions:
--  * food + juice_shop cashier eligibility (owner decision Nov 26 00:12:
--    food DOES need a cashier; juice_shop joins the type CHECK).
--  * Type gates INSIDE the 442 RPCs (security condition 3): merchants.type
--    is owner-mutable (the sensitive-fields guard does not cover it), so a
--    merchant can create staff as a cashier-type and then flip away. Gate
--    shift OPEN and SALE on the CURRENT type; never void/close/reads/audit
--    (liveness: a flip mid-shift must not strand the drawer).
--  * Per-type custom-line rule (security condition 4): custom lines are
--    the fraud surface for the cashier role. Managers keep them; cashiers
--    get them only on simple-service types (the simple invoice) or when the
--    owner explicitly enables them per merchant, then under a lower
--    per-line cap plus per-shift count and value caps; the shift close
--    report counts and flags them.
--  * Exhaustive, fail-closed partition (security condition 2): every
--    merchants_type_check value is in exactly one of is_cashier_type /
--    is_simple_service_type; the harness pins the whole partition.
--  * CHECK replacement is drop+add in one transaction with old/new pins
--    and row validation (security condition 5).
-- Presets/modifiers (condition 6) land in 446 on this same PR.

BEGIN;

-- ─── 0. preconditions (A0): 442 tables + 444 objects + pre-image pins ───
-- This migration REPLACES three live 442 functions and 444's
-- is_cashier_type. On a DB where 442/444 never applied, CREATE OR REPLACE
-- would create SECURITY DEFINER functions carrying default PUBLIC EXECUTE
-- (anon-callable), and on a drifted DB it would silently overwrite an
-- unknown body. Refuse both before touching anything (442/443 pattern;
-- body md5s computed from the deterministic 439..444 chain build).
DO $a0$
BEGIN
  IF to_regclass('public.merchant_staff') IS NULL
     OR to_regclass('public.merchant_staff_events') IS NULL
     OR to_regclass('public.pos_shifts') IS NULL
     OR to_regclass('public.pos_sales') IS NULL
     OR to_regclass('public.pos_sale_payments') IS NULL
     OR to_regclass('public.pos_debt_ledger') IS NULL
     OR to_regclass('public.pos_customers') IS NULL
     OR to_regclass('public.pos_stock_moves') IS NULL
     OR to_regclass('public.branches') IS NULL
     OR to_regclass('public.platform_settings') IS NULL THEN
    RAISE EXCEPTION '445 precondition failed: 442 POS/staff tables missing';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_attribute
                  WHERE attrelid = 'public.pos_stock_moves'::regclass
                    AND attname = 'sale_id' AND NOT attisdropped) THEN
    RAISE EXCEPTION '445 precondition failed: pos_stock_moves.sale_id missing (442-era)';
  END IF;
  IF to_regprocedure('public.staff_shift_open(numeric,uuid)') IS NULL
     OR to_regprocedure('public.staff_create_walk_in_sale(jsonb,jsonb,uuid,numeric,uuid,uuid,text)') IS NULL
     OR to_regprocedure('public.staff_shift_close(numeric)') IS NULL
     OR to_regprocedure('public.is_cashier_type(text)') IS NULL
     OR to_regprocedure('public.staff_admin_set_active(uuid,boolean)') IS NULL
     OR to_regprocedure('public._authorize_staff(text,text[])') IS NULL
     OR to_regprocedure('public.feature_enabled(text)') IS NULL
     OR to_regprocedure('public._num_or_null(text)') IS NULL THEN
    RAISE EXCEPTION '445 precondition failed: 442/444 helper objects missing';
  END IF;
  IF md5(pg_get_functiondef('public.staff_shift_open(numeric, uuid)'::regprocedure))
       <> 'bcd1f64882e077d5bb5ea6cc82df9988'
     OR md5(pg_get_functiondef('public.staff_create_walk_in_sale(jsonb, jsonb, uuid, numeric, uuid, uuid, text)'::regprocedure))
       <> '768aaa5526180770a48ba1954f85d17b'
     OR md5(pg_get_functiondef('public.staff_shift_close(numeric)'::regprocedure))
       <> '02a7fc503301ec3bc329cea0660662a1'
     OR md5(pg_get_functiondef('public.is_cashier_type(text)'::regprocedure))
       <> '315ce3bad146ce58b3dd78743ac3bbd5' THEN
    RAISE EXCEPTION '445 precondition failed: a replaced function drifted from its 442/444 pre-image';
  END IF;
  -- CHECK replacement pre-image (reviewer guard gap): refuse a drifted
  -- type list before the DROP. Two real pre-images: the 435-purged
  -- 43-value list (staging/prod) and the older pre-435 list that still
  -- carries 'pharmacy'. Both converge on the same 445 post-image.
  IF (SELECT pg_get_constraintdef(oid) FROM pg_constraint
       WHERE conname = 'merchants_type_check'
         AND conrelid = 'public.merchants'::regclass) NOT IN (
    'CHECK ((type = ANY (ARRAY[''food''::text, ''restaurant''::text, ''grocery''::text, ''supermarket''::text, ''electronics''::text, ''fashion''::text, ''flowers''::text, ''bakery''::text, ''general''::text, ''fruits''::text, ''meat''::text, ''seafood''::text, ''sweets''::text, ''clothing''::text, ''shoes''::text, ''mobile''::text, ''furniture''::text, ''home''::text, ''cafe''::text, ''petShop''::text, ''fitness''::text, ''gas''::text, ''carwash''::text, ''perfumes''::text, ''spices''::text, ''dairy''::text, ''accessories''::text, ''butcher''::text, ''vegetables''::text, ''service''::text, ''home_services''::text, ''plumbing''::text, ''electrical''::text, ''cleaning''::text, ''handyman''::text, ''carpentry''::text, ''ac_maintenance''::text, ''painting''::text, ''pest_control''::text, ''appliance_repair''::text, ''doctor''::text, ''clinic''::text, ''other''::text])))',
    'CHECK ((type = ANY (ARRAY[''food''::text, ''restaurant''::text, ''grocery''::text, ''supermarket''::text, ''pharmacy''::text, ''electronics''::text, ''fashion''::text, ''flowers''::text, ''bakery''::text, ''general''::text, ''fruits''::text, ''meat''::text, ''seafood''::text, ''sweets''::text, ''clothing''::text, ''shoes''::text, ''mobile''::text, ''furniture''::text, ''home''::text, ''cafe''::text, ''petShop''::text, ''fitness''::text, ''gas''::text, ''carwash''::text, ''perfumes''::text, ''spices''::text, ''dairy''::text, ''accessories''::text, ''butcher''::text, ''vegetables''::text, ''service''::text, ''home_services''::text, ''plumbing''::text, ''electrical''::text, ''cleaning''::text, ''handyman''::text, ''carpentry''::text, ''ac_maintenance''::text, ''painting''::text, ''pest_control''::text, ''appliance_repair''::text, ''doctor''::text, ''clinic''::text, ''other''::text])))'
  ) THEN
    RAISE EXCEPTION '445 precondition failed: merchants_type_check drifted from both known pre-images';
  END IF;
END
$a0$;

-- ─── 1. merchants_type_check gains juice_shop (condition 5) ───────────
-- 435's definition (43 values, pharmacy purged) + 'juice_shop'. Existing
-- rows are validated against the new list before it is installed.
DO $g$
BEGIN
  IF EXISTS (SELECT 1 FROM public.merchants m
             WHERE m.type <> ALL (ARRAY[
               'food','restaurant','grocery','supermarket','electronics',
               'fashion','flowers','bakery','general','fruits','meat',
               'seafood','sweets','clothing','shoes','mobile','furniture',
               'home','cafe','petShop','fitness','gas','carwash','perfumes',
               'spices','dairy','accessories','butcher','vegetables',
               'service','home_services','plumbing','electrical','cleaning',
               'handyman','carpentry','ac_maintenance','painting',
               'pest_control','appliance_repair','doctor','clinic','other',
               'juice_shop'])) THEN
    RAISE EXCEPTION 'merchants rows violate the 445 type list';
  END IF;
END $g$;
ALTER TABLE public.merchants DROP CONSTRAINT merchants_type_check;
ALTER TABLE public.merchants ADD CONSTRAINT merchants_type_check
  CHECK ((type = ANY (ARRAY['food'::text, 'restaurant'::text, 'grocery'::text, 'supermarket'::text, 'electronics'::text, 'fashion'::text, 'flowers'::text, 'bakery'::text, 'general'::text, 'fruits'::text, 'meat'::text, 'seafood'::text, 'sweets'::text, 'clothing'::text, 'shoes'::text, 'mobile'::text, 'furniture'::text, 'home'::text, 'cafe'::text, 'petShop'::text, 'fitness'::text, 'gas'::text, 'carwash'::text, 'perfumes'::text, 'spices'::text, 'dairy'::text, 'accessories'::text, 'butcher'::text, 'vegetables'::text, 'service'::text, 'home_services'::text, 'plumbing'::text, 'electrical'::text, 'cleaning'::text, 'handyman'::text, 'carpentry'::text, 'ac_maintenance'::text, 'painting'::text, 'pest_control'::text, 'appliance_repair'::text, 'doctor'::text, 'clinic'::text, 'other'::text, 'juice_shop'::text])));

-- ─── 2. the partition: is_cashier_type + is_simple_service_type ───────
-- food joins the cashier list (owner decision; juice_shop was already in
-- 444's list and now exists in the CHECK). Everything else about
-- is_cashier_type is unchanged: pure, IMMUTABLE, SECURITY INVOKER, and
-- fail-closed for NULL/unknown.
CREATE OR REPLACE FUNCTION public.is_cashier_type(p_type text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SECURITY INVOKER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(p_type = ANY (ARRAY[
    'food','restaurant','cafe','juice_shop','bakery','sweets','grocery',
    'supermarket','fruits','vegetables','butcher','meat','seafood','dairy',
    'spices','general','electronics','mobile','fashion','clothing','shoes',
    'accessories','perfumes','flowers','petShop','furniture','home'
  ]), false);
$function$;

-- Simple services sell time and work, not catalog goods: the POS for them
-- is the simple (free-text) invoice, and the cashier app is not their
-- surface. Complement of the cashier list over the CHECK; the harness
-- asserts the partition is exhaustive and disjoint. general = goods ok
-- and other/gas/carwash = simple-service ok per the security review.
CREATE FUNCTION public.is_simple_service_type(p_type text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SECURITY INVOKER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(p_type = ANY (ARRAY[
    'service','home_services','plumbing','electrical','cleaning','handyman',
    'carpentry','ac_maintenance','painting','pest_control',
    'appliance_repair','doctor','clinic','other','gas','carwash','fitness'
  ]), false);
$function$;

-- ─── 3. per-merchant staff settings (owner-managed) ───────────────────
-- cashier_custom_lines (default off): lets the CASHIER role add custom
-- lines at a cashier-type shop, under the tighter caps in section 5.
ALTER TABLE public.merchants
  ADD COLUMN IF NOT EXISTS staff_settings jsonb NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.merchants.staff_settings IS
  'Per-merchant staff/POS owner settings (445). Known keys: cashier_custom_lines (boolean, default false). Owner-writable via the merchants update policy; the guard trigger rejects unknown keys and non-boolean values.';

-- Whitelist guard for the new column: unknown keys and non-boolean values
-- are refused for EVERY writer, so no code path can smuggle a setting the
-- sale RPC would honor.
CREATE FUNCTION public._assert_staff_settings_shape()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_key text;
BEGIN
  IF jsonb_typeof(NEW.staff_settings) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION 'staff_settings must be an object';
  END IF;
  FOR v_key IN SELECT k FROM jsonb_object_keys(NEW.staff_settings) AS k LOOP
    IF v_key <> 'cashier_custom_lines' THEN
      RAISE EXCEPTION 'unknown staff_settings key %', v_key;
    END IF;
    IF jsonb_typeof(NEW.staff_settings -> v_key) IS DISTINCT FROM 'boolean' THEN
      RAISE EXCEPTION 'staff_settings.% must be a boolean', v_key;
    END IF;
  END LOOP;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public._assert_staff_settings_shape() FROM PUBLIC, anon, authenticated;

CREATE TRIGGER trg_merchants_staff_settings_shape
  BEFORE INSERT OR UPDATE OF staff_settings ON public.merchants
  FOR EACH ROW EXECUTE FUNCTION public._assert_staff_settings_shape();


CREATE OR REPLACE FUNCTION public.staff_shift_open(p_opening_float numeric DEFAULT 0, p_client_op_id uuid DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_staff public.merchant_staff%ROWTYPE;
  v_id uuid;
  v_float numeric;
  v_branch uuid;
BEGIN
  v_staff := public._authorize_staff('cashier_mode_mobile', ARRAY['cashier','branch_manager']);
  v_float := round(coalesce(p_opening_float, -1), 2);
  IF v_float < 0 THEN
    RAISE EXCEPTION 'opening float must be >= 0';
  END IF;
  -- 445 gate (security condition 3): merchants.type is owner-mutable (the
  -- sensitive-fields guard does not cover it), so staff work is gated on
  -- the CURRENT type, not the type at provision time. A flip to a
  -- non-cashier type stops NEW staff work here; void/close/reads are
  -- NEVER gated so an open drawer can always be reconciled.
  IF NOT public.is_cashier_type(
       (SELECT m.type FROM public.merchants m WHERE m.id = v_staff.merchant_id)) THEN
    RAISE EXCEPTION 'staff sales need a cashier-type shop';
  END IF;
  -- Serialize with sale/close for this staff member (#252).
  PERFORM pg_advisory_xact_lock(hashtextextended(v_staff.id::text, 442002));
  IF p_client_op_id IS NOT NULL THEN
    SELECT s.id, s.opening_float, s.branch_id INTO v_id, v_float, v_branch FROM public.pos_shifts s
     WHERE s.merchant_id = v_staff.merchant_id AND s.client_op_id = p_client_op_id
     LIMIT 1;
    IF FOUND THEN
      -- Replay must reconcile the payload (#256): same op id, different
      -- float, another staff member's shift, or a different branch is a
      -- conflict.
      IF v_float IS DISTINCT FROM round(coalesce(p_opening_float, -1), 2)
         OR v_branch IS DISTINCT FROM v_staff.branch_id
         OR NOT EXISTS (SELECT 1 FROM public.pos_shifts s2
                         WHERE s2.id = v_id AND s2.opened_by_staff = v_staff.id) THEN
        RAISE EXCEPTION 'idempotency key reused with a different request';
      END IF;
      RETURN jsonb_build_object('id', v_id, 'idempotent_replay', true);
    END IF;
  END IF;
  IF EXISTS (SELECT 1 FROM public.pos_shifts s
              WHERE s.merchant_id = v_staff.merchant_id
                AND s.opened_by_staff = v_staff.id AND s.closed_at IS NULL) THEN
    RAISE EXCEPTION 'close your current shift before opening a new one';
  END IF;
  INSERT INTO public.pos_shifts
    (merchant_id, client_op_id, opened_by, opening_float, branch_id, opened_by_staff)
  VALUES
    (v_staff.merchant_id, p_client_op_id, auth.uid(), round(p_opening_float, 2),
     v_staff.branch_id, v_staff.id)
  RETURNING id INTO v_id;
  INSERT INTO public.merchant_staff_events (staff_id, merchant_id, kind, detail, actor_id)
  VALUES (v_staff.id, v_staff.merchant_id, 'shift_opened',
          jsonb_build_object('shift_id', v_id, 'float', p_opening_float), auth.uid());
  RETURN jsonb_build_object('id', v_id, 'idempotent_replay', false);
EXCEPTION WHEN unique_violation THEN
  -- Two concurrent opens: the partial unique index fired; the winner's
  -- shift exists now (#252).
  RAISE EXCEPTION 'close your current shift before opening a new one';
END;
$function$;


CREATE OR REPLACE FUNCTION public.staff_create_walk_in_sale(
  p_items jsonb,
  p_payments jsonb,
  p_client_op_id uuid,
  p_discount numeric DEFAULT 0,
  p_pos_customer_id uuid DEFAULT NULL,
  p_branch_id uuid DEFAULT NULL,
  p_notes text DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_staff public.merchant_staff%ROWTYPE;
  v_merchant public.merchants%ROWTYPE;
  v_branch uuid;
  v_item jsonb;
  v_product public.products%ROWTYPE;
  v_label text;
  v_qty numeric;
  v_price numeric;
  v_subtotal numeric := 0;
  v_discount numeric := round(coalesce(p_discount, 0), 2);
  v_total numeric;
  v_pay jsonb;
  v_pay_sum numeric := 0;
  v_pay_amount numeric;
  v_methods text[] := '{}';
  v_deferred numeric := 0;
  v_sale_id uuid;
  v_shift uuid;
  v_normalized jsonb := '[]'::jsonb;
  v_stock_ops jsonb := '[]'::jsonb;
  v_applied numeric := 0;
  v_op jsonb;
  v_existing public.pos_sales%ROWTYPE;
  v_request_hash text;
  v_custom_cap numeric;
  v_charge_id bigint;
  v_custom_count int := 0;
  v_custom_value numeric := 0;
  CASHIER_DISCOUNT_CAP constant numeric := 0.10;
  MANAGER_DISCOUNT_CAP constant numeric := 0.50;
BEGIN
  v_staff := public._authorize_staff('cashier_mode_mobile', ARRAY['cashier','branch_manager']);

  -- Branch: derived from the staff row; a manager over all branches must
  -- pass one and it is validated against the merchant.
  v_branch := v_staff.branch_id;
  IF v_branch IS NULL THEN
    IF p_branch_id IS NULL THEN
      RAISE EXCEPTION 'branch required for an all-branches manager';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.branches b
                    WHERE b.id = p_branch_id AND b.merchant_id = v_staff.merchant_id) THEN
      RAISE EXCEPTION 'branch does not belong to this shop';
    END IF;
    v_branch := p_branch_id;
  END IF;

  IF p_client_op_id IS NULL THEN
    RAISE EXCEPTION 'client op id required';
  END IF;

  SELECT * INTO v_merchant FROM public.merchants WHERE id = v_staff.merchant_id;

  -- 445 gate (security condition 3): same current-type check as
  -- staff_shift_open. A flip mid-shift never strands the drawer: close
  -- and void stay ungated, but no NEW sale is taken.
  IF NOT public.is_cashier_type(v_merchant.type) THEN
    RAISE EXCEPTION 'staff sales need a cashier-type shop';
  END IF;

  -- Canonical request fingerprint (#256): the replay contract compares the
  -- WHOLE request, not just the op id.
  v_request_hash := md5(jsonb_build_object(
    'items', p_items, 'payments', p_payments, 'discount', v_discount,
    'customer', p_pos_customer_id, 'branch', v_branch, 'notes', p_notes)::text);

  -- Same-staff serialization for this op id: concurrent first calls queue
  -- here instead of racing to unique_violation (#256).
  PERFORM pg_advisory_xact_lock(hashtextextended(v_staff.merchant_id::text || ':' || p_client_op_id::text, 442001));

  -- Idempotency: replay only for the SAME staff member with the SAME
  -- payload; anything else with this op id is a conflict.
  SELECT * INTO v_existing FROM public.pos_sales s
   WHERE s.merchant_id = v_staff.merchant_id
     AND s.idempotency_key = p_client_op_id::text
   LIMIT 1;
  IF FOUND THEN
    IF v_existing.staff_id IS DISTINCT FROM v_staff.id
       OR v_existing.branch_id IS DISTINCT FROM v_branch
       OR v_existing.request_hash IS DISTINCT FROM v_request_hash THEN
      RAISE EXCEPTION 'idempotency key reused with a different request';
    END IF;
    RETURN jsonb_build_object('id', v_existing.id, 'total', v_existing.total_amount,
                              'idempotent_replay', true);
  END IF;

  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'items required';
  END IF;

  -- Shift + serialization (#267): the shared per-staff advisory lock
  -- (#252/S7) and the open-shift derivation run BEFORE line validation,
  -- so the per-shift custom caps below read settled state: concurrent
  -- requests queue here instead of both passing stale totals, and the
  -- caps add this request's own accepted custom lines to the persisted
  -- ones (read once here, accumulated in the loop).
  PERFORM pg_advisory_xact_lock(hashtextextended(v_staff.id::text, 442002));
  SELECT s.id INTO v_shift FROM public.pos_shifts s
   WHERE s.merchant_id = v_staff.merchant_id
     AND s.opened_by_staff = v_staff.id AND s.closed_at IS NULL
   ORDER BY s.opened_at DESC LIMIT 1;
  IF v_staff.role <> 'branch_manager' THEN
    SELECT count(*), coalesce(sum(round(
             coalesce(public._num_or_null(li.value ->> 'unit_price'), 0)
             * coalesce(public._num_or_null(li.value ->> 'qty'), 0), 2)), 0)
      INTO v_custom_count, v_custom_value
      FROM public.pos_sales s3,
           LATERAL jsonb_array_elements(s3.items) AS li(value)
     WHERE s3.shift_id = v_shift AND s3.status = 'completed'
       AND coalesce((li.value ->> 'custom')::boolean, false) IS TRUE;
  END IF;

  v_custom_cap := coalesce(
    (SELECT public._num_or_null(feature_flags ->> 'custom_line_cap')
       FROM public.platform_settings WHERE id = 'default'), 50000);

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
    v_applied := 0;
    IF v_item ? 'product_id' THEN
      -- S2/#255: a product_id key is a catalog line, ALWAYS. Malformed or
      -- unknown ids refuse; they never fall through to free-text pricing.
      IF (v_item ->> 'product_id') !~ '^[0-9a-fA-F-]{36}$' THEN
        RAISE EXCEPTION 'malformed product_id %', v_item ->> 'product_id';
      END IF;
      v_qty := public._num_or_null(v_item ->> 'qty');
      IF v_qty IS NULL OR v_qty <= 0 OR v_qty <> trunc(v_qty) THEN
        RAISE EXCEPTION 'catalog qty must be a positive integer';
      END IF;
      SELECT * INTO v_product FROM public.products
       WHERE id = (v_item ->> 'product_id')::uuid
         AND merchant_id = v_staff.merchant_id;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'unknown product %', v_item ->> 'product_id';
      END IF;
      IF v_product.is_available IS NOT TRUE THEN
        RAISE EXCEPTION 'product unavailable %', coalesce(v_product.name_ar, v_product.name);
      END IF;
      -- Server-side price: the client never names a price for catalog items.
      v_price := v_product.price;
      v_label := coalesce(v_product.name_ar, v_product.name);
      -- Stock ops are collected and applied after the sale row exists so
      -- the moves can link back to it (S3); same transaction = atomic.
      IF v_product.stock_quantity IS NOT NULL THEN
        v_applied := v_qty;
        v_stock_ops := v_stock_ops || jsonb_build_object(
          'product_id', v_product.id, 'qty', v_qty, 'label', v_label);
      END IF;
    ELSE
      -- Free-text line (service-shop simple invoice): EXPLICIT custom only
      -- (S2), price > 0, manager or service-type shop, value-capped.
      IF coalesce((v_item ->> 'custom')::boolean, false) IS NOT TRUE THEN
        RAISE EXCEPTION 'non-catalog lines must be explicit custom items';
      END IF;
      -- 445 per-type custom-line rule (security condition 4): managers
      -- keep custom lines under the global cap. A CASHIER gets them only
      -- when the owner opts the merchant in (staff_settings.
      -- cashier_custom_lines, default off), then under the tighter
      -- cashier per-line cap plus per-shift count and value caps.
      -- Simple-service types never reach this RPC: the type gate above
      -- refuses non-cashier types; their surface is the provider app's
      -- simple invoice, not the POS.
      IF v_staff.role <> 'branch_manager' THEN
        IF coalesce((v_merchant.staff_settings ->> 'cashier_custom_lines')::boolean, false) IS NOT TRUE THEN
          RAISE EXCEPTION 'custom lines need a branch manager';
        END IF;
        -- #267: a cashier's custom lines ride an open shift for ANY
        -- payment method; a shiftless custom sale reads NULL history and
        -- bypasses every cap AND the shift-close report.
        IF v_shift IS NULL THEN
          RAISE EXCEPTION 'open a shift before custom lines';
        END IF;
        v_custom_cap := coalesce(
          (SELECT public._num_or_null(feature_flags ->> 'cashier_custom_line_cap')
             FROM public.platform_settings WHERE id = 'default'), 5000);
      END IF;
      v_label := nullif(btrim(coalesce(v_item ->> 'label', '')), '');
      IF v_label IS NULL THEN
        RAISE EXCEPTION 'custom item label required';
      END IF;
      v_price := round(coalesce(public._num_or_null(v_item ->> 'price'), -1), 2);
      IF v_price <= 0 THEN
        RAISE EXCEPTION 'custom item price must be a number > 0';
      END IF;
      v_qty := round(coalesce(public._num_or_null(v_item ->> 'qty'), 0), 3);
      IF v_qty <= 0 THEN
        RAISE EXCEPTION 'qty must be a positive number';
      END IF;
      IF v_price * v_qty > v_custom_cap THEN
        RAISE EXCEPTION 'custom line exceeds the % cap', v_custom_cap;
      END IF;
      IF v_staff.role <> 'branch_manager' THEN
        -- #267: persisted + THIS request's already-accepted custom lines,
        -- both under the staff lock above; a batch cannot outrun the caps.
        IF v_custom_count + 1 > coalesce(
             (SELECT public._num_or_null(feature_flags ->> 'cashier_custom_per_shift_count')
                FROM public.platform_settings WHERE id = 'default'), 10) THEN
          RAISE EXCEPTION 'custom lines: shift count cap reached';
        END IF;
        IF v_custom_value + round(v_price * v_qty, 2) > coalesce(
             (SELECT public._num_or_null(feature_flags ->> 'cashier_custom_per_shift_value')
                FROM public.platform_settings WHERE id = 'default'), 20000) THEN
          RAISE EXCEPTION 'custom lines: shift value cap reached';
        END IF;
        v_custom_count := v_custom_count + 1;
        v_custom_value := v_custom_value + round(v_price * v_qty, 2);
      END IF;
    END IF;
    v_subtotal := v_subtotal + round(v_price * v_qty, 2);
    -- Applied-stock metadata (#251): every staff-sale line records what
    -- the sale ACTUALLY decremented -- the qty for tracked catalog lines,
    -- an explicit 0 for untracked and custom lines -- so a later void
    -- (either gate) never has to guess, and tracking that starts after
    -- the sale cannot credit invented stock.
    -- 'custom' marks the free-text lines so the shift close report can
    -- count and flag them (445); pre-445 rows simply lack the key.
    v_normalized := v_normalized || jsonb_build_object(
      'product_id', v_item ->> 'product_id', 'label', v_label,
      'qty', v_qty, 'unit_price', v_price, 'stock_applied', v_applied,
      'custom', NOT (v_item ? 'product_id'));
  END LOOP;

  IF v_discount < 0 OR v_discount > v_subtotal * (CASE v_staff.role
        WHEN 'cashier' THEN CASHIER_DISCOUNT_CAP
        ELSE MANAGER_DISCOUNT_CAP END) THEN
    RAISE EXCEPTION 'discount exceeds the % cap', v_staff.role;
  END IF;
  v_total := round(v_subtotal - v_discount, 2);

  IF p_payments IS NULL OR jsonb_typeof(p_payments) <> 'array'
     OR jsonb_array_length(p_payments) = 0 THEN
    RAISE EXCEPTION 'payments required';
  END IF;
  FOR v_pay IN SELECT value FROM jsonb_array_elements(p_payments) LOOP
    IF (v_pay ->> 'method') NOT IN ('cash','instapay','vodafone_cash','card','deferred') THEN
      RAISE EXCEPTION 'unknown payment method %', v_pay ->> 'method';
    END IF;
    v_pay_amount := round(coalesce(public._num_or_null(v_pay ->> 'amount'), -1), 2);
    IF v_pay_amount < 0 THEN
      RAISE EXCEPTION 'payment amount must be a number >= 0';
    END IF;
    v_pay_sum := v_pay_sum + v_pay_amount;
    v_methods := v_methods || (v_pay ->> 'method');
    IF (v_pay ->> 'method') = 'deferred' THEN
      v_deferred := v_deferred + v_pay_amount;
    END IF;
  END LOOP;
  IF abs(v_pay_sum - v_total) > 0.001 THEN
    RAISE EXCEPTION 'payments (%) must sum to the total (%)', v_pay_sum, v_total;
  END IF;
  IF v_deferred > 0 AND p_pos_customer_id IS NULL THEN
    RAISE EXCEPTION 'deferred payment requires a customer';
  END IF;
  IF p_pos_customer_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.pos_customers c
     WHERE c.id = p_pos_customer_id AND c.merchant_id = v_staff.merchant_id
  ) THEN
    RAISE EXCEPTION 'customer does not belong to this shop';
  END IF;

  -- Shift (#252/S7): derived under the shared per-staff advisory lock
  -- BEFORE the item loop (#267); cash sales REQUIRE an open shift.
  IF 'cash' = ANY(v_methods) AND v_shift IS NULL THEN
    RAISE EXCEPTION 'open a shift before taking cash';
  END IF;

  INSERT INTO public.pos_sales
    (merchant_id, cashier_user_id, items, subtotal, discount, total_amount,
     payment_method, notes, status, idempotency_key, shift_id, branch_id,
     staff_id, pos_customer_id, request_hash)
  VALUES
    (v_staff.merchant_id, auth.uid(), v_normalized, v_subtotal, v_discount,
     v_total, CASE WHEN array_length(v_methods, 1) = 1 THEN v_methods[1] ELSE 'mixed' END,
     p_notes, 'completed', p_client_op_id::text, v_shift, v_branch,
     v_staff.id, p_pos_customer_id, v_request_hash)
  RETURNING id INTO v_sale_id;

  -- Canonical stock (S12): atomic guarded decrement on
  -- products.stock_quantity; the move records what was ACTUALLY applied
  -- and links to the sale for exact void restore (S3).
  FOR v_op IN SELECT value FROM jsonb_array_elements(v_stock_ops) LOOP
    UPDATE public.products
       SET stock_quantity = stock_quantity - (v_op ->> 'qty')::int, updated_at = now()
     WHERE id = (v_op ->> 'product_id')::uuid
       AND stock_quantity >= (v_op ->> 'qty')::int;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'insufficient stock for %', v_op ->> 'label';
    END IF;
    INSERT INTO public.pos_stock_moves
      (merchant_id, product_id, kind, qty, note, created_by, sale_id)
    VALUES
      (v_staff.merchant_id, (v_op ->> 'product_id')::uuid, 'sale',
       -(v_op ->> 'qty')::numeric, 'walk-in sale', auth.uid(), v_sale_id);
  END LOOP;

  FOR v_pay IN SELECT value FROM jsonb_array_elements(p_payments) LOOP
    INSERT INTO public.pos_sale_payments (sale_id, method, amount)
    VALUES (v_sale_id, v_pay ->> 'method', round(public._num_or_null(v_pay ->> 'amount'), 2));
  END LOOP;

  -- أجل (S1): ONE summed charge per sale under its OWN derived key from
  -- the sale id — it can never collide with a debt payment's op id, and a
  -- conflict raises instead of silently dropping the charge.
  IF v_deferred > 0 THEN
    INSERT INTO public.pos_debt_ledger
      (merchant_id, customer_id, sale_id, client_op_id, kind, amount, note, created_by)
    VALUES
      (v_staff.merchant_id, p_pos_customer_id, v_sale_id,
       md5('charge:' || v_sale_id::text)::uuid, 'charge', v_deferred,
       'أجل - بيع محلي', auth.uid())
    ON CONFLICT (merchant_id, client_op_id) DO NOTHING
    RETURNING id INTO v_charge_id;
    IF v_charge_id IS NULL THEN
      RAISE EXCEPTION 'deferred charge conflict for sale %', v_sale_id;
    END IF;
  END IF;

  INSERT INTO public.merchant_staff_events (staff_id, merchant_id, kind, detail, actor_id)
  VALUES (v_staff.id, v_staff.merchant_id, 'walk_in_sale',
          jsonb_build_object('sale_id', v_sale_id, 'total', v_total,
                             'methods', v_methods, 'branch_id', v_branch),
          auth.uid());

  RETURN jsonb_build_object('id', v_sale_id, 'total', v_total, 'idempotent_replay', false);
EXCEPTION WHEN unique_violation THEN
  -- A concurrent first call slipped past the advisory lock window or the
  -- op id is already taken by a different request (#256): never mask it.
  SELECT * INTO v_existing FROM public.pos_sales s
   WHERE s.merchant_id = v_staff.merchant_id
     AND s.idempotency_key = p_client_op_id::text
   LIMIT 1;
  IF FOUND AND v_existing.staff_id IS NOT DISTINCT FROM v_staff.id
     AND v_existing.branch_id IS NOT DISTINCT FROM v_branch
     AND v_existing.request_hash IS NOT DISTINCT FROM v_request_hash THEN
    RETURN jsonb_build_object('id', v_existing.id, 'total', v_existing.total_amount,
                              'idempotent_replay', true);
  END IF;
  RAISE EXCEPTION 'idempotency key reused with a different request';
END;
$function$;


CREATE OR REPLACE FUNCTION public.staff_shift_close(p_closing_cash numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_staff public.merchant_staff%ROWTYPE;
  v_shift public.pos_shifts%ROWTYPE;
  v_cash numeric;
  v_debt_cash numeric;
  v_totals jsonb;
  v_expected numeric;
  v_variance numeric;
  v_custom_count int;
  v_custom_value numeric;
  v_custom jsonb;
BEGIN
  v_staff := public._authorize_staff('cashier_mode_mobile', ARRAY['cashier','branch_manager']);
  IF coalesce(p_closing_cash, -1) < 0 THEN
    RAISE EXCEPTION 'closing cash must be >= 0';
  END IF;
  -- Serialize with open/sale for this staff member (#252).
  PERFORM pg_advisory_xact_lock(hashtextextended(v_staff.id::text, 442002));
  SELECT * INTO v_shift FROM public.pos_shifts s
   WHERE s.merchant_id = v_staff.merchant_id
     AND s.opened_by_staff = v_staff.id AND s.closed_at IS NULL
   ORDER BY s.opened_at DESC LIMIT 1
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'no open shift';
  END IF;
  SELECT coalesce(sum(sub.amount) FILTER (WHERE sub.method = 'cash'), 0),
         coalesce(jsonb_object_agg(sub.method, sub.method_total), '{}'::jsonb)
    INTO v_cash, v_totals
    FROM (SELECT p2.method, sum(p2.amount) AS method_total, sum(p2.amount) AS amount
            FROM public.pos_sale_payments p2
            JOIN public.pos_sales s2 ON s2.id = p2.sale_id
           WHERE s2.shift_id = v_shift.id AND s2.status = 'completed'
           GROUP BY p2.method) sub;
  -- S7: cash debt receipts taken on this shift count in the drawer.
  SELECT coalesce(sum(l.amount), 0) INTO v_debt_cash
    FROM public.pos_debt_ledger l
   WHERE l.shift_id = v_shift.id AND l.kind = 'payment';
  v_expected := v_shift.opening_float + v_cash + v_debt_cash;
  v_variance := round(p_closing_cash, 2) - v_expected;
  -- 445 (security condition 4): custom lines are counted and FLAGGED in
  -- every close report; a non-zero count is the fraud-review signal.
  SELECT count(*), coalesce(sum(round(
           coalesce(public._num_or_null(li.value ->> 'unit_price'), 0)
           * coalesce(public._num_or_null(li.value ->> 'qty'), 0), 2)), 0)
    INTO v_custom_count, v_custom_value
    FROM public.pos_sales s3,
         LATERAL jsonb_array_elements(s3.items) AS li(value)
   WHERE s3.shift_id = v_shift.id AND s3.status = 'completed'
     AND coalesce((li.value ->> 'custom')::boolean, false) IS TRUE;
  v_custom := jsonb_build_object('count', v_custom_count, 'value', v_custom_value,
                                 'flagged', v_custom_count > 0);
  UPDATE public.pos_shifts
     SET closed_at = now(), closing_cash = round(p_closing_cash, 2),
         expected_cash = v_expected,
         totals = v_totals || jsonb_build_object('debt_receipts', v_debt_cash,
                                                 'custom_lines', v_custom)
   WHERE id = v_shift.id;
  INSERT INTO public.merchant_staff_events (staff_id, merchant_id, kind, detail, actor_id)
  VALUES (v_staff.id, v_staff.merchant_id, 'shift_closed',
          jsonb_build_object('shift_id', v_shift.id, 'expected', v_expected,
                             'counted', p_closing_cash, 'variance', v_variance,
                             'debt_receipts', v_debt_cash,
                             'custom_lines', v_custom),
          auth.uid());
  RETURN jsonb_build_object('id', v_shift.id, 'expected', v_expected,
                            'counted', p_closing_cash, 'variance', v_variance,
                            'custom_lines', v_custom);
END;
$function$;

-- ─── 6. grants: explicit after every replacement (security BLOCKING 2) ──
-- CREATE OR REPLACE keeps existing grants, but on a 442-less DB it would
-- CREATE with default PUBLIC EXECUTE; pin the intended ACL either way.
REVOKE EXECUTE ON FUNCTION public.staff_shift_open(numeric, uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.staff_create_walk_in_sale(jsonb, jsonb, uuid, numeric, uuid, uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.staff_shift_close(numeric) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.is_cashier_type(text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.is_simple_service_type(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.staff_shift_open(numeric, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_create_walk_in_sale(jsonb, jsonb, uuid, numeric, uuid, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_shift_close(numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_cashier_type(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_simple_service_type(text) TO authenticated;

COMMIT;
