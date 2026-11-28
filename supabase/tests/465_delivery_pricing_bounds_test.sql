-- Run after migration 465. Synthetic fixtures only, everything rolled back.
-- delivery_pricing rejects out-of-range values at the database, updated_at is
-- set by the server, and a zero fare fails closed as PRICING_UNAVAILABLE.
BEGIN;
DO $$
DECLARE
  u uuid := gen_random_uuid();
  a jsonb;
  v_before timestamptz;
  v_after timestamptz;
  v_rides int;
  v_ok boolean;
BEGIN
  INSERT INTO auth.users(id, email) VALUES (u, u::text || '@example.invalid');
  INSERT INTO public.users(id, email, role)
    VALUES (u, u::text || '@example.invalid', 'customer')
  ON CONFLICT (id) DO NOTHING;
  DELETE FROM public.delivery_pricing WHERE service_type IN ('courier', 'marketplace_delivery');
  INSERT INTO public.delivery_pricing(service_type, base_fee, per_km, per_kg,
    minimum_fee, priority_multiplier, express_multiplier, currency, is_active)
  VALUES ('courier', 15, 5, 2, 20, 1.2, 1.5, 'EGP', true),
         ('marketplace_delivery', 12, 4, 1.5, 18, 1.3, 1.8, 'EGP', true);

  -- (1) each bound is enforced, nothing is stored
  v_ok := true;
  BEGIN UPDATE public.delivery_pricing SET base_fee = -1 WHERE service_type = 'courier'; v_ok := false;
  EXCEPTION WHEN check_violation THEN NULL; END;
  ASSERT v_ok, '465 1a: negative base_fee accepted';
  BEGIN UPDATE public.delivery_pricing SET base_fee = 501 WHERE service_type = 'courier'; v_ok := false;
  EXCEPTION WHEN check_violation THEN NULL; END;
  ASSERT v_ok, '465 1b: base_fee above 500 accepted';
  BEGIN UPDATE public.delivery_pricing SET per_km = 51 WHERE service_type = 'courier'; v_ok := false;
  EXCEPTION WHEN check_violation THEN NULL; END;
  ASSERT v_ok, '465 1c: per_km above 50 accepted';
  BEGIN UPDATE public.delivery_pricing SET per_kg = -0.5 WHERE service_type = 'courier'; v_ok := false;
  EXCEPTION WHEN check_violation THEN NULL; END;
  ASSERT v_ok, '465 1d: negative per_kg accepted';
  BEGIN UPDATE public.delivery_pricing SET minimum_fee = -5 WHERE service_type = 'courier'; v_ok := false;
  EXCEPTION WHEN check_violation THEN NULL; END;
  ASSERT v_ok, '465 1e: negative minimum_fee accepted';
  BEGIN UPDATE public.delivery_pricing SET express_multiplier = 3.5 WHERE service_type = 'courier'; v_ok := false;
  EXCEPTION WHEN check_violation THEN NULL; END;
  ASSERT v_ok, '465 1f: multiplier above 3 accepted';
  BEGIN UPDATE public.delivery_pricing SET priority_multiplier = 0.5 WHERE service_type = 'courier'; v_ok := false;
  EXCEPTION WHEN check_violation THEN NULL; END;
  ASSERT v_ok, '465 1g: multiplier below 1 accepted';
  ASSERT (SELECT base_fee FROM public.delivery_pricing WHERE service_type = 'courier') = 15, '465 1h: row unchanged';

  -- (2) the caps themselves are allowed; updated_at moves on the server
  SELECT updated_at INTO v_before FROM public.delivery_pricing WHERE service_type = 'courier';
  PERFORM pg_sleep(0.01);
  UPDATE public.delivery_pricing SET base_fee = 500, per_km = 50, per_kg = 50,
    minimum_fee = 500, priority_multiplier = 3, express_multiplier = 3
   WHERE service_type = 'courier';
  SELECT updated_at INTO v_after FROM public.delivery_pricing WHERE service_type = 'courier';
  ASSERT v_after IS NOT NULL AND (v_before IS NULL OR v_after > v_before), '465 2: updated_at not touched';
  UPDATE public.delivery_pricing SET base_fee = 15, per_km = 5, per_kg = 2,
    minimum_fee = 20, priority_multiplier = 1.2, express_multiplier = 1.5
   WHERE service_type = 'courier';

  PERFORM set_config('request.jwt.claim.sub', u::text, true);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u)::text, true);
  PERFORM set_config('role', 'authenticated', true);

  -- (3) normal pricing still works
  a := public.request_courier_delivery(30.0, 31.0, 'p', 30.1, 31.1, 'd', 'x', NULL, 'standard');
  ASSERT (a->>'ok')::boolean AND (a->>'fare')::numeric > 0, '465 3a: ' || a::text;
  a := public.request_delivery(30.0, 31.0, 'p', 30.1, 31.1, 'd', 'x');
  ASSERT (a->>'ok')::boolean, '465 3b: ' || a::text;

  -- (4) an all-zero row (allowed by the bounds) fails closed, no ride
  PERFORM set_config('role', 'none', true);
  UPDATE public.delivery_pricing SET base_fee = 0, per_km = 0, per_kg = 0, minimum_fee = 0
   WHERE service_type IN ('courier', 'marketplace_delivery');
  SELECT count(*) INTO v_rides FROM public.rides WHERE rider_id = u;
  PERFORM set_config('role', 'authenticated', true);
  a := public.request_courier_delivery(30.0, 31.0, 'p', 30.1, 31.1, 'd', 'x', NULL, 'standard');
  ASSERT a->>'reason' = 'PRICING_UNAVAILABLE' AND NOT (a->>'ok')::boolean, '465 4a: ' || a::text;
  a := public.request_delivery(30.0, 31.0, 'p', 30.1, 31.1, 'd', 'x');
  ASSERT a->>'reason' = 'PRICING_UNAVAILABLE' AND NOT (a->>'ok')::boolean, '465 4b: ' || a::text;
  PERFORM set_config('role', 'none', true);
  ASSERT (SELECT count(*) FROM public.rides WHERE rider_id = u) = v_rides, '465 4c: ride written at zero fare';
  RAISE NOTICE '465 delivery pricing bounds: all assertions passed';
END $$;
ROLLBACK;
