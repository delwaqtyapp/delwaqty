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
  -- #132: keyed retry with a NULL amount must fail validation, not replay
  v_r := public.request_withdrawal(d1, NULL, 'bank', '423-K1');
  ASSERT v_r->>'reason' = 'invalid_amount', '423: NULL-amount keyed retry bypassed validation';
  -- #132: sub-cent precision rejected (stored column is numeric(10,2))
  v_r := public.request_withdrawal(d1, 10.123, 'bank', '423-KF');
  ASSERT v_r->>'reason' = 'invalid_amount', '423: sub-cent amount not rejected';
  -- #132: nonfinite and zero amounts rejected before anything else
  v_r := public.request_withdrawal(d1, 'Infinity'::float8, 'bank', '423-KI');
  ASSERT v_r->>'reason' = 'invalid_amount', '423: Infinity amount not rejected';
  v_r := public.request_withdrawal(d1, 'NaN'::float8, 'bank', '423-KN');
  ASSERT v_r->>'reason' = 'invalid_amount', '423: NaN amount not rejected';
  v_r := public.request_withdrawal(d1, 0, 'bank', '423-KZ');
  ASSERT v_r->>'reason' = 'invalid_amount', '423: zero amount not rejected';
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
  ASSERT v_r->>'reason' = 'invalid_amount', '423: negative amount not refused';

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

  -- #131: ACL proof. No PUBLIC/anon execute; intended roles only.
  -- PUBLIC is not a real role for has_function_privilege on this build;
  -- its grant shows up as an empty-grantee aclitem (=X/grantor) instead.
  ASSERT NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname='request_withdrawal'
      AND p.proacl::text ~ '(^|[{,])=X/'),
    '423: PUBLIC still has EXECUTE';
  ASSERT NOT has_function_privilege('anon',
    'public.request_withdrawal(uuid,double precision,text,text)', 'EXECUTE'),
    '423: anon still has EXECUTE';
  ASSERT has_function_privilege('authenticated',
    'public.request_withdrawal(uuid,double precision,text,text)', 'EXECUTE'),
    '423: authenticated lost EXECUTE';
  ASSERT has_function_privilege('service_role',
    'public.request_withdrawal(uuid,double precision,text,text)', 'EXECUTE'),
    '423: service_role lost EXECUTE';

  -- #131: real anon-role call is refused by the ACL, not just the matrix
  PERFORM set_config('role','anon',true);
  PERFORM set_config('request.jwt.claim.sub','',true);
  BEGIN
    PERFORM public.request_withdrawal(d1, 100);
    ASSERT false, '423: anon call not refused';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  PERFORM set_config('role','none',true);
END $$;
ROLLBACK;
