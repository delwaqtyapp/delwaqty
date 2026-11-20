-- Run after migration 151. Every fixture and resulting row is rolled back.
-- Verifies: customers cannot rewrite their orders, merchants cannot mark
-- delivered directly but can via merchant_complete_order (which records the
-- commission idempotently), and rides reject client-side tampering.
BEGIN;
DO $$
DECLARE
  c uuid := gen_random_uuid();      -- customer
  mo uuid := gen_random_uuid();     -- merchant owner
  m uuid := gen_random_uuid();      -- merchant
  o uuid := gen_random_uuid();      -- order
  r uuid := gen_random_uuid();      -- ride
  v_blocked boolean;
  v_res jsonb;
  v_ride rides%ROWTYPE;
BEGIN
  INSERT INTO auth.users(id,email) VALUES
    (c,c::text||'@example.invalid'),(mo,mo::text||'@example.invalid');
  INSERT INTO public.users(id,email) VALUES
    (c,c::text||'@example.invalid'),(mo,mo::text||'@example.invalid')
    ON CONFLICT(id) DO NOTHING;
  INSERT INTO public.merchants(id, owner_user_id, name)
    VALUES (m, mo, 'Lockdown Fixture');
  INSERT INTO public.orders(id, user_id, merchant_id, status, subtotal, total_amount)
    VALUES (o, c, m, 'ready', 100, 120);

  -- ── customer tampering ──
  PERFORM set_config('request.jwt.claim.sub', c::text, true);
  PERFORM set_config('role','authenticated',true);

  v_blocked := false;
  BEGIN
    UPDATE public.orders SET payment_status = 'paid' WHERE id = o;
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'customer marked own order paid'; END IF;

  v_blocked := false;
  BEGIN
    UPDATE public.orders SET status = 'delivered' WHERE id = o;
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'customer marked own order delivered'; END IF;

  v_blocked := false;
  BEGIN
    UPDATE public.orders SET total_amount = 1 WHERE id = o;
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'customer rewrote order total'; END IF;

  -- harmless field still editable
  UPDATE public.orders SET notes = 'please call on arrival' WHERE id = o;

  -- ── merchant boundaries ──
  PERFORM set_config('role','none',true);
  PERFORM set_config('request.jwt.claim.sub', mo::text, true);
  PERFORM set_config('role','authenticated',true);

  UPDATE public.orders SET status = 'preparing' WHERE id = o;
  UPDATE public.orders SET status = 'ready' WHERE id = o;

  v_blocked := false;
  BEGIN
    UPDATE public.orders SET status = 'delivered' WHERE id = o;
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'merchant marked delivered directly'; END IF;

  v_blocked := false;
  BEGIN
    UPDATE public.orders SET subtotal = 1 WHERE id = o;
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'merchant rewrote subtotal'; END IF;

  -- the sanctioned completion path records the commission
  SELECT public.merchant_complete_order(o) INTO v_res;
  IF NOT (v_res->>'ok')::boolean THEN
    RAISE EXCEPTION 'merchant_complete_order refused: %', v_res;
  END IF;
  IF (SELECT status FROM public.orders WHERE id = o) <> 'delivered' THEN
    RAISE EXCEPTION 'order not delivered after RPC';
  END IF;
  -- idempotent
  SELECT public.merchant_complete_order(o) INTO v_res;
  IF v_res->>'reason' <> 'ALREADY_DONE' THEN
    RAISE EXCEPTION 'second completion not refused: %', v_res;
  END IF;

  -- ── rides tampering ──
  PERFORM set_config('role','none',true);
  IF NOT EXISTS (
    SELECT 1 FROM public.platform_commissions
    WHERE reference_type='order' AND reference_id=o
      AND gross_amount=100 AND commission_amount=3.00 AND net_amount=97.00
  ) THEN
    RAISE EXCEPTION 'commission row missing or wrong amounts';
  END IF;
  PERFORM set_config('request.jwt.claim.sub', c::text, true);
  PERFORM set_config('role','authenticated',true);

  INSERT INTO public.rides(id, rider_id, status, payment_status, fare,
      pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude)
    VALUES (r, c, 'completed', 'paid', 0, 30.0, 31.0, 30.1, 31.1)
    RETURNING * INTO v_ride;
  IF v_ride.payment_status <> 'pending' OR v_ride.status <> 'searching' THEN
    RAISE EXCEPTION 'ride insert kept client-supplied payment/status';
  END IF;

  v_blocked := false;
  BEGIN
    UPDATE public.rides SET fare = 0 WHERE id = r;
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'rider rewrote ride fare'; END IF;

  v_blocked := false;
  BEGIN
    UPDATE public.rides SET payment_status = 'paid' WHERE id = r;
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'rider marked ride paid'; END IF;

  PERFORM set_config('role','none',true);
END;
$$;
ROLLBACK;
