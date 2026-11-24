-- Run after migration 430. Every fixture and resulting row is rolled back.
-- Verifies the closed rides-write paths stay closed and the courier RPC
-- still creates the ride with server-controlled fields.
BEGIN;
-- Rollback-only synthetic fixtures. Never use real user accounts or money.
DO $$
DECLARE
  u uuid := gen_random_uuid();
  v_id uuid;
  v_ride RECORD;
  v_denied boolean;
  a jsonb;
BEGIN
  INSERT INTO auth.users(id, email) VALUES (u, u::text || '@example.invalid');
  INSERT INTO public.users(id, email) VALUES (u, u::text || '@example.invalid') ON CONFLICT (id) DO NOTHING;

  -- Become the synthetic user.
  PERFORM set_config('request.jwt.claim.sub', u::text, true);
  PERFORM set_config('role', 'authenticated', true);

  -- (1) Direct INSERT into rides must be denied.
  v_denied := false;
  BEGIN
    INSERT INTO public.rides (
      rider_id, pickup_latitude, pickup_longitude, pickup_address,
      dropoff_latitude, dropoff_longitude, dropoff_address,
      ride_type, service_type, status, fare
    ) VALUES (
      u, 30.0, 31.0, 'a', 30.1, 31.1, 'b', 'motorcycle', 'courier',
      'searching', 9999
    );
  EXCEPTION WHEN OTHERS THEN
    -- Accept only a real permission/RLS denial; anything else is a bug in
    -- the fixture, not proof the hole is closed.
    v_denied := SQLERRM LIKE '%permission denied%'
                OR SQLERRM LIKE '%row-level security%'
                OR SQLERRM LIKE '%row violates%';
  END;
  IF NOT v_denied THEN
    RAISE EXCEPTION 'authenticated caller can still INSERT into rides';
  END IF;

  -- (2) request_courier_delivery creates the ride with server-controlled
  -- fields: caller cannot set fare, payment, order_id or merchant_id.
  a := public.request_courier_delivery(
    30.0, 31.0, 'pickup',
    30.1, 31.1, 'dropoff',
    'documents x1', 'call on arrival', 'standard'
  );
  IF NOT COALESCE((a->>'ok')::boolean, false) THEN
    RAISE EXCEPTION 'request_courier_delivery rejected a valid request: %', a;
  END IF;
  v_id := (a->>'delivery_id')::uuid;

  SELECT * INTO v_ride FROM public.rides WHERE id = v_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'request_courier_delivery returned ok without a row';
  END IF;
  IF v_ride.rider_id IS DISTINCT FROM u THEN
    RAISE EXCEPTION 'rider_id is not the caller';
  END IF;
  IF v_ride.service_type IS DISTINCT FROM 'courier'
     OR v_ride.fare IS NOT NULL
     OR v_ride.order_id IS NOT NULL
     OR v_ride.merchant_id IS NOT NULL THEN
    RAISE EXCEPTION 'courier ride fields not server-controlled: %', v_ride;
  END IF;

  -- (3) The RPC rejects bad input and bad priority.
  a := public.request_courier_delivery(
    NULL, 31.0, 'pickup', 30.1, 31.1, 'dropoff', 'x', NULL, 'standard'
  );
  IF COALESCE((a->>'ok')::boolean, false) THEN
    RAISE EXCEPTION 'request_courier_delivery accepted NULL coordinates';
  END IF;
  a := public.request_courier_delivery(
    30.0, 31.0, 'pickup', 30.1, 31.1, 'dropoff', 'x', NULL, 'surge-me'
  );
  IF COALESCE((a->>'ok')::boolean, false) THEN
    RAISE EXCEPTION 'request_courier_delivery accepted an unknown priority';
  END IF;

  -- (4) The RPC is not executable by anon.
  PERFORM set_config('role', 'anon', true);
  v_denied := false;
  BEGIN
    PERFORM public.request_courier_delivery(
      30.0, 31.0, 'pickup', 30.1, 31.1, 'dropoff', 'x', NULL, 'standard'
    );
  EXCEPTION WHEN insufficient_privilege THEN
    v_denied := true;
  WHEN OTHERS THEN
    v_denied := SQLERRM LIKE '%permission%' OR SQLERRM LIKE '%denied%';
  END;
  IF NOT v_denied THEN
    RAISE EXCEPTION 'anon can execute request_courier_delivery';
  END IF;
END $$;
ROLLBACK;
