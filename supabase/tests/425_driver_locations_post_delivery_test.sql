-- 425 actual-role staging run (transaction-wrapped, fixtures rolled back).
-- Customer + merchant: readable while delivering, unreadable after
-- delivered. Driver self, owner and permissioned admin: unaffected.
BEGIN;
DO $$
DECLARE
  c uuid := gen_random_uuid(); u1 uuid := gen_random_uuid(); mu uuid := gen_random_uuid();
  ow uuid := gen_random_uuid(); ad uuid := gen_random_uuid();
  d1 uuid := gen_random_uuid(); m uuid := gen_random_uuid(); o1 uuid := gen_random_uuid();
  v_n int;
BEGIN
  INSERT INTO auth.users(id,email) SELECT g, g::text||'@x.i' FROM unnest(ARRAY[c,u1,mu,ow,ad]) g;
  INSERT INTO public.users(id,email,role) VALUES
    (c,c::text||'@x.i','customer'),(mu,mu::text||'@x.i','merchant'),
    (ow,ow::text||'@x.i','owner'),(ad,ad::text||'@x.i','admin')
    ON CONFLICT(id) DO UPDATE SET role=EXCLUDED.role;
  INSERT INTO public.users(id,email,role) VALUES (u1,u1::text||'@x.i','driver')
    ON CONFLICT(id) DO UPDATE SET role=EXCLUDED.role;
  INSERT INTO public.admin_management(admin_id,supervisor_id,is_active) VALUES (ad,ow,true);
  INSERT INTO public.regions(id,code,country_code,name_ar,type,is_active) VALUES (gen_random_uuid(),'425R','EG','425','city',true);
  INSERT INTO public.admin_region_assignments(admin_id,region_id) SELECT ad, id FROM public.regions WHERE code='425R';
  INSERT INTO public.admin_permission_grants(admin_id,permission) VALUES (ad,'DELIVERY_LOCATION_VIEW');
  INSERT INTO public.drivers(id,user_id,full_name,status,is_verified,is_active,accepts_deliveries,service_types,max_delivery_distance_km,max_weight_kg)
    VALUES (d1,u1,'425 D1','approved',true,true,true,ARRAY['parcel']::text[],15,20);
  INSERT INTO public.merchants(id,name,owner_user_id,type,status,is_open)
    VALUES (m,'425 M',mu,'restaurant','active',true);
  INSERT INTO public.orders(id,user_id,merchant_id,driver_id,status,dispatch_status,payment_status,payment_method,subtotal,total_amount,delivery_fee,delivery_latitude,delivery_longitude)
    VALUES (o1,c,m,d1,'delivering','ACCEPTED','unpaid','cash',100,120,20,30.001,31.001);
  INSERT INTO public.driver_locations(driver_id,latitude,longitude) VALUES (d1,30.05,31.25);

  PERFORM set_config('role','authenticated',true);

  -- while delivering: customer, merchant, driver, owner, admin all read
  PERFORM set_config('request.jwt.claim.sub', c::text, true);
  SELECT count(*) INTO v_n FROM public.driver_locations WHERE driver_id=d1;
  ASSERT v_n = 1, '425: customer cannot read while delivering';
  PERFORM set_config('request.jwt.claim.sub', mu::text, true);
  SELECT count(*) INTO v_n FROM public.driver_locations WHERE driver_id=d1;
  ASSERT v_n = 1, '425: merchant cannot read while delivering';
  PERFORM set_config('request.jwt.claim.sub', u1::text, true);
  SELECT count(*) INTO v_n FROM public.driver_locations WHERE driver_id=d1;
  ASSERT v_n = 1, '425: driver cannot read own row';

  -- delivery completes
  PERFORM set_config('role','none',true);
  UPDATE public.orders SET status='delivered' WHERE id=o1;
  PERFORM set_config('role','authenticated',true);

  -- customer + merchant lose the row; owner, admin, driver keep it
  PERFORM set_config('request.jwt.claim.sub', c::text, true);
  SELECT count(*) INTO v_n FROM public.driver_locations WHERE driver_id=d1;
  ASSERT v_n = 0, '425: customer still reads after delivered';
  PERFORM set_config('request.jwt.claim.sub', mu::text, true);
  SELECT count(*) INTO v_n FROM public.driver_locations WHERE driver_id=d1;
  ASSERT v_n = 0, '425: merchant still reads after delivered';
  PERFORM set_config('request.jwt.claim.sub', ow::text, true);
  SELECT count(*) INTO v_n FROM public.driver_locations WHERE driver_id=d1;
  ASSERT v_n = 1, '425: owner lost access after delivered';
  PERFORM set_config('request.jwt.claim.sub', ad::text, true);
  SELECT count(*) INTO v_n FROM public.driver_locations WHERE driver_id=d1;
  ASSERT v_n = 1, '425: admin lost access after delivered';
  PERFORM set_config('request.jwt.claim.sub', u1::text, true);
  SELECT count(*) INTO v_n FROM public.driver_locations WHERE driver_id=d1;
  ASSERT v_n = 1, '425: driver lost own row after delivered';

  -- cancelled orders also close the window
  PERFORM set_config('role','none',true);
  UPDATE public.orders SET status='delivering' WHERE id=o1;
  PERFORM set_config('role','authenticated',true);
  PERFORM set_config('request.jwt.claim.sub', c::text, true);
  SELECT count(*) INTO v_n FROM public.driver_locations WHERE driver_id=d1;
  ASSERT v_n = 1, '425: customer lost access while delivering (restore)';
  PERFORM set_config('role','none',true);
  UPDATE public.orders SET status='cancelled' WHERE id=o1;
  PERFORM set_config('role','authenticated',true);
  PERFORM set_config('request.jwt.claim.sub', c::text, true);
  SELECT count(*) INTO v_n FROM public.driver_locations WHERE driver_id=d1;
  ASSERT v_n = 0, '425: customer still reads after cancelled';

  PERFORM set_config('role','none',true);
END $$;
ROLLBACK;
