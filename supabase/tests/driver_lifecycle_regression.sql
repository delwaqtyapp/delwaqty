-- Run after migration 138. Every fixture and resulting notification is rolled back.
BEGIN;
-- Rollback-only synthetic fixtures. Never use real user accounts or money.
DO $$
DECLARE
 u uuid:=gen_random_uuid(); m_user uuid:=gen_random_uuid(); c uuid:=gen_random_uuid();
 d uuid:=gen_random_uuid(); d2 uuid:=gen_random_uuid(); v uuid:=gen_random_uuid();
 m uuid:=gen_random_uuid(); o uuid:=gen_random_uuid(); r uuid; r2 uuid; a jsonb;
BEGIN
 INSERT INTO auth.users(id,email) VALUES(u,u::text||'@example.invalid'),(m_user,m_user::text||'@example.invalid'),(c,c::text||'@example.invalid');
 INSERT INTO public.users(id,email) VALUES(u,u::text||'@example.invalid'),(m_user,m_user::text||'@example.invalid'),(c,c::text||'@example.invalid') ON CONFLICT(id) DO NOTHING;
 INSERT INTO public.drivers(id,user_id,full_name,status,is_verified,is_active,accepts_deliveries,current_latitude,current_longitude)
 VALUES(d,u,'Synthetic audit driver','online',true,true,true,30,31);
 INSERT INTO public.vehicles(id,driver_id,category,plate_number,is_active) VALUES(v,d,'motorcycle','AUDIT-ONLY',true);
 UPDATE public.drivers SET active_vehicle_id=v WHERE id=d;
 INSERT INTO public.merchants(id,name,owner_user_id,latitude,longitude) VALUES(m,'Synthetic audit merchant',m_user,30,31);
 INSERT INTO public.orders(id,user_id,merchant_id,subtotal,total_amount,delivery_fee,delivery_latitude,delivery_longitude,payment_method)
 VALUES(o,c,m,100,120,20,30.001,31.001,'instapay');
 PERFORM set_config('request.jwt.claim.sub',m_user::text,true);
 PERFORM set_config('role','authenticated',true);
 a:=public.merchant_dispatch_order_driver(o);
 PERFORM set_config('role','none',true);
 IF a->>'ok' <> 'true' THEN RAISE EXCEPTION 'merchant dispatch failed: %',a; END IF;
 SELECT id INTO r FROM public.rides WHERE order_id=o;
 IF r IS NULL THEN RAISE EXCEPTION 'no linked ride'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.ride_requests WHERE ride_id=r AND driver_id=d AND status='offered') THEN RAISE EXCEPTION 'no offer'; END IF;
 -- Repeated dispatch must not create another ride or report no drivers.
 PERFORM set_config('role','authenticated',true);
 a:=public.merchant_dispatch_order_driver(o);
 PERFORM set_config('role','none',true);
 IF a->'dispatch'->>'success' <> 'true' THEN RAISE EXCEPTION 'repeat dispatch failed: %',a; END IF;
 PERFORM set_config('request.jwt.claim.sub',u::text,true);
 UPDATE public.ride_requests SET expires_at=now()-interval '1 second' WHERE ride_id=r;
 PERFORM set_config('role','authenticated',true);
 a:=public.accept_ride_request(r,d);
 PERFORM set_config('role','none',true);
 IF a->>'reason' <> 'offer_expired' THEN RAISE EXCEPTION 'expiry not enforced: %',a; END IF;
 UPDATE public.ride_requests SET status='offered',expires_at=now()+interval '20 seconds' WHERE ride_id=r;
 PERFORM set_config('role','authenticated',true);
 a:=public.accept_ride_request(r,d);
 PERFORM set_config('role','none',true);
 IF a->>'success' <> 'true' THEN RAISE EXCEPTION 'accept failed: %',a; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.orders WHERE id=o AND driver_id=d AND dispatch_status='ASSIGNED') THEN RAISE EXCEPTION 'assignment sync failed'; END IF;
 PERFORM set_config('role','authenticated',true);
 a:=public.complete_delivery(r,d,NULL::text,NULL::numeric,NULL::text);
 PERFORM set_config('role','none',true);
 IF a->>'reason' <> 'invalid_transition' THEN RAISE EXCEPTION 'premature completion allowed: %',a; END IF;
 PERFORM set_config('role','authenticated',true);
 a:=public.driver_arrive(r,d);
 PERFORM set_config('role','none',true);
 IF a->>'success' <> 'true' THEN RAISE EXCEPTION 'arrive failed: %',a; END IF;
 PERFORM set_config('role','authenticated',true);
 a:=public.start_trip(r,d,'');
 PERFORM set_config('role','none',true);
 IF a->>'success' <> 'true' THEN RAISE EXCEPTION 'start failed: %',a; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.orders WHERE id=o AND status='delivering') THEN RAISE EXCEPTION 'pickup sync failed'; END IF;
 PERFORM set_config('request.jwt.claim.sub',c::text,true);
 PERFORM set_config('role','authenticated',true);
 a:=public.complete_delivery(r,d,NULL::text,NULL::numeric,NULL::text);
 PERFORM set_config('role','none',true);
 IF a->>'reason' <> 'forbidden' THEN RAISE EXCEPTION 'wrong identity completion allowed: %',a; END IF;
 PERFORM set_config('request.jwt.claim.sub',u::text,true);
 PERFORM set_config('role','authenticated',true);
 a:=public.complete_delivery(r,d,NULL::text,NULL::numeric,NULL::text);
 PERFORM set_config('role','none',true);
 IF a->>'success' <> 'true' THEN RAISE EXCEPTION 'complete failed: %',a; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.orders WHERE id=o AND status='delivered') THEN RAISE EXCEPTION 'completion sync failed'; END IF;
 PERFORM set_config('role','authenticated',true);
 a:=public.complete_delivery(r,d,NULL::text,NULL::numeric,NULL::text);
 PERFORM set_config('role','none',true);
 IF a->>'reason' <> 'invalid_transition' THEN RAISE EXCEPTION 'repeat completion allowed: %',a; END IF;
 PERFORM set_config('role','authenticated',true);
 a:=public.driver_update_location(d,30.01::double precision,31.01::double precision,NULL::double precision,NULL::double precision);
 IF a->>'success' <> 'true' THEN RAISE EXCEPTION 'location update failed: %',a; END IF;
 IF has_table_privilege(current_user,'public.deliveries','UPDATE') THEN RAISE EXCEPTION 'legacy writer still accessible'; END IF;
 BEGIN
   INSERT INTO public.ride_requests(ride_id,driver_id) VALUES(r,d);
   RAISE EXCEPTION 'direct offer insertion unexpectedly allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 PERFORM set_config('role','none',true);
 -- No creation after completion.
 PERFORM set_config('request.jwt.claim.sub',m_user::text,true);
 PERFORM set_config('role','authenticated',true);
 a:=public.merchant_dispatch_order_driver(o);
 PERFORM set_config('role','none',true);
 IF a->>'reason' <> 'INVALID_ORDER_STATE' THEN RAISE EXCEPTION 'completed order redispatched: %',a; END IF;
END $$;
SELECT 'synthetic driver lifecycle assertions passed; transaction rolled back' AS result;

ROLLBACK;
