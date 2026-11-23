-- 424 actual-role staging run (transaction-wrapped, fixtures rolled back).
-- Covers: guard-trigger revoke spec, helper ACLs, confirm_cash_collection
-- (delivered-only, NOT_FOUND oracle, linked-ride sync, replay, audit),
-- rate_ride completion/cash gates, provider_set_working_hours 24:xx regex,
-- pharmacy_import_drug trim-dedup, pos_create_sale merchant-scoped replay.
BEGIN;
DO $$
DECLARE
  c uuid := gen_random_uuid(); u1 uuid := gen_random_uuid(); u2 uuid := gen_random_uuid();
  ua uuid := gen_random_uuid(); ub uuid := gen_random_uuid(); mu uuid := gen_random_uuid();
  d1 uuid := gen_random_uuid();
  m uuid := gen_random_uuid(); ma uuid := gen_random_uuid(); mb uuid := gen_random_uuid();
  o1 uuid := gen_random_uuid(); r1 uuid := gen_random_uuid();
  rw uuid := gen_random_uuid(); rn uuid := gen_random_uuid(); rc uuid := gen_random_uuid();
  drug uuid := gen_random_uuid();
  v_r jsonb; v_id uuid; v_blocked boolean;
BEGIN
  -- fixtures (as owner role: no normalization triggers)
  INSERT INTO auth.users(id,email) SELECT g, g::text||'@x.i' FROM unnest(ARRAY[c,u1,u2,ua,ub,mu]) g;
  INSERT INTO public.users(id,email,role)
    SELECT g, g::text||'@x.i', 'customer' FROM unnest(ARRAY[c,u2]) g
    ON CONFLICT(id) DO NOTHING;
  INSERT INTO public.users(id,email,role)
    SELECT g, g::text||'@x.i', 'driver' FROM unnest(ARRAY[u1]) g
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
  -- order: cash, unpaid, assigned to d1, still delivering
  INSERT INTO public.orders(id,user_id,merchant_id,driver_id,status,payment_status,payment_method,subtotal,total_amount,delivery_fee,delivery_latitude,delivery_longitude)
    VALUES (o1,c,m,d1,'delivering','unpaid','cash',100,120,20,30.001,31.001);
  INSERT INTO public.rides(id,rider_id,driver_id,order_id,status,payment_status,payment_method,fare,pickup_latitude,pickup_longitude,dropoff_latitude,dropoff_longitude)
    VALUES (r1,c,d1,o1,'completed','pending','cash',20,30.0,31.0,30.1,31.1);
  -- rate_ride rides: completed+wallet / searching / completed+cash-uncollected
  INSERT INTO public.rides(id,rider_id,driver_id,status,payment_status,payment_method,fare,pickup_latitude,pickup_longitude,dropoff_latitude,dropoff_longitude)
    VALUES (rw,c,d1,'completed','paid','wallet',20,30.0,31.0,30.1,31.1),
           (rn,c,d1,'searching','pending','cash',20,30.0,31.0,30.1,31.1),
           (rc,c,d1,'completed','pending','cash',20,30.0,31.0,30.1,31.1);
  -- pos replay fixture under merchant A
  INSERT INTO public.pos_sales(id,merchant_id,cashier_user_id,items,subtotal,discount,total_amount,payment_method,idempotency_key)
    VALUES (gen_random_uuid(),ma,ua,'[]'::jsonb,50,0,50,'cash','424-POSK');
  -- pharmacy catalog row with a PADDED barcode
  INSERT INTO public.drug_catalog(id,barcode,name_en,is_active,official_price_egp)
    VALUES (drug,' BC424 ','424 Drug',true,25);

  PERFORM set_config('role','authenticated',true);

  -- ── confirm_cash_collection ──────────────────────────────────────
  -- stranger sees the same NOT_FOUND as a nonexistent id (no oracle)
  PERFORM set_config('request.jwt.claim.sub', u2::text, true);
  v_r := public.confirm_cash_collection('order', o1);
  ASSERT v_r->>'code' = 'NOT_FOUND', '424: stranger got more than NOT_FOUND: '||v_r::text;
  v_r := public.confirm_cash_collection('order', gen_random_uuid());
  ASSERT v_r->>'code' = 'NOT_FOUND', '424: missing id did not return NOT_FOUND';
  -- assigned driver, order still delivering -> INVALID_LIFECYCLE
  PERFORM set_config('request.jwt.claim.sub', u1::text, true);
  v_r := public.confirm_cash_collection('order', o1);
  ASSERT v_r->>'code' = 'INVALID_LIFECYCLE', '424: delivering order confirmable: '||v_r::text;
  -- advance to delivered (owner role), then driver confirms
  PERFORM set_config('role','none',true);
  UPDATE public.orders SET status='delivered' WHERE id=o1;
  PERFORM set_config('role','authenticated',true);
  PERFORM set_config('request.jwt.claim.sub', u1::text, true);
  v_r := public.confirm_cash_collection('order', o1);
  ASSERT v_r->>'code' = 'COLLECTED', '424: delivered cash order not collectable: '||v_r::text;
  v_r := public.confirm_cash_collection('order', o1);
  ASSERT v_r->>'code' = 'ALREADY_COLLECTED', '424: replay not idempotent';
  -- state verification reads run as the owner role: RLS/column grants
  -- rightly hide payment columns and audit_log from the client role
  PERFORM set_config('role','none',true);
  ASSERT (SELECT payment_status FROM public.orders WHERE id=o1) = 'paid', '424: order not paid';
  ASSERT (SELECT payment_status FROM public.rides WHERE id=r1) = 'paid', '424: linked ride not synced';
  ASSERT (SELECT cash_collected_at FROM public.rides WHERE id=r1) IS NOT NULL, '424: ride stamp missing';
  ASSERT (SELECT count(*) FROM public.audit_log WHERE action='CASH_COLLECTED' AND resource_id=o1::text) = 1, '424: order audit missing';
  ASSERT (SELECT count(*) FROM public.audit_log WHERE action='CASH_COLLECTED' AND resource_id=r1::text) = 1, '424: ride audit missing';
  PERFORM set_config('role','authenticated',true);
  PERFORM set_config('request.jwt.claim.sub', u1::text, true);

  -- ── rate_ride ────────────────────────────────────────────────────
  PERFORM set_config('request.jwt.claim.sub', c::text, true);
  v_r := public.rate_ride(rn, 5, NULL, 0);
  ASSERT v_r->>'reason' = 'RIDE_NOT_COMPLETED', '424: uncompleted ride rateable: '||v_r::text;
  v_r := public.rate_ride(rc, 5, NULL, 0);
  ASSERT v_r->>'reason' = 'CASH_NOT_COLLECTED', '424: uncollected cash ride rateable: '||v_r::text;
  v_r := public.rate_ride(rw, 5, NULL, 0);
  ASSERT (v_r->>'ok')::boolean OR (v_r->>'success')::boolean, '424: completed wallet ride not rateable: '||v_r::text;

  -- ── provider_set_working_hours regex ─────────────────────────────
  PERFORM set_config('request.jwt.claim.sub', mu::text, true);
  v_blocked := false;
  BEGIN
    PERFORM public.provider_set_working_hours('[{"day":1,"open":"24:30","close":"23:00"}]'::jsonb);
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  ASSERT v_blocked, '424: 24:30 opening time accepted';
  v_r := public.provider_set_working_hours('[{"day":1,"open":"09:00","close":"23:00"}]'::jsonb);
  PERFORM set_config('role','none',true);
  ASSERT (SELECT count(*) FROM public.working_hours WHERE merchant_id=m AND day_of_week=1) = 1, '424: valid schedule rejected';
  PERFORM set_config('role','authenticated',true);
  PERFORM set_config('request.jwt.claim.sub', mu::text, true);

  -- ── pharmacy_import_drug: padded barcode dedups on re-import ─────
  v_r := public.pharmacy_import_drug(drug, m, 25, 10);
  ASSERT (v_r->>'ok')::boolean AND NOT COALESCE((v_r->>'duplicate')::boolean,false), '424: first import failed: '||v_r::text;
  v_id := (v_r->>'product_id')::uuid;
  v_r := public.pharmacy_import_drug(drug, m, 25, 10);
  ASSERT (v_r->>'ok')::boolean AND (v_r->>'duplicate')::boolean AND (v_r->>'product_id')::uuid = v_id, '424: re-import duplicated: '||v_r::text;
  PERFORM set_config('role','none',true);
  ASSERT (SELECT barcode FROM public.products WHERE id=v_id) = 'BC424', '424: stored barcode not trimmed';
  ASSERT (SELECT count(*) FROM public.products WHERE merchant_id=m AND barcode='BC424') = 1, '424: duplicate product row created';
  PERFORM set_config('role','authenticated',true);
  PERFORM set_config('request.jwt.claim.sub', mu::text, true);

  -- ── pos_create_sale: replay lookup is merchant-scoped ────────────
  -- merchant B owner reusing A's key must NOT replay A's sale: the call
  -- proceeds past the lookup and fails on the empty cart instead.
  PERFORM set_config('request.jwt.claim.sub', ub::text, true);
  v_blocked := false;
  BEGIN
    PERFORM public.pos_create_sale(mb, '[]'::jsonb, 0, 'cash', NULL, NULL, '424-POSK');
  EXCEPTION WHEN OTHERS THEN v_blocked := SQLERRM = 'EMPTY_CART'; END;
  ASSERT v_blocked, '424: cross-merchant key replayed or wrong failure';
  -- same merchant with same key replays fine
  PERFORM set_config('request.jwt.claim.sub', ua::text, true);
  v_r := public.pos_create_sale(ma, '[]'::jsonb, 0, 'cash', NULL, NULL, '424-POSK');
  ASSERT (v_r->>'id') IS NOT NULL OR (v_r->>'sale_id') IS NOT NULL, '424: same-merchant replay broken: '||v_r::text;

  -- ── ACL assertions ───────────────────────────────────────────────
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
