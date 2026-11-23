-- 424b: PROD-ONLY backports (security-reviewer triage 2026-11-23).
--
-- Every body replace is guarded by a live pre-state md5 check:
--   * prod pre-state md5  -> the backport applies;
--   * staging's newer body (398/400) or the backport target -> skipped,
--     so this file CANNOT clobber staging and is safe to re-run on prod;
--   * anything else       -> loud abort.
-- No gift-credit / platform-credit parts; none exist in these bodies.
-- 395 stays staging-only pending the owner's confirmation.
-- All columns touched verified present on prod 2026-11-23; audit_log and
-- its columns exist on prod; the helpers come from 424a.
--
-- pos_sales idempotency: prod still carries the GLOBAL unique constraint
-- pos_sales_idempotency_key_key (verified live 2026-11-23); with a
-- merchant-scoped replay lookup that would 23505 across merchants, so the
-- constraint is swapped for the per-merchant partial unique index (the
-- 400 shape). The swap statements are idempotent/convergent (staging
-- already has them via 400) and intentionally unguarded.

BEGIN;

-- ── pos_sales: global unique -> per-merchant partial unique ──────────
ALTER TABLE public.pos_sales DROP CONSTRAINT IF EXISTS pos_sales_idempotency_key_key;
CREATE UNIQUE INDEX IF NOT EXISTS pos_sales_merchant_idempotency_uq
  ON public.pos_sales (merchant_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- ── confirm_cash_collection ─────────────────────────────────────────────────────────
-- staging body verbatim: order confirmation requires 'delivered' (prod allowed 'delivering'), unauthorized ids return NOT_FOUND, canonical lock order orders->rides with linked-partner payment sync, idempotent replay healing, CASH_COLLECTED audit + pair warnings.
DO $g$
DECLARE
  v_md5 text := (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p
                 JOIN pg_namespace n ON n.oid=p.pronamespace
                 WHERE n.nspname='public' AND p.proname='confirm_cash_collection');
BEGIN
  IF v_md5 = '0b1310bd3142b9bca01c3d074e3dd953' THEN
    EXECUTE $ccc$
CREATE OR REPLACE FUNCTION public.confirm_cash_collection(p_reference_type cash_ref_type, p_reference_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  DECLARE
  v_uid uuid := auth.uid();
  v_is_owner boolean;
  v_is_driver boolean;
  v_is_provider uuid;
  v_provider_user uuid;
  v_status text;
  v_pay_status text;
  v_pay_method text;
  v_amount numeric;
  v_linked_amount numeric;
  v_driver_id uuid;
  v_order_id uuid;
  v_already boolean := false;
  v_stamp timestamptz;
  v_warnings jsonb := '[]'::jsonb;
  v_r record;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED');
  END IF;
  IF p_reference_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_REFERENCE');
  END IF;

  v_is_owner := public._is_owner_uid(v_uid);

  -- ── ORDER (commerce) ────────────────────────────────────────────
  -- Canonical lock order: orders first, then rides.
  IF p_reference_type = 'order'::public.cash_ref_type THEN
    SELECT status, payment_status, payment_method, driver_id, total_amount, cash_collected_at
      INTO v_status, v_pay_status, v_pay_method, v_driver_id, v_amount, v_stamp
      FROM public.orders
     WHERE id = p_reference_id
     FOR UPDATE;

    -- Authorization FIRST: only the owner or the physically assigned driver
    -- may learn anything about this id. Everyone else gets the same
    -- NOT_FOUND a nonexistent id returns.
    v_is_driver := COALESCE(
      v_driver_id IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.drivers d
         WHERE d.user_id = v_uid AND d.id = v_driver_id
      ),
      FALSE
    );
    IF NOT v_is_driver AND NOT v_is_owner THEN
      RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND');
    END IF;

    IF v_pay_method <> 'cash' THEN
      RETURN jsonb_build_object('ok', false, 'code', 'NOT_CASH');
    END IF;
    IF v_pay_status NOT IN ('unpaid', 'pending', 'paid') THEN
      RETURN jsonb_build_object('ok', false, 'code', 'INVALID_STATUS', 'current_status', v_pay_status);
    END IF;
    -- Completed-handoff predicate: the order reaches 'delivered' only when
    -- its delivery ride completed, which requires the recipient OTP. The
    -- captain UI alone is not the gate; the server refuses earlier.
    IF NOT v_is_owner AND v_status <> 'delivered' THEN
      RETURN jsonb_build_object('ok', false, 'code', 'INVALID_LIFECYCLE', 'current_status', v_status);
    END IF;

    v_already := v_pay_status = 'paid';
    IF NOT v_already THEN
      UPDATE public.orders
         SET payment_status = 'paid',
             cash_collected_at = now(),
             cash_collected_by = v_uid,
             updated_at = now()
       WHERE id = p_reference_id;
    ELSIF v_stamp IS NULL THEN
      -- Replay heals a historical paid row missing its collection stamp.
      UPDATE public.orders
         SET cash_collected_at = COALESCE(updated_at, now()),
             cash_collected_by = COALESCE(cash_collected_by, v_uid)
       WHERE id = p_reference_id;
    END IF;

    -- Sync the linked delivery rides. Never resurrect payment: only cash
    -- rides still unpaid/pending are stamped; refunded, failed or non-cash
    -- partners are skipped and reported for reconciliation. Every paid cash
    -- partner gets its own CASH_COLLECTED audit row (idempotent).
    FOR v_r IN
      SELECT id, fare, payment_method, payment_status, status, cash_collected_at
        FROM public.rides
       WHERE order_id = p_reference_id
         AND status <> 'cancelled'
       ORDER BY id
       FOR UPDATE
    LOOP
      IF v_r.payment_method = 'cash' AND v_r.payment_status IN ('unpaid', 'pending') THEN
        UPDATE public.rides
           SET payment_status = 'paid',
               cash_collected_at = COALESCE(cash_collected_at, now()),
               cash_collected_by = COALESCE(cash_collected_by, v_uid)
         WHERE id = v_r.id;
        PERFORM public._audit_cash_collection('ride', v_r.id, v_amount);
      ELSIF v_r.payment_method = 'cash' AND v_r.payment_status = 'paid' THEN
        -- Partner already paid: heal its missing stamp and audit row
        -- (both idempotent) so the rating RLS and the UI agree.
        IF v_r.cash_collected_at IS NULL THEN
          UPDATE public.rides
             SET cash_collected_at = COALESCE(completed_at, now()),
                 cash_collected_by = COALESCE(cash_collected_by, v_uid)
           WHERE id = v_r.id;
        END IF;
        PERFORM public._audit_cash_collection('ride', v_r.id, v_amount);
      ELSE
        v_warnings := v_warnings || jsonb_build_object(
          'resource', 'ride', 'id', v_r.id,
          'payment_method', v_r.payment_method,
          'payment_status', v_r.payment_status);
      END IF;
    END LOOP;

    PERFORM public._audit_cash_collection('order', p_reference_id, v_amount);
    PERFORM public._audit_cash_pair_mismatch('order', p_reference_id, v_warnings);
    RETURN jsonb_build_object(
      'ok', true,
      'code', CASE WHEN v_already THEN 'ALREADY_COLLECTED' ELSE 'COLLECTED' END,
      'reference_id', p_reference_id,
      'amount', v_amount,
      'pair_warnings', v_warnings);
  END IF;

  -- ── RIDE (direct delivery) ──────────────────────────────────────
  IF p_reference_type = 'ride'::public.cash_ref_type THEN
    -- Canonical lock order: orders first, then rides. Read the ride once
    -- without a lock to find the partner order, lock the order, then lock
    -- the ride and re-read it so every check below runs on locked state.
    SELECT order_id INTO v_order_id FROM public.rides WHERE id = p_reference_id;
    IF v_order_id IS NOT NULL THEN
      SELECT total_amount INTO v_linked_amount
        FROM public.orders WHERE id = v_order_id FOR UPDATE;
    END IF;

    SELECT status, payment_status, payment_method, driver_id, fare, order_id, cash_collected_at
      INTO v_status, v_pay_status, v_pay_method, v_driver_id, v_amount, v_order_id, v_stamp
      FROM public.rides
     WHERE id = p_reference_id
     FOR UPDATE;

    -- Authorization FIRST, same NOT_FOUND shape as a missing id.
    v_is_driver := COALESCE(
      v_driver_id IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.drivers d
         WHERE d.user_id = v_uid AND d.id = v_driver_id
      ),
      FALSE
    );
    IF NOT v_is_driver AND NOT v_is_owner THEN
      RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND');
    END IF;

    -- What the customer physically hands over: the linked order's total
    -- (goods + delivery) when there is one, otherwise the delivery fare.
    v_amount := COALESCE(v_linked_amount, v_amount);

    IF v_pay_method <> 'cash' THEN
      RETURN jsonb_build_object('ok', false, 'code', 'NOT_CASH');
    END IF;
    IF v_pay_status NOT IN ('pending', 'unpaid', 'paid') THEN
      RETURN jsonb_build_object('ok', false, 'code', 'INVALID_STATUS', 'current_status', v_pay_status);
    END IF;
    -- Completed-handoff predicate: complete_delivery sets 'completed' only
    -- after the dropoff recipient OTP verifies.
    IF NOT v_is_owner AND v_status <> 'completed' THEN
      RETURN jsonb_build_object('ok', false, 'code', 'INVALID_LIFECYCLE', 'current_status', v_status);
    END IF;

    v_already := v_pay_status = 'paid';
    IF NOT v_already THEN
      UPDATE public.rides
         SET payment_status = 'paid',
             cash_collected_at = now(),
             cash_collected_by = v_uid
       WHERE id = p_reference_id;
    ELSIF v_stamp IS NULL THEN
      -- Replay heals a historical paid row missing its collection stamp.
      UPDATE public.rides
         SET cash_collected_at = COALESCE(completed_at, now()),
             cash_collected_by = COALESCE(cash_collected_by, v_uid)
       WHERE id = p_reference_id;
    END IF;

    -- Sync the linked commerce order with the same never-resurrect guard.
    IF v_order_id IS NOT NULL THEN
      SELECT o.payment_method, o.payment_status, o.status
        INTO v_pay_method, v_pay_status, v_status
        FROM public.orders o WHERE o.id = v_order_id;
      IF v_pay_method = 'cash' AND v_pay_status IN ('unpaid', 'pending') AND v_status <> 'cancelled' THEN
        UPDATE public.orders
           SET payment_status = 'paid',
               cash_collected_at = COALESCE(cash_collected_at, now()),
               cash_collected_by = COALESCE(cash_collected_by, v_uid),
               updated_at = now()
         WHERE id = v_order_id;
        PERFORM public._audit_cash_collection('order', v_order_id, v_linked_amount);
      ELSIF v_pay_method = 'cash' AND v_pay_status = 'paid' THEN
        -- Partner already paid: heal its missing stamp and audit row
        -- (both idempotent) so the rating RLS and the UI agree.
        UPDATE public.orders
           SET cash_collected_at = COALESCE(cash_collected_at, updated_at, now()),
               cash_collected_by = COALESCE(cash_collected_by, v_uid)
         WHERE id = v_order_id
           AND cash_collected_at IS NULL;
        PERFORM public._audit_cash_collection('order', v_order_id, v_linked_amount);
      ELSIF v_pay_status IS NOT NULL THEN
        v_warnings := v_warnings || jsonb_build_object(
          'resource', 'order', 'id', v_order_id,
          'payment_method', v_pay_method,
          'payment_status', v_pay_status);
      END IF;
    END IF;

    PERFORM public._audit_cash_collection('ride', p_reference_id, v_amount);
    PERFORM public._audit_cash_pair_mismatch('ride', p_reference_id, v_warnings);
    RETURN jsonb_build_object(
      'ok', true,
      'code', CASE WHEN v_already THEN 'ALREADY_COLLECTED' ELSE 'COLLECTED' END,
      'reference_id', p_reference_id,
      'amount', v_amount,
      'pair_warnings', v_warnings);
  END IF;

  -- ── SERVICE BOOKING (provider) ──────────────────────────────────
  IF p_reference_type = 'service_booking'::public.cash_ref_type THEN
    SELECT b.status, b.payment_status, b.payment_method,
           p.user_id::uuid
      INTO v_status, v_pay_status, v_pay_method, v_provider_user
      FROM public.service_bookings b
      JOIN public.service_providers p ON p.id = b.provider_id
     WHERE b.id = p_reference_id
     FOR UPDATE OF b;

    -- Authorization FIRST: provider or owner only; everyone else sees the
    -- same NOT_FOUND a missing id returns.
    v_is_provider := v_provider_user;
    IF (v_is_provider IS DISTINCT FROM v_uid) AND NOT v_is_owner THEN
      RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND');
    END IF;

    -- Method and state checks BEFORE the paid replay: a paid card/wallet
    -- booking must never get a cash stamp or a CASH_COLLECTED audit, and a
    -- refunded booking is refused, not resurrected.
    IF v_pay_method <> 'cash' THEN
      RETURN jsonb_build_object('ok', false, 'code', 'NOT_CASH');
    END IF;
    IF v_pay_status NOT IN ('unpaid', 'pending', 'paid') THEN
      RETURN jsonb_build_object('ok', false, 'code', 'INVALID_STATUS', 'current_status', v_pay_status);
    END IF;
    IF v_pay_status = 'paid' THEN
      -- Heal a missing stamp only; collected_by is filled from the current
      -- caller only when the stamp is healed in the same call. A stamped
      -- booking with a NULL collector keeps NULL — never invented.
      UPDATE public.service_bookings
         SET cash_collected_at = COALESCE(updated_at, now()),
             cash_collected_by = COALESCE(cash_collected_by, v_uid)
       WHERE id = p_reference_id
         AND cash_collected_at IS NULL;
      PERFORM public._audit_cash_collection('service_booking', p_reference_id, NULL);
      RETURN jsonb_build_object('ok', true, 'code', 'ALREADY_COLLECTED', 'reference_id', p_reference_id);
    END IF;
    IF NOT v_is_owner AND v_status <> 'completed' THEN
      RETURN jsonb_build_object('ok', false, 'code', 'INVALID_LIFECYCLE', 'current_status', v_status);
    END IF;

    UPDATE public.service_bookings
       SET payment_status = 'paid',
           cash_collected_at = now(),
           cash_collected_by = v_uid,
           updated_at = now()
     WHERE id = p_reference_id
     RETURNING COALESCE(final_price, estimated_price) INTO v_amount;

    PERFORM public._audit_cash_collection('service_booking', p_reference_id, v_amount);
    RETURN jsonb_build_object('ok', true, 'code', 'COLLECTED', 'reference_id', p_reference_id, 'amount', v_amount);
  END IF;

  RETURN jsonb_build_object('ok', false, 'code', 'INVALID_REFERENCE_TYPE');
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND', 'reference_type', p_reference_type::text);
END;
$function$
$ccc$;
  ELSIF v_md5 IN ('9bba5a7f0e1411410b0917b16dfeefad', '9bba5a7f0e1411410b0917b16dfeefad') THEN
    RAISE NOTICE '424b: confirm_cash_collection already at staging/target state (%), skipped', v_md5;
  ELSE
    RAISE EXCEPTION '424b: confirm_cash_collection unexpected pre-state md5 % - aborting', v_md5;
  END IF;
END $g$;

-- ── rate_ride ─────────────────────────────────────────────────────────
-- staging body verbatim: only a completed ride is rateable; a cash ride requires cash_collected_at (matches the RLS).
DO $g$
DECLARE
  v_md5 text := (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p
                 JOIN pg_namespace n ON n.oid=p.pronamespace
                 WHERE n.nspname='public' AND p.proname='rate_ride');
BEGIN
  IF v_md5 = '59c7a16a2ce1ad8acf2439c9966a21cf' THEN
    EXECUTE $rr$
CREATE OR REPLACE FUNCTION public.rate_ride(p_ride_id uuid, p_rating integer, p_feedback text DEFAULT NULL::text, p_tip numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_fare numeric;
  v_tip numeric;
  v_pay_method text;
  v_collected_at timestamptz;
  v_status text;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'UNAUTHENTICATED');
  END IF;
  IF p_rating < 1 OR p_rating > 5 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_RATING');
  END IF;
  SELECT fare, payment_method, cash_collected_at, status
    INTO v_fare, v_pay_method, v_collected_at, v_status
    FROM public.rides WHERE id = p_ride_id AND rider_id = v_uid FOR UPDATE;
  IF v_fare IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_YOUR_RIDE');
  END IF;
  -- Only a completed ride can be rated (matches the RLS predicate).
  IF v_status <> 'completed' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'RIDE_NOT_COMPLETED');
  END IF;
  -- A cash ride is rateable only after the cash was collected.
  IF v_pay_method = 'cash' AND v_collected_at IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'CASH_NOT_COLLECTED');
  END IF;
  -- Clamp tip to [0, fare]
  v_tip := COALESCE(p_tip, 0);
  IF v_tip < 0 THEN v_tip := 0; END IF;
  IF v_tip > COALESCE(v_fare, 0) THEN v_tip := COALESCE(v_fare, 0); END IF;

  UPDATE public.rides
     SET rating = p_rating, feedback = p_feedback, tip = v_tip
   WHERE id = p_ride_id AND rider_id = v_uid;
  RETURN jsonb_build_object('ok', true, 'tip', v_tip);
END;
$function$
$rr$;
  ELSIF v_md5 IN ('4c167fe1e1aab6c01af6a50cf6d4b735', '4c167fe1e1aab6c01af6a50cf6d4b735') THEN
    RAISE NOTICE '424b: rate_ride already at staging/target state (%), skipped', v_md5;
  ELSE
    RAISE EXCEPTION '424b: rate_ride unexpected pre-state md5 % - aborting', v_md5;
  END IF;
END $g$;

-- ── provider_set_working_hours ─────────────────────────────────────────────────────────
-- prod body + regex rejects 24:xx-29:xx. Staging's 398 overnight-window semantics deliberately NOT backported; prod keeps the close-after-open rule.
DO $g$
DECLARE
  v_md5 text := (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p
                 JOIN pg_namespace n ON n.oid=p.pronamespace
                 WHERE n.nspname='public' AND p.proname='provider_set_working_hours');
BEGIN
  IF v_md5 = '17262838dc784a15d723021fb19f171b' THEN
    EXECUTE $wh$
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

    IF NOT v_closed AND v_open >= v_close THEN
      RAISE EXCEPTION 'Closing time must be after opening time on day %', v_day;
    END IF;

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
$wh$;
  ELSIF v_md5 IN ('23fb4da4e061c3b88aa483e234825932', '7c2f6d1b25ca39384e35120df2aa0210') THEN
    RAISE NOTICE '424b: provider_set_working_hours already at staging/target state (%), skipped', v_md5;
  ELSE
    RAISE EXCEPTION '424b: provider_set_working_hours unexpected pre-state md5 % - aborting', v_md5;
  END IF;
END $g$;

-- ── pharmacy_import_drug ─────────────────────────────────────────────────────────
-- prod body + barcode trimmed ONCE (NULLIF(btrim)) used for the dedup lookup AND the stored row (prod has no canonicalize trigger; 400 is staging-only). Staging's unique-index race re-read not backported (no such index on prod).
DO $g$
DECLARE
  v_md5 text := (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p
                 JOIN pg_namespace n ON n.oid=p.pronamespace
                 WHERE n.nspname='public' AND p.proname='pharmacy_import_drug');
BEGIN
  IF v_md5 = '82dc574833b609a86da914050e674290' THEN
    EXECUTE $ph$
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
  v_barcode text;
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

  -- 424b: normalize the barcode ONCE (trim) and use the trimmed value for
  -- the dedup lookup AND the stored row. (Prod has no canonicalize
  -- trigger - 400 is staging-only - so the function must do it.)
  v_barcode := NULLIF(btrim(v_drug.barcode, E' \t\r\n'), '');

  -- Default to the official retail price when the caller does not set one.
  v_price := COALESCE(p_price, v_drug.official_price_egp);
  IF v_price IS NULL OR v_price < 0 THEN
    RAISE EXCEPTION 'INVALID_PRICE';
  END IF;

  -- Duplicate guard: re-importing the same drug returns the existing product.
  SELECT id INTO v_product_id FROM public.products
   WHERE merchant_id = p_merchant_id
     AND ((v_barcode IS NOT NULL AND barcode = v_barcode)
          OR (v_barcode IS NULL
              AND name = v_drug.name_en || COALESCE(' ' || v_drug.strength, '')))
   ORDER BY created_at
   LIMIT 1;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'product_id', v_product_id, 'duplicate', true);
  END IF;

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
    v_barcode
  )
  RETURNING id INTO v_product_id;

  RETURN jsonb_build_object('ok', true, 'product_id', v_product_id);
END;
$function$
$ph$;
  ELSIF v_md5 IN ('7249f4a78b7f22e8725f6a653ead5f8f', '7d1c8a7aa115f2d5d79023494ae8fc2c') THEN
    RAISE NOTICE '424b: pharmacy_import_drug already at staging/target state (%), skipped', v_md5;
  ELSE
    RAISE EXCEPTION '424b: pharmacy_import_drug unexpected pre-state md5 % - aborting', v_md5;
  END IF;
END $g$;

-- ── pos_create_sale ─────────────────────────────────────────────────────────
-- prod body + replay lookup scoped to the merchant, paired with the per-merchant idempotency index below. Staging's #96 advisory lock + sub-block restructure deliberately NOT backported.
DO $g$
DECLARE
  v_md5 text := (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p
                 JOIN pg_namespace n ON n.oid=p.pronamespace
                 WHERE n.nspname='public' AND p.proname='pos_create_sale');
BEGIN
  IF v_md5 = 'd1b339b24d960ec9503c0b3e17e7b601' THEN
    EXECUTE $pos$
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
$function$
$pos$;
  ELSIF v_md5 IN ('ca32bc89277d6777be2ac66f0c3a8683', '0004abb4841688095ae1a2ae58ebb488') THEN
    RAISE NOTICE '424b: pos_create_sale already at staging/target state (%), skipped', v_md5;
  ELSE
    RAISE EXCEPTION '424b: pos_create_sale unexpected pre-state md5 % - aborting', v_md5;
  END IF;
END $g$;

-- ACL standard: CREATE OR REPLACE preserves each function's existing
-- grants ({postgres, authenticated, service_role} on prod); assert no
-- PUBLIC/anon leakage.
REVOKE EXECUTE ON FUNCTION public.confirm_cash_collection(cash_ref_type,uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.rate_ride(uuid,integer,text,numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.provider_set_working_hours(jsonb) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.pharmacy_import_drug(uuid,uuid,numeric,integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.pos_create_sale(uuid,jsonb,numeric,text,text,text,text) FROM PUBLIC, anon;

COMMIT;

NOTIFY pgrst, 'reload schema';
