-- 392: cash handoff — assigned-driver collection gate.
--
-- Owner decision (2026-11-23): when the captain hands over a cash order he
-- taps "تم التحصيل" in his app; that marks the cash collected. Only then does
-- the customer get the stars+comment rating for that delivery driver.
--
-- What changes:
--   1. confirm_cash_collection authorizes BEFORE any response that reveals
--      whether an id exists or what its payment state is. The old order of
--      checks returned ALREADY_COLLECTED to any signed-in user, which made
--      order/ride ids a payment-state oracle. Unauthorized callers now get
--      the same NOT_FOUND a nonexistent id returns.
--   2. Collection syncs the linked order/ride pair: confirming on a
--      commerce order marks its delivery rides paid, and confirming on a
--      delivery ride marks the linked order paid. Both directions are
--      idempotent and add no ledger rows — settlement obligations were
--      already accrued at delivery time by _record_delivery_earnings with
--      ON CONFLICT guards, so this function only stamps payment state.
--   3. Every successful collection writes exactly one audit_log row
--      (action CASH_COLLECTED) per reference; replays do not duplicate it.
--   4. ride_ratings RLS and rate_ride now require a cash ride to be
--      collected before a participant can rate it; non-cash rides are
--      unchanged.
--   5. New driver_cash_collection_state RPC feeds the captain app's
--      "تم التحصيل" card (collectable amount, collected flag) without
--      widening rides/orders RLS.

CREATE OR REPLACE FUNCTION public._audit_cash_collection(p_resource text, p_resource_id uuid, p_amount numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- Idempotent: one CASH_COLLECTED audit row per reference, however many
  -- times the confirmation is replayed (double tap, retry, order+ride pair).
  INSERT INTO public.audit_log (actor, actor_role, scope, action, resource, resource_id, after)
  SELECT auth.uid(),
         COALESCE((SELECT u.role FROM public.users u WHERE u.id = auth.uid()), 'unknown'),
         'GLOBAL',
         'CASH_COLLECTED',
         p_resource,
         p_resource_id::text,
         jsonb_build_object('amount', p_amount, 'collected_by', auth.uid())
  WHERE NOT EXISTS (
    SELECT 1 FROM public.audit_log a
     WHERE a.action = 'CASH_COLLECTED'
       AND a.resource = p_resource
       AND a.resource_id = p_resource_id::text
  );
END;
$function$
;

REVOKE ALL ON FUNCTION public._audit_cash_collection(text, uuid, numeric) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public._audit_cash_collection(text, uuid, numeric) TO postgres;
GRANT EXECUTE ON FUNCTION public._audit_cash_collection(text, uuid, numeric) TO service_role;

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
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED');
  END IF;
  IF p_reference_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_REFERENCE');
  END IF;

  v_is_owner := public._is_owner_uid(v_uid);

  -- ── ORDER (commerce) ────────────────────────────────────────────
  IF p_reference_type = 'order'::public.cash_ref_type THEN
    SELECT status, payment_status, payment_method, driver_id, total_amount
      INTO v_status, v_pay_status, v_pay_method, v_driver_id, v_amount
      FROM public.orders
     WHERE id = p_reference_id
     FOR UPDATE;

    -- Authorization FIRST: only the owner or the physically assigned driver
    -- may learn anything about this id. Everyone else gets the same
    -- NOT_FOUND a nonexistent id returns — no existence or payment-state
    -- oracle, and no idempotent response before authorization.
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

    IF v_pay_status = 'paid' THEN
      RETURN jsonb_build_object('ok', true, 'code', 'ALREADY_COLLECTED', 'reference_id', p_reference_id, 'amount', v_amount);
    END IF;
    IF v_pay_status NOT IN ('unpaid', 'pending') THEN
      RETURN jsonb_build_object('ok', false, 'code', 'INVALID_STATUS', 'current_status', v_pay_status);
    END IF;
    IF v_pay_method <> 'cash' THEN
      RETURN jsonb_build_object('ok', false, 'code', 'NOT_CASH');
    END IF;

    IF NOT v_is_owner AND v_status NOT IN ('delivering', 'delivered') THEN
      RETURN jsonb_build_object('ok', false, 'code', 'INVALID_LIFECYCLE', 'current_status', v_status);
    END IF;

    UPDATE public.orders
       SET payment_status = 'paid',
           cash_collected_at = now(),
           cash_collected_by = v_uid,
           updated_at = now()
     WHERE id = p_reference_id;

    -- Sync the linked delivery rides (idempotent; cancelled rides untouched).
    UPDATE public.rides
       SET payment_status = 'paid',
           cash_collected_at = COALESCE(cash_collected_at, now()),
           cash_collected_by = COALESCE(cash_collected_by, v_uid)
     WHERE order_id = p_reference_id
       AND status <> 'cancelled'
       AND payment_status IS DISTINCT FROM 'paid';

    PERFORM public._audit_cash_collection('order', p_reference_id, v_amount);
    RETURN jsonb_build_object('ok', true, 'code', 'COLLECTED', 'reference_id', p_reference_id, 'amount', v_amount);
  END IF;

  -- ── RIDE (direct delivery) ──────────────────────────────────────
  IF p_reference_type = 'ride'::public.cash_ref_type THEN
    SELECT status, payment_status, payment_method, driver_id, fare, order_id
      INTO v_status, v_pay_status, v_pay_method, v_driver_id, v_amount, v_order_id
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
    IF v_order_id IS NOT NULL THEN
      SELECT total_amount INTO v_linked_amount FROM public.orders WHERE id = v_order_id;
      v_amount := COALESCE(v_linked_amount, v_amount);
    END IF;

    IF v_pay_status = 'paid' THEN
      RETURN jsonb_build_object('ok', true, 'code', 'ALREADY_COLLECTED', 'reference_id', p_reference_id, 'amount', v_amount);
    END IF;
    IF v_pay_status NOT IN ('pending', 'unpaid') THEN
      RETURN jsonb_build_object('ok', false, 'code', 'INVALID_STATUS', 'current_status', v_pay_status);
    END IF;
    IF v_pay_method <> 'cash' THEN
      RETURN jsonb_build_object('ok', false, 'code', 'NOT_CASH');
    END IF;
    IF NOT v_is_owner AND v_status <> 'completed' THEN
      RETURN jsonb_build_object('ok', false, 'code', 'INVALID_LIFECYCLE', 'current_status', v_status);
    END IF;

    UPDATE public.rides
       SET payment_status = 'paid',
           cash_collected_at = now(),
           cash_collected_by = v_uid
     WHERE id = p_reference_id;

    -- Sync the linked commerce order (idempotent).
    IF v_order_id IS NOT NULL THEN
      UPDATE public.orders
         SET payment_status = 'paid',
             cash_collected_at = COALESCE(cash_collected_at, now()),
             cash_collected_by = COALESCE(cash_collected_by, v_uid),
             updated_at = now()
       WHERE id = v_order_id
         AND status <> 'cancelled'
         AND payment_status IS DISTINCT FROM 'paid';
    END IF;

    PERFORM public._audit_cash_collection('ride', p_reference_id, v_amount);
    RETURN jsonb_build_object('ok', true, 'code', 'COLLECTED', 'reference_id', p_reference_id, 'amount', v_amount);
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

    IF v_pay_status = 'paid' THEN
      RETURN jsonb_build_object('ok', true, 'code', 'ALREADY_COLLECTED', 'reference_id', p_reference_id);
    END IF;
    IF v_pay_method <> 'cash' THEN
      RETURN jsonb_build_object('ok', false, 'code', 'NOT_CASH');
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
;

-- Captain app cash card: what to collect on this delivery and whether it is
-- collected already. Assigned driver or owner only — same NOT_FOUND shape
-- for everyone else, so the id space stays opaque.
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
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'ride_id', r.id,
    'order_id', r.order_id,
    'ride_status', r.status,
    'payment_method', r.payment_method,
    'payment_status', r.payment_status,
    'collected', (r.payment_status = 'paid' OR r.cash_collected_at IS NOT NULL),
    'amount', v_amount,
    'currency', COALESCE(NULLIF(r.currency, ''), 'EGP')
  );
END;
$function$
;

REVOKE ALL ON FUNCTION public.driver_cash_collection_state(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.driver_cash_collection_state(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.driver_cash_collection_state(uuid) TO postgres;
GRANT EXECUTE ON FUNCTION public.driver_cash_collection_state(uuid) TO service_role;

-- Ratings wait for collection on cash rides: the customer rates the driver
-- only after the captain tapped "تم التحصيل". Non-cash rides unchanged.
DROP POLICY "ratings rater rw" ON public.ride_ratings;
CREATE POLICY "ratings rater rw" ON public.ride_ratings AS PERMISSIVE FOR ALL TO authenticated USING ((rater_id = auth.uid())) WITH CHECK (((rater_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM rides r
  WHERE ((r.id = ride_ratings.ride_id) AND ((r.rider_id = auth.uid()) OR (r.driver_id = ( SELECT d.id
           FROM drivers d
          WHERE (d.user_id = auth.uid())))) AND (r.status = 'completed'::text) AND ((r.payment_method IS DISTINCT FROM 'cash'::text) OR (r.cash_collected_at IS NOT NULL)))))));

-- Same gate inside the RPC path (SECURITY DEFINER bypasses RLS).
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
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'UNAUTHENTICATED');
  END IF;
  IF p_rating < 1 OR p_rating > 5 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_RATING');
  END IF;
  SELECT fare, payment_method, cash_collected_at
    INTO v_fare, v_pay_method, v_collected_at
    FROM public.rides WHERE id = p_ride_id AND rider_id = v_uid FOR UPDATE;
  IF v_fare IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_YOUR_RIDE');
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
;
