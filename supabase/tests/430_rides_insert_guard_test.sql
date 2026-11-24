-- Run after migration 430. Every fixture and resulting row is rolled back.
-- Verifies the closed rides-write paths stay closed and the courier RPC
-- still creates the ride with server-controlled fields.
BEGIN;
-- Rollback-only synthetic fixtures. Never use real user accounts or money.
DO $$
DECLARE
  u uuid := gen_random_uuid();
  other uuid := gen_random_uuid();
  adm uuid := gen_random_uuid();
  v_id uuid;
  v_ride RECORD;
  v_denied boolean;
  a jsonb;
BEGIN
  INSERT INTO auth.users(id, email) VALUES
    (u, u::text || '@example.invalid'),
    (other, other::text || '@example.invalid'),
    (adm, adm::text || '@example.invalid');
  INSERT INTO public.users(id, email, role) VALUES
    (u, u::text || '@example.invalid', 'customer'),
    (other, other::text || '@example.invalid', 'customer'),
    (adm, adm::text || '@example.invalid', 'owner')
  ON CONFLICT (id) DO NOTHING;

  -- Seed one searching ride for u directly (as the migration role).
  INSERT INTO public.rides (
    rider_id, pickup_latitude, pickup_longitude, pickup_address,
    dropoff_latitude, dropoff_longitude, dropoff_address,
    ride_type, service_type, status
  ) VALUES (
    u, 30.0, 31.0, 'a', 30.1, 31.1, 'b', 'motorcycle', 'courier', 'searching'
  ) RETURNING id INTO v_id;

  -- Become the synthetic rider.
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

  -- (2) Rider UPDATE on their own ride must affect zero rows (no rider
  -- UPDATE policy remains) and must not change the row.
  UPDATE public.rides SET fare = 9999 WHERE id = v_id;
  SELECT * INTO v_ride FROM public.rides WHERE id = v_id;
  IF v_ride.fare IS NOT NULL THEN
    RAISE EXCEPTION 'rider UPDATE mutated their own ride';
  END IF;

  -- (3) Rider UPDATE on a foreign ride: same zero-row guarantee.
  UPDATE public.rides SET fare = 9999 WHERE rider_id = other;

  -- (4) Zero-row UPDATE must be a silent no-op, not an error.
  UPDATE public.rides SET fare = 1 WHERE id = gen_random_uuid();

  -- (5) An active admin keeps the UPDATE path the admin app uses.
  PERFORM set_config('request.jwt.claim.sub', adm::text, true);
  UPDATE public.rides SET status = 'cancelled', cancellation_reason = 'test'
   WHERE id = v_id;
  SELECT * INTO v_ride FROM public.rides WHERE id = v_id;
  IF v_ride.status IS DISTINCT FROM 'cancelled' THEN
    RAISE EXCEPTION 'admin UPDATE path broke';
  END IF;

  -- (6) request_courier_delivery creates the ride with server-controlled
  -- fields: caller cannot set fare, payment, order_id or merchant_id.
  PERFORM set_config('request.jwt.claim.sub', u::text, true);
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

  -- (7) Input bounds: bad coordinates, blank address, oversize text and
  -- unknown priority are all rejected.
  a := public.request_courier_delivery(
    NULL, 31.0, 'pickup', 30.1, 31.1, 'dropoff', 'x', NULL, 'standard'
  );
  IF COALESCE((a->>'ok')::boolean, false) THEN
    RAISE EXCEPTION 'request_courier_delivery accepted NULL coordinates';
  END IF;
  a := public.request_courier_delivery(
    91.0, 31.0, 'pickup', 30.1, 31.1, 'dropoff', 'x', NULL, 'standard'
  );
  IF COALESCE((a->>'ok')::boolean, false) THEN
    RAISE EXCEPTION 'request_courier_delivery accepted out-of-range latitude';
  END IF;
  a := public.request_courier_delivery(
    30.0, 31.0, 'pickup', 30.1, 31.1, '   ', 'x', NULL, 'standard'
  );
  IF COALESCE((a->>'ok')::boolean, false) THEN
    RAISE EXCEPTION 'request_courier_delivery accepted a blank address';
  END IF;
  a := public.request_courier_delivery(
    30.0, 31.0, 'pickup', 30.1, 31.1, 'dropoff', repeat('x', 501), NULL,
    'standard'
  );
  IF COALESCE((a->>'ok')::boolean, false) THEN
    RAISE EXCEPTION 'request_courier_delivery accepted oversize items text';
  END IF;
  a := public.request_courier_delivery(
    30.0, 31.0, 'pickup', 30.1, 31.1, 'dropoff', 'x', NULL, 'surge-me'
  );
  IF COALESCE((a->>'ok')::boolean, false) THEN
    RAISE EXCEPTION 'request_courier_delivery accepted an unknown priority';
  END IF;

  -- (8) The abuse cap refuses a sixth open searching ride.
  RESET role;
  INSERT INTO public.rides (
    rider_id, pickup_latitude, pickup_longitude, pickup_address,
    dropoff_latitude, dropoff_longitude, dropoff_address,
    ride_type, service_type, status
  )
  SELECT u, 30.0, 31.0, 'a', 30.1, 31.1, 'b', 'motorcycle', 'courier',
         'searching'
    FROM generate_series(1, 4);
  PERFORM set_config('role', 'authenticated', true);
  a := public.request_courier_delivery(
    30.0, 31.0, 'pickup', 30.1, 31.1, 'dropoff', 'x', NULL, 'standard'
  );
  IF COALESCE((a->>'ok')::boolean, false)
     OR a->>'reason' IS DISTINCT FROM 'TOO_MANY_OPEN_RIDES' THEN
    RAISE EXCEPTION 'open-ride cap not enforced: %', a;
  END IF;

  -- (9) The RPC is not executable by anon.
  PERFORM set_config('role', 'anon', true);
  v_denied := false;
  BEGIN
    PERFORM public.request_courier_delivery(
      30.0, 31.0, 'pickup', 30.1, 31.1, 'dropoff', 'x', NULL, 'standard'
    );
  EXCEPTION WHEN OTHERS THEN
    v_denied := SQLERRM LIKE '%permission denied%'
                OR SQLERRM LIKE '%insufficient%';
  END;
  IF NOT v_denied THEN
    RAISE EXCEPTION 'anon can execute request_courier_delivery';
  END IF;
END $$;
ROLLBACK;
