-- 424a/424b actual-role staging run (transaction-wrapped, fixtures rolled back).
-- Environment-aware: 424b replaces bodies only on prod-state md5s, so the
-- working-hours / pos sections branch on the LIVE md5 (staging
-- keeps its newer 398/400 bodies; prod gets the 424b targets).
BEGIN;
DO $$
DECLARE
  c uuid := gen_random_uuid(); u1 uuid := gen_random_uuid(); u2 uuid := gen_random_uuid();
  ua uuid := gen_random_uuid(); ub uuid := gen_random_uuid(); mu uuid := gen_random_uuid();
  d1 uuid := gen_random_uuid();
  m uuid := gen_random_uuid(); ma uuid := gen_random_uuid(); mb uuid := gen_random_uuid();
  o1 uuid := gen_random_uuid(); r1 uuid := gen_random_uuid();
  rw uuid := gen_random_uuid(); rn uuid := gen_random_uuid(); rc uuid := gen_random_uuid();
  sa uuid := gen_random_uuid(); sb uuid := gen_random_uuid();
  v_r jsonb; v_id uuid; v_blocked boolean; v_md5 text;
BEGIN
  INSERT INTO auth.users(id,email) SELECT g, g::text||'@x.i' FROM unnest(ARRAY[c,u1,u2,ua,ub,mu]) g;
  INSERT INTO public.users(id,email,role)
    SELECT g, g::text||'@x.i', 'customer' FROM unnest(ARRAY[c,u2]) g
    ON CONFLICT(id) DO NOTHING;
  INSERT INTO public.users(id,email,role) VALUES (u1,u1::text||'@x.i','driver')
    ON CONFLICT(id) DO UPDATE SET role=EXCLUDED.role;
  INSERT INTO public.users(id,email,role)
    SELECT g, g::text||'@x.i', 'merchant' FROM unnest(ARRAY[ua,ub,mu]) g
    ON CONFLICT(id) DO UPDATE SET role=EXCLUDED.role;
  INSERT INTO public.drivers(id,user_id,full_name,status,is_verified,is_active,accepts_deliveries,service_types,max_delivery_distance_km,max_weight_kg)
    VALUES (d1,u1,'424 D1','approved',true,true,true,ARRAY['parcel']::text[],15,20);
  INSERT INTO public.merchants(id,name,owner_user_id,type,status,is_open) VALUES
    (m,'424 M',mu,'restaurant','active',true),
    (ma,'424 MA',ua,'grocery','active',true),
    (mb,'424 MB',ub,'grocery','active',true);
  INSERT INTO public.orders(id,user_id,merchant_id,driver_id,status,payment_status,payment_method,subtotal,total_amount,delivery_fee,delivery_latitude,delivery_longitude)
    VALUES (o1,c,m,d1,'delivering','unpaid','cash',100,120,20,30.001,31.001);
  INSERT INTO public.rides(id,rider_id,driver_id,order_id,status,payment_status,payment_method,fare,pickup_latitude,pickup_longitude,dropoff_latitude,dropoff_longitude)
    VALUES (r1,c,d1,o1,'completed','pending','cash',20,30.0,31.0,30.1,31.1);
  INSERT INTO public.rides(id,rider_id,driver_id,status,payment_status,payment_method,fare,pickup_latitude,pickup_longitude,dropoff_latitude,dropoff_longitude)
    VALUES (rw,c,d1,'completed','paid','wallet',20,30.0,31.0,30.1,31.1),
           (rn,c,d1,'searching','pending','cash',20,30.0,31.0,30.1,31.1),
           (rc,c,d1,'completed','pending','cash',20,30.0,31.0,30.1,31.1);

  PERFORM set_config('role','authenticated',true);

  -- ── confirm_cash_collection (identical body on both envs) ───────
  PERFORM set_config('request.jwt.claim.sub', u2::text, true);
  v_r := public.confirm_cash_collection('order', o1);
  ASSERT v_r->>'code' = 'NOT_FOUND', '424: stranger got more than NOT_FOUND: '||v_r::text;
  v_r := public.confirm_cash_collection('order', gen_random_uuid());
  ASSERT v_r->>'code' = 'NOT_FOUND', '424: missing id did not return NOT_FOUND';
  PERFORM set_config('request.jwt.claim.sub', u1::text, true);
  v_r := public.confirm_cash_collection('order', o1);
  ASSERT v_r->>'code' = 'INVALID_LIFECYCLE', '424: delivering order confirmable: '||v_r::text;
  PERFORM set_config('role','none',true);
  UPDATE public.orders SET status='delivered' WHERE id=o1;
  PERFORM set_config('role','authenticated',true);
  PERFORM set_config('request.jwt.claim.sub', u1::text, true);
  v_r := public.confirm_cash_collection('order', o1);
  ASSERT v_r->>'code' = 'COLLECTED', '424: delivered cash order not collectable: '||v_r::text;
  v_r := public.confirm_cash_collection('order', o1);
  ASSERT v_r->>'code' = 'ALREADY_COLLECTED', '424: replay not idempotent';
  PERFORM set_config('role','none',true);
  ASSERT (SELECT payment_status FROM public.orders WHERE id=o1) = 'paid', '424: order not paid';
  ASSERT (SELECT payment_status FROM public.rides WHERE id=r1) = 'paid', '424: linked ride not synced';
  ASSERT (SELECT cash_collected_at FROM public.rides WHERE id=r1) IS NOT NULL, '424: ride stamp missing';
  ASSERT (SELECT count(*) FROM public.audit_log WHERE action='CASH_COLLECTED' AND resource_id=o1::text) = 1, '424: order audit missing';
  ASSERT (SELECT count(*) FROM public.audit_log WHERE action='CASH_COLLECTED' AND resource_id=r1::text) = 1, '424: ride audit missing';
  PERFORM set_config('role','authenticated',true);

  -- ── rate_ride (identical body on both envs) ─────────────────────
  PERFORM set_config('request.jwt.claim.sub', c::text, true);
  v_r := public.rate_ride(rn, 5, NULL, 0);
  ASSERT v_r->>'reason' = 'RIDE_NOT_COMPLETED', '424: uncompleted ride rateable: '||v_r::text;
  v_r := public.rate_ride(rc, 5, NULL, 0);
  ASSERT v_r->>'reason' = 'CASH_NOT_COLLECTED', '424: uncollected cash ride rateable: '||v_r::text;
  v_r := public.rate_ride(rw, 5, NULL, 0);
  ASSERT (v_r->>'ok')::boolean OR (v_r->>'success')::boolean, '424: completed wallet ride not rateable: '||v_r::text;

  -- ── provider_set_working_hours ──────────────────────────────────
  v_md5 := (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
            WHERE n.nspname='public' AND p.proname='provider_set_working_hours');
  ASSERT v_md5 IN ('23fb4da4e061c3b88aa483e234825932','7c2f6d1b25ca39384e35120df2aa0210'),
    '424: working_hours body at unexpected md5 '||v_md5;
  PERFORM set_config('request.jwt.claim.sub', mu::text, true);
  v_blocked := false;
  BEGIN
    PERFORM public.provider_set_working_hours('[{"day":1,"open":"24:30","close":"23:00"}]'::jsonb);
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  ASSERT v_blocked, '424: 24:30 opening time accepted';
  v_r := public.provider_set_working_hours('[{"day":1,"open":"09:00","close":"23:00"}]'::jsonb);
  IF v_md5 = '23fb4da4e061c3b88aa483e234825932' THEN
    -- staging 398 semantics: overnight window (close < open) is valid
    v_r := public.provider_set_working_hours('[{"day":2,"open":"18:00","close":"02:00"}]'::jsonb);
    PERFORM set_config('role','none',true);
    ASSERT (SELECT count(*) FROM public.working_hours WHERE merchant_id=m AND day_of_week=2 AND open_time='18:00' AND close_time='02:00') = 1,
      '424: 398 overnight window rejected on staging body';
    PERFORM set_config('role','authenticated',true);
    PERFORM set_config('request.jwt.claim.sub', mu::text, true);
  ELSE
    -- prod 424b target keeps the close-after-open rule
    v_blocked := false;
    BEGIN
      PERFORM public.provider_set_working_hours('[{"day":2,"open":"18:00","close":"02:00"}]'::jsonb);
    EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
    ASSERT v_blocked, '424: overnight window accepted by prod-target body';
  END IF;

  -- ── pos_create_sale: merchant-scoped replay + per-merchant index ─
  v_md5 := (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
            WHERE n.nspname='public' AND p.proname='pos_create_sale');
  ASSERT v_md5 IN ('ca32bc89277d6777be2ac66f0c3a8683','0004abb4841688095ae1a2ae58ebb488'),
    '424: pos body at unexpected md5 '||v_md5;
  -- per-merchant index proof: the SAME key under TWO merchants must both
  -- insert (the dropped global constraint would 23505 the second)
  PERFORM set_config('role','none',true);
  INSERT INTO public.pos_sales(id,merchant_id,cashier_user_id,items,subtotal,discount,total_amount,payment_method,idempotency_key)
    VALUES (sa,ma,ua,'[]'::jsonb,50,0,50,'cash','424-POSK'),
           (sb,mb,ub,'[]'::jsonb,70,0,70,'cash','424-POSK');
  ASSERT (SELECT count(*) FROM public.pos_sales WHERE idempotency_key='424-POSK') = 2,
    '424: per-merchant idempotency index blocked a cross-merchant key';
  -- replay fixture under merchant A only (key exists under ma, not mb)
  INSERT INTO public.pos_sales(id,merchant_id,cashier_user_id,items,subtotal,discount,total_amount,payment_method,idempotency_key)
    VALUES (gen_random_uuid(),ma,ua,'[]'::jsonb,50,0,50,'cash','424-ONLY-A');
  PERFORM set_config('role','authenticated',true);
  -- merchant B owner reusing A's key must NOT replay A's sale: proceeds
  -- past the lookup and fails on the empty cart instead
  PERFORM set_config('request.jwt.claim.sub', ub::text, true);
  v_blocked := false;
  BEGIN
    PERFORM public.pos_create_sale(mb, '[]'::jsonb, 0, 'cash', NULL, NULL, '424-ONLY-A');
  EXCEPTION WHEN OTHERS THEN v_blocked := SQLERRM = 'EMPTY_CART'; END;
  ASSERT v_blocked, '424: cross-merchant key replayed or wrong failure';
  -- same merchant, same key replays the original sale
  PERFORM set_config('request.jwt.claim.sub', ua::text, true);
  v_r := public.pos_create_sale(ma, '[]'::jsonb, 0, 'cash', NULL, NULL, '424-ONLY-A');
  ASSERT (v_r->>'id') IS NOT NULL OR (v_r->>'sale_id') IS NOT NULL, '424: same-merchant replay broken: '||v_r::text;

  -- ── ACL matrix (424a) ────────────────────────────────────────────
  ASSERT NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname IN
      ('orders_guard_sensitive','rides_guard_client_writes','service_bookings_guard_client_writes',
       'reservations_guard_customer_updates','freeze_review_identity','freeze_service_review_identity',
       'complaints_guard_admin_fields','guard_vehicle_verification','service_providers_guard_sensitive_fields',
       '_audit_cash_collection','_audit_cash_pair_mismatch')
      AND (p.proacl::text ~ '(^|[{,])=X/'
        OR has_function_privilege('anon', p.oid, 'EXECUTE')
        OR has_function_privilege('authenticated', p.oid, 'EXECUTE'))),
    '424: a guard or helper is still client/PUBLIC-callable';
  ASSERT has_function_privilege('service_role','public._audit_cash_collection(text,uuid,numeric)','EXECUTE'),
    '424: service_role lost helper access';

  PERFORM set_config('role','none',true);
END $$;
ROLLBACK;
