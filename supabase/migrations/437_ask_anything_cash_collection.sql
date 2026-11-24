-- 437: ask-anything cash collection = locked fare + approved goods.
--
-- Owner money model (2026-11-23): the captain collects the locked delivery
-- fare PLUS the approved goods total; goods are a pass-through, never
-- platform revenue. Both cash functions below used fare only on the ride
-- path, so the captain would have collected and audited half the money.
--
-- Scope discipline:
--   * ONLY the collectable amount and its cash audit change.
--   * Commission, earnings and settlement stay fare-only (security
--     condition); nothing here touches them.
--   * Ordinary courier rides (fare only) and merchant order rides (order
--     total) are byte-identical: the new branch runs only for rides with
--     is_ask_anything, which never carry order_id.
--   * Fail closed: while shopping is unfinished the state function shows
--     no amount and confirm refuses with SHOPPING_UNFINISHED, so no
--     partial amount can ever be displayed, stamped or audited. An
--     incident-cancelled ride keeps its records but settles through the
--     incident report: the state function shows no amount and confirm
--     refuses with RIDE_CANCELLED, even for the owner.
--
-- Release condition (security): this migration must land together with or
-- before the prod apply of 436; until then ask-anything stays disabled
-- for real users.
--
-- Preimage guards pin the live 392/424b bodies by full md5; any drift
-- aborts the migration before anything changes.

BEGIN;

-- Hard dependency: 436 must be applied first.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema='public' AND table_name='rides'
       AND column_name IN ('is_ask_anything','courier_shopping_finished','courier_goods_total')
     GROUP BY table_name HAVING count(*) = 3
  ) THEN
    RAISE EXCEPTION '437: rides ask-anything columns missing - apply 436 first';
  END IF;
END $$;

-- ── driver_cash_collection_state ──────────────────────────────────────
DO $g$
DECLARE
  v_md5 text := (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p
                 JOIN pg_namespace n ON n.oid=p.pronamespace
                 WHERE n.nspname='public' AND p.proname='driver_cash_collection_state');
BEGIN
  IF v_md5 = '9a6a7756c160cb3c3cd1ea2a2bea18a3' THEN
    EXECUTE $fn$
CREATE OR REPLACE FUNCTION public.driver_cash_collection_state(p_ride_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  r public.rides%ROWTYPE;
  v_is_driver boolean;
  v_amount numeric;
  v_order_total numeric;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED');
  END IF;

  SELECT * INTO r FROM public.rides WHERE id = p_ride_id;

  v_is_driver := COALESCE(
    r.driver_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.drivers d
       WHERE d.id = r.driver_id AND d.user_id = auth.uid()
    ),
    FALSE
  );
  IF NOT v_is_driver AND NOT public._is_owner_uid(auth.uid()) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND');
  END IF;

  -- The customer hands over the linked order's total (goods + delivery);
  -- for a pure courier ride that is just the fare.
  v_amount := r.fare;
  IF r.order_id IS NOT NULL THEN
    SELECT total_amount INTO v_order_total FROM public.orders WHERE id = r.order_id;
    v_amount := COALESCE(v_order_total, r.fare);
  ELSIF r.is_ask_anything THEN
    -- 437: an ask-anything ride collects the locked fare plus the approved
    -- goods total (goods are a pass-through, never platform revenue). Fail
    -- closed while shopping is unfinished: no partial amount is shown.
    IF r.courier_shopping_finished AND r.status <> 'cancelled' THEN
      v_amount := COALESCE(r.fare, 0) + COALESCE(r.courier_goods_total, 0);
    ELSE
      -- Unfinished shopping (no partial amount) or an incident-cancelled
      -- ride (settlement goes through the incident report, never the
      -- cash card).
      v_amount := NULL;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'ride_id', r.id,
    'order_id', r.order_id,
    'ride_status', r.status,
    'payment_method', r.payment_method,
    'payment_status', r.payment_status,
    'collected', (r.cash_collected_at IS NOT NULL),
    'amount', v_amount,
    'currency', COALESCE(NULLIF(r.currency, ''), 'EGP')
  );
END;
$function$
$fn$;
  ELSE
    RAISE EXCEPTION '437: driver_cash_collection_state unexpected pre-state md5 % - aborting', v_md5;
  END IF;
END $g$;

REVOKE EXECUTE ON FUNCTION public.driver_cash_collection_state(uuid) FROM PUBLIC, anon;

-- ── confirm_cash_collection ───────────────────────────────────────────
DO $g$
DECLARE
  v_md5 text := (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p
                 JOIN pg_namespace n ON n.oid=p.pronamespace
                 WHERE n.nspname='public' AND p.proname='confirm_cash_collection');
BEGIN
  IF v_md5 = '9bba5a7f0e1411410b0917b16dfeefad' THEN
    EXECUTE $fn$
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
  v_ask boolean;
  v_shopping_finished boolean;
  v_goods numeric;
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

    SELECT status, payment_status, payment_method, driver_id, fare, order_id, cash_collected_at,
           is_ask_anything, courier_shopping_finished, courier_goods_total
      INTO v_status, v_pay_status, v_pay_method, v_driver_id, v_amount, v_order_id, v_stamp,
           v_ask, v_shopping_finished, v_goods
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

    -- 437: an ask-anything ride never has a linked order; it collects the
    -- locked fare plus the approved goods total (goods are a pass-through,
    -- never platform revenue). Fail closed while shopping is unfinished
    -- rather than stamping or auditing a partial amount.
    IF v_order_id IS NULL AND v_ask THEN
      -- An incident-cancelled ride keeps its shopping records, but its
      -- settlement goes through the incident report - never through cash
      -- collection, not even for the owner.
      IF v_status = 'cancelled' THEN
        RETURN jsonb_build_object('ok', false, 'code', 'RIDE_CANCELLED');
      END IF;
      IF NOT v_shopping_finished THEN
        RETURN jsonb_build_object('ok', false, 'code', 'SHOPPING_UNFINISHED');
      END IF;
      v_amount := COALESCE(v_amount, 0) + COALESCE(v_goods, 0);
    END IF;

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
$fn$;
  ELSE
    RAISE EXCEPTION '437: confirm_cash_collection unexpected pre-state md5 % - aborting', v_md5;
  END IF;
END $g$;

REVOKE EXECUTE ON FUNCTION public.confirm_cash_collection(cash_ref_type,uuid) FROM PUBLIC, anon;

COMMIT;

NOTIFY pgrst, 'reload schema';
