-- 392: cash handoff — assigned-driver collection gate.
--
-- Owner decision (2026-11-23): when the captain hands over a cash order he
-- taps "تم التحصيل" in his app; that marks the cash collected. Only then does
-- the customer get the stars+comment rating for that delivery driver.
--
-- What changes:
--   1. confirm_cash_collection authorizes BEFORE any response that reveals
--      whether an id exists or what its payment state is. Unauthorized
--      callers get the same NOT_FOUND a nonexistent id returns — no
--      existence/payment-state oracle, and no idempotent response before
--      authorization.
--   2. The server requires the completed-handoff predicate in BOTH paths:
--      a non-owner caller can collect a commerce order only once it is
--      'delivered' (set by the rides trigger when the recipient-OTP
--      completion lands), and a delivery ride only once it is 'completed'
--      (complete_delivery sets that only after the dropoff OTP verifies).
--      The owner keeps the reconciliation exemption.
--   3. Collection syncs the linked order/ride pair idempotently and NEVER
--      resurrects payment: only cash rows still unpaid/pending are stamped;
--      refunded, failed or non-cash partners are skipped and surfaced as
--      pair_warnings for owner reconciliation. No ledger rows are added —
--      settlement obligations accrue at delivery time via
--      _record_delivery_earnings' ON CONFLICT guards.
--   4. Replays heal: an ALREADY_COLLECTED response still runs the partner
--      sync and the audit postcondition, so a paid source with an
--      uncollected linked target converges instead of staying split.
--   5. collected_by is never invented: healing fills it from the current
--      caller ONLY when the stamp itself is healed in the same call. A row
--      whose stamp exists but whose collected_by is NULL keeps NULL — the
--      historical collector is unknown and stays unknown.
--   6. Audit rule (owner): exactly one CASH_COLLECTED audit_log row per
--      resource, the partner included, and the amount is always what the
--      customer handed over — the order total — on both partners and both
--      endpoints. Skipped partners (refunded/failed/non-cash) are surfaced
--      to the caller as pair_warnings AND to the owner as one admin-visible
--      CASH_PAIR_MISMATCH audit row per reference. A restricted backfill
--      stamps only historical paid cash rows that actually completed the
--      handoff (completed rides from their real completed_at; delivered
--      orders from the linked ride's completed_at), leaving cancelled,
--      incomplete and timestamp-less rows null, and writes system/backfill
--      audit rows for the stamped rows only.
--   7. Both paths take locks in one canonical order — orders first, then
--      rides — so concurrent opposite-reference calls serialize on the
--      order row instead of deadlocking.
--   8. ride_ratings RLS and rate_ride require a completed ride, and a cash
--      ride additionally requires the collection stamp; non-cash rides are
--      unchanged.
--   9. New driver_cash_collection_state RPC feeds the captain app's
--      "تم التحصيل" card (collectable amount, collected flag) without
--      widening rides/orders RLS; its collected flag is the same stamp rule
--      the RLS uses.
--
-- Staging note: prod has never applied any revision of 392, so this file is
-- still the single source of truth for the whole change. Staging received
-- earlier revisions via the Management API query endpoint (which records no
-- schema_migrations row); each revision is re-applied there in full, so
-- staging matches this file. Applying it again through the CLI is safe:
-- every statement is idempotent, and the whole file runs in one
-- transaction.

begin;

CREATE OR REPLACE FUNCTION public._audit_cash_collection(p_resource text, p_resource_id uuid, p_amount numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- Idempotent: one CASH_COLLECTED audit row per resource, however many
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

-- One admin-visible row per mismatched/refunded pair, so reconciliation
-- reaches the owner even though the captain sees plain success. Idempotent
-- per reference: the latest warnings replace the record, not stack up.
CREATE OR REPLACE FUNCTION public._audit_cash_pair_mismatch(p_resource text, p_reference_id uuid, p_warnings jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF p_warnings IS NULL OR jsonb_array_length(p_warnings) = 0 THEN
    RETURN;
  END IF;
  IF EXISTS (SELECT 1 FROM public.audit_log a
              WHERE a.action = 'CASH_PAIR_MISMATCH'
                AND a.resource = p_resource
                AND a.resource_id = p_reference_id::text) THEN
    UPDATE public.audit_log
       SET after = jsonb_build_object('pair_warnings', p_warnings, 'reported_by', auth.uid()),
           created_at = now()
     WHERE action = 'CASH_PAIR_MISMATCH'
       AND resource = p_resource
       AND resource_id = p_reference_id::text;
  ELSE
    INSERT INTO public.audit_log (actor, actor_role, scope, action, resource, resource_id, after, reason)
    VALUES (auth.uid(),
            COALESCE((SELECT u.role FROM public.users u WHERE u.id = auth.uid()), 'unknown'),
            'GLOBAL',
            'CASH_PAIR_MISMATCH',
            p_resource,
            p_reference_id::text,
            jsonb_build_object('pair_warnings', p_warnings, 'reported_by', auth.uid()),
            'cash_handoff_pair_mismatch');
  END IF;
END;
$function$
;

REVOKE ALL ON FUNCTION public._audit_cash_pair_mismatch(text, uuid, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public._audit_cash_pair_mismatch(text, uuid, jsonb) TO postgres;
GRANT EXECUTE ON FUNCTION public._audit_cash_pair_mismatch(text, uuid, jsonb) TO service_role;

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
;

-- Backfill: historical paid cash rows predate the collection stamp. Only
-- rows that actually completed the handoff are stamped — completed rides
-- (from their real completed_at) and delivered orders (from the linked
-- ride's completed_at). Cancelled, incomplete, and timestamp-less rows stay
-- null; a later replay heals them. collected_by stays NULL on backfilled
-- rows: the historical collector is unknown and is not invented. Audit rows
-- are written ONLY for the rows this backfill actually stamps (captured via
-- RETURNING), marked system/backfill, with the collected amount (the order
-- total where one is linked). Rows already stamped — by live pre-392
-- collections or by a re-applied earlier revision — get nothing.
CREATE TEMPORARY TABLE IF NOT EXISTS pg_temp.zz_392_bf_rides(id uuid PRIMARY KEY, amount numeric) ON COMMIT DROP;
CREATE TEMPORARY TABLE IF NOT EXISTS pg_temp.zz_392_bf_orders(id uuid PRIMARY KEY, amount numeric) ON COMMIT DROP;
-- Belt and braces for a re-apply inside one session.
DELETE FROM pg_temp.zz_392_bf_rides;
DELETE FROM pg_temp.zz_392_bf_orders;

WITH stamped AS (
  UPDATE public.rides r
     SET cash_collected_at = r.completed_at
   WHERE r.payment_method = 'cash'
     AND r.payment_status = 'paid'
     AND r.status = 'completed'
     AND r.completed_at IS NOT NULL
     AND r.cash_collected_at IS NULL
   RETURNING r.id, r.fare, r.order_id
)
INSERT INTO pg_temp.zz_392_bf_rides (id, amount)
SELECT s.id, COALESCE(o.total_amount, s.fare)
  FROM stamped s
  LEFT JOIN public.orders o ON o.id = s.order_id;

WITH stamped AS (
  UPDATE public.orders o
     SET cash_collected_at = r.completed_at
    FROM (SELECT order_id, min(completed_at) AS completed_at
            FROM public.rides
           WHERE status = 'completed' AND completed_at IS NOT NULL
           GROUP BY order_id) r
   WHERE r.order_id = o.id
     AND o.payment_method = 'cash'
     AND o.payment_status = 'paid'
     AND o.status = 'delivered'
     AND o.cash_collected_at IS NULL
   RETURNING o.id, o.total_amount
)
INSERT INTO pg_temp.zz_392_bf_orders (id, amount)
SELECT id, total_amount FROM stamped;

-- A stamped row with a pre-existing CASH_COLLECTED audit keeps that row:
-- exactly one audit per resource, however the row got stamped (#94).
INSERT INTO public.audit_log (actor, actor_role, scope, action, resource, resource_id, after, reason)
SELECT NULL, 'system', 'GLOBAL', 'CASH_COLLECTED', 'ride', b.id::text,
       jsonb_build_object('amount', b.amount, 'backfill', true),
       'backfill_392'
  FROM pg_temp.zz_392_bf_rides b
 WHERE NOT EXISTS (SELECT 1 FROM public.audit_log a
                    WHERE a.action = 'CASH_COLLECTED' AND a.resource = 'ride' AND a.resource_id = b.id::text);

INSERT INTO public.audit_log (actor, actor_role, scope, action, resource, resource_id, after, reason)
SELECT NULL, 'system', 'GLOBAL', 'CASH_COLLECTED', 'order', b.id::text,
       jsonb_build_object('amount', b.amount, 'backfill', true),
       'backfill_392'
  FROM pg_temp.zz_392_bf_orders b
 WHERE NOT EXISTS (SELECT 1 FROM public.audit_log a
                    WHERE a.action = 'CASH_COLLECTED' AND a.resource = 'order' AND a.resource_id = b.id::text);

-- A staging-only repair for audit rows written by earlier 392 review
-- revisions lives in supabase/tests/392_staging_audit_repair.sql. It is
-- deliberately NOT part of this migration: prod has no such rows (verified
-- zero on 2026-11-23), and a blind rewrite could destroy legitimate
-- historical evidence (e.g. amounts captured before a refund).

-- Captain app cash card: what to collect on this delivery and whether it is
-- collected already. Assigned driver or owner only — same NOT_FOUND shape
-- for everyone else, so the id space stays opaque. The collected flag is
-- the stamp rule, the same one the rating RLS and the customer UI use.
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
    'collected', (r.cash_collected_at IS NOT NULL),
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

-- Same gate inside the RPC path (SECURITY DEFINER bypasses RLS), plus the
-- completion check the old RPC was missing.
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
;

commit;
