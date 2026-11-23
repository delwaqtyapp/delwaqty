-- 423 actual-role staging run (transaction-wrapped, fixtures rolled back).
-- Serial functional matrix with the real authenticated role; the unique
-- partial index is proven as the concurrency backstop by a direct second
-- pending insert (the window a racer would have to win) failing with a
-- unique violation.
BEGIN;
DO $$
DECLARE
  u1 uuid := gen_random_uuid(); u2 uuid := gen_random_uuid(); u3 uuid := gen_random_uuid();
  d1 uuid := gen_random_uuid(); d2 uuid := gen_random_uuid(); d3 uuid := gen_random_uuid();
  v_r jsonb; v_id uuid; v_n integer;
BEGIN
  -- fixtures
  INSERT INTO auth.users(id,email) SELECT g, g::text||'@x.i' FROM unnest(ARRAY[u1,u2,u3]) g;
  INSERT INTO public.users(id,email,role)
    SELECT g, g::text||'@x.i', 'driver' FROM unnest(ARRAY[u1,u2,u3]) g
    ON CONFLICT(id) DO UPDATE SET role = EXCLUDED.role;
  INSERT INTO public.drivers(id,user_id,full_name,status,is_verified,is_active,accepts_deliveries,service_types,max_delivery_distance_km,max_weight_kg)
    SELECT d, u, '423 ' || d::text, 'approved', true, true, true,
           ARRAY['parcel']::text[], 15, 20
    FROM (VALUES (d1,u1),(d2,u2),(d3,u3)) AS v(d,u);
  INSERT INTO public.driver_earnings(driver_id,type,amount,description) VALUES
    (d1,'trip',500,'423 fixture'),(d2,'trip',200,'423 fixture'),(d3,'trip',100,'423 fixture');

  -- unauthenticated
  PERFORM set_config('role','authenticated',true);
  PERFORM set_config('request.jwt.claim.sub','',true);
  v_r := public.request_withdrawal(d1, 100);
  ASSERT v_r->>'reason' = 'unauthenticated', '423: unauthenticated not refused';

  -- U1/D1: keyed request, duplicate retry, conflict, blank/oversize key,
  -- pending-exists, backstop unique index
  PERFORM set_config('request.jwt.claim.sub', u1::text, true);
  v_r := public.request_withdrawal(d1, 100, 'bank', '423-K1');
  ASSERT (v_r->>'success')::boolean, '423: first request failed: ' || v_r::text;
  v_id := (v_r->>'withdrawal_id')::uuid;
  v_r := public.request_withdrawal(d1, 100, 'bank', '423-K1');
  ASSERT (v_r->>'success')::boolean AND (v_r->>'duplicate')::boolean AND (v_r->>'withdrawal_id')::uuid = v_id,
    '423: idempotent retry not returned as duplicate';
  ASSERT (SELECT count(*) FROM public.withdrawal_requests WHERE driver_id=d1) = 1,
    '423: duplicate retry inserted a second row';
  ASSERT (SELECT count(*) FROM public.driver_earnings WHERE driver_id=d1 AND type='withdrawal') = 1,
    '423: duplicate retry deducted earnings twice';
  v_r := public.request_withdrawal(d1, 150, 'bank', '423-K1');
  ASSERT v_r->>'reason' = 'idempotency_conflict', '423: key+amount conflict not detected';
  v_r := public.request_withdrawal(d1, 100, 'bank', '   ');
  ASSERT v_r->>'reason' = 'invalid_idempotency_key', '423: blank key accepted';
  v_r := public.request_withdrawal(d1, 100, 'bank', repeat('k',129));
  ASSERT v_r->>'reason' = 'invalid_idempotency_key', '423: oversize key accepted';
  v_r := public.request_withdrawal(d1, 60);
  ASSERT v_r->>'reason' = 'pending_exists', '423: second pending allowed';
  -- backstop: a racer slipping past the check hits the unique index
  -- (run as the table owner: RLS rightly blocks direct client inserts
  -- before the index, so prove the index itself as the owner role)
  PERFORM set_config('role','none',true);
  BEGIN
    INSERT INTO public.withdrawal_requests (driver_id, amount, status, method)
    VALUES (d1, 10, 'pending', 'bank');
    ASSERT false, '423: direct second pending insert not blocked by unique index';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
  PERFORM set_config('role','authenticated',true);
  PERFORM set_config('request.jwt.claim.sub', u1::text, true);

  -- U2: foreign driver refused; unknown driver; balance/amount guards
  PERFORM set_config('request.jwt.claim.sub', u2::text, true);
  v_r := public.request_withdrawal(d1, 50);
  ASSERT v_r->>'reason' = 'forbidden', '423: foreign driver not refused';
  v_r := public.request_withdrawal(gen_random_uuid(), 50);
  ASSERT v_r->>'reason' = 'driver_not_found', '423: unknown driver not refused';
  v_r := public.request_withdrawal(d2, 100000);
  ASSERT v_r->>'reason' = 'insufficient_balance', '423: over-balance not refused';
  v_r := public.request_withdrawal(d2, -5);
  ASSERT v_r->>'reason' = 'insufficient_balance', '423: negative amount not refused';

  -- 3-arg compat: old positional call (no method, no key) still works
  v_r := public.request_withdrawal(d2, 50);
  ASSERT (v_r->>'success')::boolean, '423: 3-arg compat call failed: ' || v_r::text;

  -- U3/D3: unkeyed request works while D1 has a pending one (per-driver scope)
  PERFORM set_config('request.jwt.claim.sub', u3::text, true);
  v_r := public.request_withdrawal(d3, 40, 'wallet');
  ASSERT (v_r->>'success')::boolean, '423: unkeyed request on other driver failed: ' || v_r::text;

  -- catalog assertion: exactly the 4-arg form exists, key defaulted
  ASSERT (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
          WHERE n.nspname='public' AND p.proname='request_withdrawal') = 1,
    '423: expected exactly one request_withdrawal';
  ASSERT (SELECT p.pronargs FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
          WHERE n.nspname='public' AND p.proname='request_withdrawal') = 4,
    '423: expected 4-arg form';
  ASSERT (SELECT p.pronargdefaults FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
          WHERE n.nspname='public' AND p.proname='request_withdrawal') = 2,
    '423: expected method+key defaulted';

  PERFORM set_config('role','none',true);
END $$;
ROLLBACK;
