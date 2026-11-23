-- Staging-only rollback suite for migration 392 (cash handoff), review-fix
-- revision. Verifies: authorization-first idempotency (no id oracle), the
-- completed-handoff predicate in both reference paths, linked order/ride
-- payment sync with never-resurrect guards, replay healing, per-resource
-- exactly-once audit, no settlement ledger writes, historical null-stamp
-- compatibility, the collection gate on driver ratings, and the captain
-- cash-state RPC. Every fixture rolls back.
-- The reversed-reference two-session race is exercised separately from bash
-- (two concurrent Management API sessions); see the task report.
begin;

create temporary table zz_cash_ctx(
  c uuid, x uuid, du uuid, drv uuid, merch uuid,
  o1 uuid, o2 uuid, o3 uuid, o4 uuid, o5 uuid, o6 uuid, o7 uuid, o8 uuid, o9 uuid, o10 uuid,
  r1 uuid, r2 uuid, r3 uuid, r5 uuid, r6 uuid, r7 uuid, r8 uuid, r9 uuid, r10 uuid, r11 uuid, r12 uuid, r13 uuid,
  sp uuid, sb1 uuid, sb2 uuid, sb3 uuid
);
insert into zz_cash_ctx
select gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
       gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
       gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
       gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
       gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
       gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
       gen_random_uuid();

-- cash_collected_by references auth.users, so the fixture needs both sides.
insert into auth.users(id,email)
select c,'zz-cash-c@example.invalid' from zz_cash_ctx union all
select x,'zz-cash-x@example.invalid' from zz_cash_ctx union all
select du,'zz-cash-d@example.invalid' from zz_cash_ctx;

-- handle_new_user may already have created the public.users rows.
insert into public.users(id,email,full_name,role,user_type,verification_status)
select c,'zz-cash-c@example.invalid','zz-cash-c','customer','customer','approved' from zz_cash_ctx union all
select x,'zz-cash-x@example.invalid','zz-cash-x','customer','customer','approved' from zz_cash_ctx union all
select du,'zz-cash-d@example.invalid','zz-cash-d','driver','driver','approved' from zz_cash_ctx
on conflict (id) do nothing;

insert into public.drivers(id,user_id,full_name,is_active,is_verified,verification_status)
select drv,du,'zz-cash-driver',true,true,'verified' from zz_cash_ctx;

insert into public.merchants(id,owner_user_id,name,status,is_open,latitude,longitude,delivery_fee)
select merch,c,'zz-cash-store','active',true,0,0,15 from zz_cash_ctx;

-- o1: cash order delivered, assigned to the driver, linked ride r1 (completed).
insert into public.orders(id,user_id,merchant_id,driver_id,status,payment_status,payment_method,subtotal,delivery_fee,total_amount)
select o1,c,merch,drv,'delivered','pending','cash',100,15,115 from zz_cash_ctx;
insert into public.rides(id,rider_id,driver_id,order_id,merchant_id,service_type,ride_type,status,payment_status,payment_method,fare,pickup_latitude,pickup_longitude,dropoff_latitude,dropoff_longitude)
select r1,c,drv,o1,merch,'food_delivery','motorcycle','completed','pending','cash',15,0,0,0.001,0.001 from zz_cash_ctx;

-- o2/r2: same shape, exercised through the ride reference instead.
insert into public.orders(id,user_id,merchant_id,driver_id,status,payment_status,payment_method,subtotal,delivery_fee,total_amount)
select o2,c,merch,drv,'delivered','pending','cash',80,15,95 from zz_cash_ctx;
insert into public.rides(id,rider_id,driver_id,order_id,merchant_id,service_type,ride_type,status,payment_status,payment_method,fare,pickup_latitude,pickup_longitude,dropoff_latitude,dropoff_longitude)
select r2,c,drv,o2,merch,'food_delivery','motorcycle','completed','pending','cash',15,0,0,0.001,0.001 from zz_cash_ctx;

-- r3: pure courier cash ride, no order.
insert into public.rides(id,rider_id,driver_id,service_type,ride_type,status,payment_status,payment_method,fare,pickup_latitude,pickup_longitude,dropoff_latitude,dropoff_longitude)
select r3,c,drv,'courier','motorcycle','completed','pending','cash',40,0,0,0.001,0.001 from zz_cash_ctx;

-- o3: non-cash order; o4: cash order still pending (wrong lifecycle).
insert into public.orders(id,user_id,merchant_id,driver_id,status,payment_status,payment_method,subtotal,delivery_fee,total_amount)
select o3,c,merch,drv,'delivered','pending','wallet',60,15,75 from zz_cash_ctx;
insert into public.orders(id,user_id,merchant_id,driver_id,status,payment_status,payment_method,subtotal,delivery_fee,total_amount)
select o4,c,merch,drv,'pending','pending','cash',50,15,65 from zz_cash_ctx;

-- o5/r5: #70 — cash order still delivering, handoff incomplete (ride inTrip).
insert into public.orders(id,user_id,merchant_id,driver_id,status,payment_status,payment_method,subtotal,delivery_fee,total_amount)
select o5,c,merch,drv,'delivering','pending','cash',70,15,85 from zz_cash_ctx;
insert into public.rides(id,rider_id,driver_id,order_id,merchant_id,service_type,ride_type,status,payment_status,payment_method,fare,pickup_latitude,pickup_longitude,dropoff_latitude,dropoff_longitude)
select r5,c,drv,o5,merch,'food_delivery','motorcycle','inTrip','pending','cash',15,0,0,0.001,0.001 from zz_cash_ctx;

-- o6/r6: #73 — cash order delivered, but the linked ride was refunded.
insert into public.orders(id,user_id,merchant_id,driver_id,status,payment_status,payment_method,subtotal,delivery_fee,total_amount)
select o6,c,merch,drv,'delivered','pending','cash',60,15,75 from zz_cash_ctx;
insert into public.rides(id,rider_id,driver_id,order_id,merchant_id,service_type,ride_type,status,payment_status,payment_method,fare,pickup_latitude,pickup_longitude,dropoff_latitude,dropoff_longitude)
select r6,c,drv,o6,merch,'food_delivery','motorcycle','completed','refunded','cash',15,0,0,0.001,0.001 from zz_cash_ctx;

-- o7/r7: #73 — cash order delivered, linked ride is a non-cash (wallet) one.
insert into public.orders(id,user_id,merchant_id,driver_id,status,payment_status,payment_method,subtotal,delivery_fee,total_amount)
select o7,c,merch,drv,'delivered','pending','cash',55,15,70 from zz_cash_ctx;
insert into public.rides(id,rider_id,driver_id,order_id,merchant_id,service_type,ride_type,status,payment_status,payment_method,fare,pickup_latitude,pickup_longitude,dropoff_latitude,dropoff_longitude)
select r7,c,drv,o7,merch,'food_delivery','motorcycle','completed','pending','wallet',15,0,0,0.001,0.001 from zz_cash_ctx;

-- r8: historical paid cash ride with no collection stamp (pre-392 shape).
insert into public.rides(id,rider_id,driver_id,service_type,ride_type,status,payment_status,payment_method,fare,cash_collected_at,completed_at,pickup_latitude,pickup_longitude,dropoff_latitude,dropoff_longitude)
select r8,c,drv,'courier','motorcycle','completed','paid','cash',30,NULL,now()-interval '2 days',0,0,0.001,0.001 from zz_cash_ctx;

-- r9: non-cash ride still inTrip, for the rate_ride completion check.
insert into public.rides(id,rider_id,driver_id,service_type,ride_type,status,payment_status,payment_method,fare,pickup_latitude,pickup_longitude,dropoff_latitude,dropoff_longitude)
select r9,c,drv,'courier','motorcycle','inTrip','pending','wallet',20,0,0,0.001,0.001 from zz_cash_ctx;

-- o8/r10 and o9/r11: historical paid cash pairs with NULL stamps on BOTH
-- sides, replayed from the opposite resource (#73 follow-up).
insert into public.orders(id,user_id,merchant_id,driver_id,status,payment_status,payment_method,subtotal,delivery_fee,total_amount,cash_collected_at)
select o8,c,merch,drv,'delivered','paid','cash',100,15,115,NULL from zz_cash_ctx;
insert into public.rides(id,rider_id,driver_id,order_id,merchant_id,service_type,ride_type,status,payment_status,payment_method,fare,cash_collected_at,completed_at,pickup_latitude,pickup_longitude,dropoff_latitude,dropoff_longitude)
select r10,c,drv,o8,merch,'food_delivery','motorcycle','completed','paid','cash',15,NULL,now()-interval '1 day',0,0,0.001,0.001 from zz_cash_ctx;
insert into public.orders(id,user_id,merchant_id,driver_id,status,payment_status,payment_method,subtotal,delivery_fee,total_amount,cash_collected_at)
select o9,c,merch,drv,'delivered','paid','cash',90,15,105,NULL from zz_cash_ctx;
insert into public.rides(id,rider_id,driver_id,order_id,merchant_id,service_type,ride_type,status,payment_status,payment_method,fare,cash_collected_at,completed_at,pickup_latitude,pickup_longitude,dropoff_latitude,dropoff_longitude)
select r11,c,drv,o9,merch,'food_delivery','motorcycle','completed','paid','cash',15,NULL,now()-interval '1 day',0,0,0.001,0.001 from zz_cash_ctx;

-- r13: stamp present, collected_by NULL — replay must not invent authorship.
insert into public.rides(id,rider_id,driver_id,service_type,ride_type,status,payment_status,payment_method,fare,cash_collected_at,cash_collected_by,completed_at,pickup_latitude,pickup_longitude,dropoff_latitude,dropoff_longitude)
select r13,c,drv,'courier','motorcycle','completed','paid','cash',22,'2026-11-20 10:00+00'::timestamptz,NULL,now()-interval '3 days',0,0,0.001,0.001 from zz_cash_ctx;

-- o10/r12: reverse-direction bad partner — completed cash ride whose linked
-- order was refunded (#73 reverse).
insert into public.orders(id,user_id,merchant_id,driver_id,status,payment_status,payment_method,subtotal,delivery_fee,total_amount)
select o10,c,merch,drv,'delivered','refunded','cash',45,15,60 from zz_cash_ctx;
insert into public.rides(id,rider_id,driver_id,order_id,merchant_id,service_type,ride_type,status,payment_status,payment_method,fare,pickup_latitude,pickup_longitude,dropoff_latitude,dropoff_longitude)
select r12,c,drv,o10,merch,'food_delivery','motorcycle','completed','pending','cash',15,0,0,0.001,0.001 from zz_cash_ctx;

-- sb1: paid WALLET service booking; sb2: REFUNDED cash booking (#83).
insert into public.service_providers(id,user_id,name,category_type)
select sp,du,'zz-cash-provider','plumbing' from zz_cash_ctx;
insert into public.service_bookings(id,user_id,provider_id,provider_name,category_type,status,scheduled_date,scheduled_time,payment_method,payment_status)
select sb1,c,sp,'zz-cash-provider','plumbing','pending',current_date,'10:00','wallet','unpaid' from zz_cash_ctx;
insert into public.service_bookings(id,user_id,provider_id,provider_name,category_type,status,scheduled_date,scheduled_time,payment_method,payment_status)
select sb2,c,sp,'zz-cash-provider','plumbing','pending',current_date,'11:00','cash','unpaid' from zz_cash_ctx;
-- The normalize trigger forces pending/unpaid on insert; set the target
-- states with an update (runs as postgres, the client-writes guard allows it).
update public.service_bookings set status='completed', payment_status='paid' where id=(select sb1 from zz_cash_ctx);
update public.service_bookings set status='completed', payment_status='refunded' where id=(select sb2 from zz_cash_ctx);
-- sb3: paid cash booking, stamp present, collector NULL (security LOW:
-- replay must not invent the collector).
insert into public.service_bookings(id,user_id,provider_id,provider_name,category_type,status,scheduled_date,scheduled_time,payment_method,payment_status)
select sb3,c,sp,'zz-cash-provider','plumbing','pending',current_date,'12:00','cash','unpaid' from zz_cash_ctx;
update public.service_bookings set status='completed', payment_status='paid',
  cash_collected_at='2026-11-20 08:00+00'::timestamptz, cash_collected_by=NULL
 where id=(select sb3 from zz_cash_ctx);

-- Full settlement-ledger snapshot: collection must never add rows.
create temporary table zz_cash_ledger_snap as
select (select count(*) from public.driver_obligations) as obligations,
       (select count(*) from public.merchant_ledger) as merchant_ledger,
       (select count(*) from public.platform_commissions) as commissions,
       (select count(*) from public.driver_earnings) as earnings;

do $$
declare
  t record; r jsonb; v_cnt int;
begin
  select * into t from zz_cash_ctx;

  -- ── Oracle closed: a stranger gets NOT_FOUND for real and fake ids alike.
  perform set_config('request.jwt.claim.sub',t.x::text,true);
  r:=public.confirm_cash_collection('order',t.o1);
  assert r->>'ok'='false' and r->>'code'='NOT_FOUND', 'stranger must not probe order ids: '||r::text;
  r:=public.confirm_cash_collection('order',gen_random_uuid());
  assert r->>'ok'='false' and r->>'code'='NOT_FOUND', 'missing id same shape';
  r:=public.confirm_cash_collection('ride',t.r1);
  assert r->>'ok'='false' and r->>'code'='NOT_FOUND', 'stranger must not probe ride ids';
  -- The customer owns the order but is not the collector.
  perform set_config('request.jwt.claim.sub',t.c::text,true);
  r:=public.confirm_cash_collection('order',t.o1);
  assert r->>'ok'='false' and r->>'code'='NOT_FOUND', 'customer is not the collector';

  -- ── #70: incomplete handoff refused in BOTH paths, nothing stamped.
  perform set_config('request.jwt.claim.sub',t.du::text,true);
  r:=public.confirm_cash_collection('order',t.o5);
  assert r->>'ok'='false' and r->>'code'='INVALID_LIFECYCLE' and r->>'current_status'='delivering',
    'delivering order refused: '||r::text;
  r:=public.confirm_cash_collection('ride',t.r5);
  assert r->>'ok'='false' and r->>'code'='INVALID_LIFECYCLE' and r->>'current_status'='inTrip',
    'incomplete ride refused: '||r::text;
  assert (select payment_status from public.orders where id=t.o5)='pending', 'delivering order untouched';
  assert (select payment_status from public.rides where id=t.r5)='pending', 'incomplete ride untouched';
  assert (select count(*) from public.audit_log where action='CASH_COLLECTED'
          and resource_id in (t.o5::text,t.r5::text))=0, 'refused collection writes no audit';

  -- ── Captain cash state: hidden from strangers, visible to the driver.
  perform set_config('request.jwt.claim.sub',t.x::text,true);
  r:=public.driver_cash_collection_state(t.r1);
  assert r->>'ok'='false' and r->>'code'='NOT_FOUND', 'cash state hidden from strangers';
  perform set_config('request.jwt.claim.sub',t.du::text,true);
  r:=public.driver_cash_collection_state(t.r1);
  assert r->>'ok'='true' and (r->>'collected')::boolean=false
     and (r->>'amount')::numeric=115 and r->>'order_id'=t.o1::text,
     'driver sees order total as collectable: '||r::text;

  -- ── Order path: assigned driver collects; linked ride syncs; per-resource audit.
  r:=public.confirm_cash_collection('order',t.o1);
  assert r->>'ok'='true' and r->>'code'='COLLECTED' and (r->>'amount')::numeric=115, 'order collection: '||r::text;
  assert (select payment_status from public.orders where id=t.o1)='paid', 'order paid';
  assert (select cash_collected_by from public.orders where id=t.o1)=t.du, 'order collected_by driver';
  assert (select payment_status from public.rides where id=t.r1)='paid', 'linked ride synced';
  assert (select cash_collected_by from public.rides where id=t.r1)=t.du, 'ride collected_by synced';
  assert (select count(*) from public.audit_log where action='CASH_COLLECTED' and resource='order' and resource_id=t.o1::text)=1,
    'exactly one order audit row';
  assert (select count(*) from public.audit_log where action='CASH_COLLECTED' and resource='ride' and resource_id=t.r1::text)=1,
    'partner ride audit row included';
  assert (select (after->>'amount')::numeric from public.audit_log
          where action='CASH_COLLECTED' and resource='order' and resource_id=t.o1::text)=115,
    'order audit amount is the order total';
  assert (select (after->>'amount')::numeric from public.audit_log
          where action='CASH_COLLECTED' and resource='ride' and resource_id=t.r1::text)=115,
    'partner ride audit amount is also the order total';

  -- Replay is idempotent for the authorized driver only.
  r:=public.confirm_cash_collection('order',t.o1);
  assert r->>'ok'='true' and r->>'code'='ALREADY_COLLECTED', 'idempotent replay';
  assert (select count(*) from public.audit_log where action='CASH_COLLECTED' and resource_id in (t.o1::text,t.r1::text))=2,
    'replay adds no audit rows';
  -- …but the stranger still cannot tell it apart from a fake id.
  perform set_config('request.jwt.claim.sub',t.x::text,true);
  r:=public.confirm_cash_collection('order',t.o1);
  assert r->>'ok'='false' and r->>'code'='NOT_FOUND', 'collected state still hidden';

  -- ── Ride path: collects, syncs the linked order, returns the order total.
  perform set_config('request.jwt.claim.sub',t.du::text,true);
  r:=public.confirm_cash_collection('ride',t.r2);
  assert r->>'ok'='true' and r->>'code'='COLLECTED' and (r->>'amount')::numeric=95, 'ride collection returns order total: '||r::text;
  assert (select payment_status from public.rides where id=t.r2)='paid', 'ride paid';
  assert (select payment_status from public.orders where id=t.o2)='paid', 'linked order synced';
  assert (select count(*) from public.audit_log where action='CASH_COLLECTED' and resource='ride' and resource_id=t.r2::text)=1,
    'exactly one ride audit row';
  assert (select count(*) from public.audit_log where action='CASH_COLLECTED' and resource='order' and resource_id=t.o2::text)=1,
    'partner order audit row included';
  assert (select (after->>'amount')::numeric from public.audit_log
          where action='CASH_COLLECTED' and resource='ride' and resource_id=t.r2::text)=95,
    'ride audit amount is the order total';
  assert (select (after->>'amount')::numeric from public.audit_log
          where action='CASH_COLLECTED' and resource='order' and resource_id=t.o2::text)=95,
    'partner order audit amount is also the order total';
  r:=public.driver_cash_collection_state(t.r2);
  assert (r->>'collected')::boolean=true, 'cash state reflects collection';

  -- Pure courier ride: amount is the fare.
  r:=public.confirm_cash_collection('ride',t.r3);
  assert r->>'ok'='true' and (r->>'amount')::numeric=40, 'courier fare amount';

  -- ── Guard rails unchanged.
  r:=public.confirm_cash_collection('order',t.o3);
  assert r->>'ok'='false' and r->>'code'='NOT_CASH', 'non-cash rejected';
  r:=public.confirm_cash_collection('order',t.o4);
  assert r->>'ok'='false' and r->>'code'='INVALID_LIFECYCLE', 'pending order cannot be collected';

  -- ── #73a: refunded partner is never resurrected, is surfaced.
  r:=public.confirm_cash_collection('order',t.o6);
  assert r->>'ok'='true' and r->>'code'='COLLECTED', 'order with refunded ride still collects: '||r::text;
  assert (select payment_status from public.orders where id=t.o6)='paid', 'order o6 paid';
  assert (select payment_status from public.rides where id=t.r6)='refunded', 'refunded ride NOT resurrected';
  assert (select cash_collected_at from public.rides where id=t.r6) is null, 'refunded ride not stamped';
  assert jsonb_array_length(r->'pair_warnings')=1, 'refunded partner surfaced: '||r::text;
  assert (select count(*) from public.audit_log where action='CASH_COLLECTED' and resource='ride' and resource_id=t.r6::text)=0,
    'no audit for a skipped partner';
  assert (select count(*) from public.audit_log where action='CASH_PAIR_MISMATCH' and resource='order' and resource_id=t.o6::text)=1,
    'refunded pair reaches the reconciliation surface';

  -- ── #73b: non-cash partner is never stamped cash-collected.
  r:=public.confirm_cash_collection('order',t.o7);
  assert r->>'ok'='true' and r->>'code'='COLLECTED', 'order with wallet ride collects: '||r::text;
  assert (select payment_status from public.rides where id=t.r7)='pending', 'wallet ride untouched';
  assert (select cash_collected_at from public.rides where id=t.r7) is null, 'wallet ride not stamped';
  assert jsonb_array_length(r->'pair_warnings')=1, 'non-cash partner surfaced: '||r::text;
  assert (select count(*) from public.audit_log where action='CASH_PAIR_MISMATCH' and resource='order' and resource_id=t.o7::text)=1,
    'non-cash pair reaches the reconciliation surface';

  -- ── #73 reverse: refunded ORDER partner is never resurrected from a ride.
  r:=public.confirm_cash_collection('ride',t.r12);
  assert r->>'ok'='true' and r->>'code'='COLLECTED', 'ride with refunded order collects: '||r::text;
  assert (select payment_status from public.rides where id=t.r12)='paid', 'ride r12 paid';
  assert (select payment_status from public.orders where id=t.o10)='refunded', 'refunded order NOT resurrected';
  assert (select cash_collected_at from public.orders where id=t.o10) is null, 'refunded order not stamped';
  assert jsonb_array_length(r->'pair_warnings')=1, 'refunded order surfaced: '||r::text;
  assert (select count(*) from public.audit_log where action='CASH_PAIR_MISMATCH' and resource='ride' and resource_id=t.r12::text)=1,
    'reverse mismatch reaches the reconciliation surface';

  -- ── Historical null-stamp compatibility: replay heals stamp + audit.
  assert (select cash_collected_at from public.rides where id=t.r8) is null, 'fixture starts unstamped';
  r:=public.confirm_cash_collection('ride',t.r8);
  assert r->>'ok'='true' and r->>'code'='ALREADY_COLLECTED', 'historical paid ride replays: '||r::text;
  assert (select cash_collected_at from public.rides where id=t.r8) is not null, 'replay heals the missing stamp';
  assert (select count(*) from public.audit_log where action='CASH_COLLECTED' and resource='ride' and resource_id=t.r8::text)=1,
    'replay heals the missing audit row';

  -- ── #73 follow-up: replay from the OPPOSITE resource heals the partner stamp.
  r:=public.confirm_cash_collection('order',t.o8);
  assert r->>'ok'='true' and r->>'code'='ALREADY_COLLECTED', 'paid order replays: '||r::text;
  assert (select cash_collected_at from public.orders where id=t.o8) is not null, 'order stamp healed';
  assert (select cash_collected_at from public.rides where id=t.r10) is not null,
    'partner ride stamp healed from the order reference';
  assert (select count(*) from public.audit_log where action='CASH_COLLECTED' and resource='ride' and resource_id=t.r10::text)=1,
    'partner ride audit healed';
  assert (select (after->>'amount')::numeric from public.audit_log
          where action='CASH_COLLECTED' and resource='ride' and resource_id=t.r10::text)=115,
    'already-paid partner ride audit amount is the order total, not the fare';
  r:=public.confirm_cash_collection('ride',t.r11);
  assert r->>'ok'='true' and r->>'code'='ALREADY_COLLECTED', 'paid ride replays: '||r::text;
  assert (select cash_collected_at from public.rides where id=t.r11) is not null, 'ride stamp healed';
  assert (select cash_collected_at from public.orders where id=t.o9) is not null,
    'partner order stamp healed from the ride reference';
  assert (select count(*) from public.audit_log where action='CASH_COLLECTED' and resource='order' and resource_id=t.o9::text)=1,
    'partner order audit healed';
  assert (select (after->>'amount')::numeric from public.audit_log
          where action='CASH_COLLECTED' and resource='order' and resource_id=t.o9::text)=105,
    'already-paid partner order audit amount is the order total';

  -- ── collected_by is never invented: stamp present + by NULL stays NULL.
  r:=public.confirm_cash_collection('ride',t.r13);
  assert r->>'ok'='true' and r->>'code'='ALREADY_COLLECTED', 'stamped ride replays: '||r::text;
  assert (select cash_collected_at from public.rides where id=t.r13)='2026-11-20 10:00+00'::timestamptz,
    'existing stamp untouched';
  assert (select cash_collected_by from public.rides where id=t.r13) is null,
    'unknown historical collector stays NULL';
  assert (select count(*) from public.audit_log where action='CASH_COLLECTED' and resource='ride' and resource_id=t.r13::text)=1,
    'audit row healed for the stamped ride';

  -- ── #83: paid non-cash and refunded service bookings are refused.
  r:=public.confirm_cash_collection('service_booking',t.sb1);
  assert r->>'ok'='false' and r->>'code'='NOT_CASH', 'paid wallet booking refused: '||r::text;
  assert (select cash_collected_at from public.service_bookings where id=t.sb1) is null,
    'no cash stamp on a non-cash booking';
  assert (select count(*) from public.audit_log where action='CASH_COLLECTED' and resource='service_booking' and resource_id=t.sb1::text)=0,
    'no cash audit for a non-cash booking';
  r:=public.confirm_cash_collection('service_booking',t.sb2);
  assert r->>'ok'='false' and r->>'code'='INVALID_STATUS' and r->>'current_status'='refunded',
    'refunded cash booking refused: '||r::text;
  assert (select payment_status from public.service_bookings where id=t.sb2)='refunded',
    'refunded booking not resurrected';

  -- ── Security LOW: stamped booking + NULL collector stays NULL on replay.
  r:=public.confirm_cash_collection('service_booking',t.sb3);
  assert r->>'ok'='true' and r->>'code'='ALREADY_COLLECTED', 'stamped booking replays: '||r::text;
  assert (select cash_collected_at from public.service_bookings where id=t.sb3)='2026-11-20 08:00+00'::timestamptz,
    'booking stamp untouched';
  assert (select cash_collected_by from public.service_bookings where id=t.sb3) is null,
    'booking collector not invented';
end $$;

-- ── Rating gate (RLS): cash ride is rateable only after collection.
do $$
declare
  t record;
begin
  select * into t from zz_cash_ctx;
  insert into public.rides(id,rider_id,driver_id,service_type,ride_type,status,payment_status,payment_method,fare,pickup_latitude,pickup_longitude,dropoff_latitude,dropoff_longitude)
  values ('dddddddd-0000-4000-8000-000000000392',t.c,t.drv,'courier','motorcycle','completed','pending','cash',25,0,0,0.001,0.001);
end $$;

grant select on zz_cash_ctx to authenticated;
set local role authenticated;
do $$
declare
  t record; v_blocked boolean;
begin
  select * into t from zz_cash_ctx;
  perform set_config('request.jwt.claim.sub',t.c::text,true);

  -- Uncollected cash ride: WITH CHECK must reject the rating.
  v_blocked:=false;
  begin
    insert into public.ride_ratings(ride_id,rater_id,ratee_role,stars,comment)
    values ('dddddddd-0000-4000-8000-000000000392',t.c,'driver',5,'قبل التحصيل');
  exception when insufficient_privilege or check_violation then v_blocked:=true;
  end;
  assert v_blocked, 'rating must wait for cash collection';

  -- The RPC path refuses too.
  assert (select (public.rate_ride('dddddddd-0000-4000-8000-000000000392',5)->>'reason')='CASH_NOT_COLLECTED'),
    'rate_ride gated on collection';

  -- rate_ride refuses an incomplete ride (completion check restored).
  assert (select (public.rate_ride(t.r9,5)->>'reason')='RIDE_NOT_COMPLETED'),
    'rate_ride requires a completed ride';

  -- Collected cash ride (r1): rating allowed.
  insert into public.ride_ratings(ride_id,rater_id,ratee_role,stars,comment)
  values (t.r1,t.c,'driver',5,'ممتاز');
  assert (select count(*) from public.ride_ratings where ride_id=t.r1 and rater_id=t.c)=1, 'rating lands after collection';

  -- rate_ride RPC on the collected ride succeeds.
  assert (select (public.rate_ride(t.r1,4)->>'ok')='true'), 'rate_ride allowed after collection';

  -- Historical paid ride healed by the replay above: RLS accepts its rating.
  insert into public.ride_ratings(ride_id,rater_id,ratee_role,stars)
  values (t.r8,t.c,'driver',5);
  assert (select count(*) from public.ride_ratings where ride_id=t.r8)=1,
    'healed historical ride is rateable';
end $$;
reset role;

-- After the captain collects the blocked ride, the customer can rate it.
do $$
declare
  t record; r jsonb;
begin
  select * into t from zz_cash_ctx;
  perform set_config('request.jwt.claim.sub',t.du::text,true);
  r:=public.confirm_cash_collection('ride','dddddddd-0000-4000-8000-000000000392');
  assert r->>'ok'='true', 'driver collects the gated ride';
end $$;
set local role authenticated;
do $$
declare
  t record;
begin
  select * into t from zz_cash_ctx;
  perform set_config('request.jwt.claim.sub',t.c::text,true);
  insert into public.ride_ratings(ride_id,rater_id,ratee_role,stars)
  values ('dddddddd-0000-4000-8000-000000000392',t.c,'driver',4);
  assert (select count(*) from public.ride_ratings where ride_id='dddddddd-0000-4000-8000-000000000392')=1,
    'rating allowed after collection';
end $$;
reset role;


-- ── Backfill combinations (#94): the migration's backfill statements run
-- verbatim inside this rollback transaction over fixed-id fixtures.
do $$
declare
  t record;
begin
  select * into t from zz_cash_ctx;

  -- A: paid cash pair, both stamps null → both stamped, one audit each,
  --    amount = order total on both.
  insert into public.orders(id,user_id,merchant_id,driver_id,status,payment_status,payment_method,subtotal,delivery_fee,total_amount,cash_collected_at)
  values ('bbbb3920-0000-4000-8000-0000000000a1',t.c,t.merch,t.drv,'delivered','paid','cash',100,15,115,NULL);
  insert into public.rides(id,rider_id,driver_id,order_id,merchant_id,service_type,ride_type,status,payment_status,payment_method,fare,cash_collected_at,completed_at,pickup_latitude,pickup_longitude,dropoff_latitude,dropoff_longitude)
  values ('bbbb3920-0000-4000-8000-0000000000a2',t.c,t.drv,'bbbb3920-0000-4000-8000-0000000000a1',t.merch,'food_delivery','motorcycle','completed','paid','cash',15,NULL,'2026-11-19 12:00+00',0,0,0.001,0.001);

  -- B: null stamp but a CASH_COLLECTED audit already exists → stamped, and
  --    the pre-existing audit is the only one afterwards.
  insert into public.rides(id,rider_id,driver_id,service_type,ride_type,status,payment_status,payment_method,fare,cash_collected_at,completed_at,pickup_latitude,pickup_longitude,dropoff_latitude,dropoff_longitude)
  values ('bbbb3920-0000-4000-8000-0000000000b1',t.c,t.drv,'courier','motorcycle','completed','paid','cash',40,NULL,'2026-11-19 13:00+00',0,0,0.001,0.001);
  insert into public.audit_log(actor,actor_role,scope,action,resource,resource_id,after)
  values (t.du,'driver','GLOBAL','CASH_COLLECTED','ride','bbbb3920-0000-4000-8000-0000000000b1',jsonb_build_object('amount',40));

  -- C: cancelled paid cash ride → untouched.
  insert into public.rides(id,rider_id,driver_id,service_type,ride_type,status,payment_status,payment_method,fare,cash_collected_at,completed_at,pickup_latitude,pickup_longitude,dropoff_latitude,dropoff_longitude)
  values ('bbbb3920-0000-4000-8000-0000000000c1',t.c,t.drv,'courier','motorcycle','cancelled','paid','cash',30,NULL,NULL,0,0,0.001,0.001);

  -- D: completed but no completed_at → stamp stays null, no audit.
  insert into public.rides(id,rider_id,driver_id,service_type,ride_type,status,payment_status,payment_method,fare,cash_collected_at,completed_at,pickup_latitude,pickup_longitude,dropoff_latitude,dropoff_longitude)
  values ('bbbb3920-0000-4000-8000-0000000000d1',t.c,t.drv,'courier','motorcycle','completed','paid','cash',25,NULL,NULL,0,0,0.001,0.001);

  -- E: stamp already present (live pre-392 collection), no audit → the
  --    backfill neither re-stamps nor audits it.
  insert into public.rides(id,rider_id,driver_id,service_type,ride_type,status,payment_status,payment_method,fare,cash_collected_at,completed_at,pickup_latitude,pickup_longitude,dropoff_latitude,dropoff_longitude)
  values ('bbbb3920-0000-4000-8000-0000000000e1',t.c,t.drv,'courier','motorcycle','completed','paid','cash',18,'2026-11-18 09:00+00','2026-11-18 09:00+00',0,0,0.001,0.001);

  -- F: delivered paid cash order whose only linked ride has no
  --    completed_at → order stamp stays null, no audit.
  insert into public.orders(id,user_id,merchant_id,driver_id,status,payment_status,payment_method,subtotal,delivery_fee,total_amount,cash_collected_at)
  values ('bbbb3920-0000-4000-8000-0000000000f1',t.c,t.merch,t.drv,'delivered','paid','cash',50,15,65,NULL);
  insert into public.rides(id,rider_id,driver_id,order_id,merchant_id,service_type,ride_type,status,payment_status,payment_method,fare,cash_collected_at,completed_at,pickup_latitude,pickup_longitude,dropoff_latitude,dropoff_longitude)
  values ('bbbb3920-0000-4000-8000-0000000000f2',t.c,t.drv,'bbbb3920-0000-4000-8000-0000000000f1',t.merch,'food_delivery','motorcycle','completed','paid','cash',15,NULL,NULL,0,0,0.001,0.001);
end $$;

-- The migration's backfill block, verbatim (temp tables are this
-- transaction's own; everything rolls back).
CREATE TEMPORARY TABLE IF NOT EXISTS pg_temp.zz_392_bf_rides(id uuid PRIMARY KEY, amount numeric) ON COMMIT DROP;
CREATE TEMPORARY TABLE IF NOT EXISTS pg_temp.zz_392_bf_orders(id uuid PRIMARY KEY, amount numeric) ON COMMIT DROP;
DELETE FROM pg_temp.zz_392_bf_rides;
DELETE FROM pg_temp.zz_392_bf_orders;

WITH stamped AS (
  UPDATE public.rides r
     SET cash_collected_at = r.completed_at
   WHERE r.payment_method = 'cash'
     AND r.payment_status = 'paid'
     AND r.status = 'completed'
     AND r.completed_at IS NOT NULL
     AND r.cash_collected_at IS NULL
   RETURNING r.id, r.fare, r.order_id
)
INSERT INTO pg_temp.zz_392_bf_rides (id, amount)
SELECT s.id, COALESCE(o.total_amount, s.fare)
  FROM stamped s
  LEFT JOIN public.orders o ON o.id = s.order_id;

WITH stamped AS (
  UPDATE public.orders o
     SET cash_collected_at = r.completed_at
    FROM (SELECT order_id, min(completed_at) AS completed_at
            FROM public.rides
           WHERE status = 'completed' AND completed_at IS NOT NULL
           GROUP BY order_id) r
   WHERE r.order_id = o.id
     AND o.payment_method = 'cash'
     AND o.payment_status = 'paid'
     AND o.status = 'delivered'
     AND o.cash_collected_at IS NULL
   RETURNING o.id, o.total_amount
)
INSERT INTO pg_temp.zz_392_bf_orders (id, amount)
SELECT id, total_amount FROM stamped;

INSERT INTO public.audit_log (actor, actor_role, scope, action, resource, resource_id, after, reason)
SELECT NULL, 'system', 'GLOBAL', 'CASH_COLLECTED', 'ride', b.id::text,
       jsonb_build_object('amount', b.amount, 'backfill', true),
       'backfill_392'
  FROM pg_temp.zz_392_bf_rides b
 WHERE NOT EXISTS (SELECT 1 FROM public.audit_log a
                    WHERE a.action = 'CASH_COLLECTED' AND a.resource = 'ride' AND a.resource_id = b.id::text);

INSERT INTO public.audit_log (actor, actor_role, scope, action, resource, resource_id, after, reason)
SELECT NULL, 'system', 'GLOBAL', 'CASH_COLLECTED', 'order', b.id::text,
       jsonb_build_object('amount', b.amount, 'backfill', true),
       'backfill_392'
  FROM pg_temp.zz_392_bf_orders b
 WHERE NOT EXISTS (SELECT 1 FROM public.audit_log a
                    WHERE a.action = 'CASH_COLLECTED' AND a.resource = 'order' AND a.resource_id = b.id::text);

do $$
begin
  -- A: both partners stamped from the real completed_at; one audit each at
  --    the order total.
  assert (select cash_collected_at from public.rides where id='bbbb3920-0000-4000-8000-0000000000a2')='2026-11-19 12:00+00'::timestamptz,
    'A: ride stamped from completed_at';
  assert (select cash_collected_at from public.orders where id='bbbb3920-0000-4000-8000-0000000000a1')='2026-11-19 12:00+00'::timestamptz,
    'A: order stamped from the linked ride completed_at';
  assert (select count(*) from public.audit_log where action='CASH_COLLECTED' and resource='ride' and resource_id='bbbb3920-0000-4000-8000-0000000000a2')=1
     and (select (after->>'amount')::numeric from public.audit_log where action='CASH_COLLECTED' and resource='ride' and resource_id='bbbb3920-0000-4000-8000-0000000000a2')=115,
    'A: one ride audit at the order total';
  assert (select count(*) from public.audit_log where action='CASH_COLLECTED' and resource='order' and resource_id='bbbb3920-0000-4000-8000-0000000000a1')=1
     and (select (after->>'amount')::numeric from public.audit_log where action='CASH_COLLECTED' and resource='order' and resource_id='bbbb3920-0000-4000-8000-0000000000a1')=115,
    'A: one order audit at the order total';

  -- B: stamped, and the pre-existing audit is the only one (#94).
  assert (select cash_collected_at from public.rides where id='bbbb3920-0000-4000-8000-0000000000b1')='2026-11-19 13:00+00'::timestamptz,
    'B: ride stamped';
  assert (select count(*) from public.audit_log where action='CASH_COLLECTED' and resource='ride' and resource_id='bbbb3920-0000-4000-8000-0000000000b1')=1,
    'B: exactly one audit remains — the backfill did not duplicate it';
  assert (select count(*) from public.audit_log where action='CASH_COLLECTED' and resource='ride' and resource_id='bbbb3920-0000-4000-8000-0000000000b1' and reason='backfill_392')=0,
    'B: the surviving audit is the original, not a backfill row';

  -- C/D/E/F: untouched combinations.
  assert (select cash_collected_at from public.rides where id='bbbb3920-0000-4000-8000-0000000000c1') is null, 'C: cancelled ride untouched';
  assert (select cash_collected_at from public.rides where id='bbbb3920-0000-4000-8000-0000000000d1') is null, 'D: no completed_at, no stamp';
  assert (select cash_collected_at from public.rides where id='bbbb3920-0000-4000-8000-0000000000e1')='2026-11-18 09:00+00'::timestamptz, 'E: existing stamp untouched';
  assert (select count(*) from public.audit_log where action='CASH_COLLECTED' and resource_id in
    ('bbbb3920-0000-4000-8000-0000000000c1','bbbb3920-0000-4000-8000-0000000000d1','bbbb3920-0000-4000-8000-0000000000e1',
     'bbbb3920-0000-4000-8000-0000000000f1','bbbb3920-0000-4000-8000-0000000000f2'))=0,
    'C/D/E/F: no audit rows for unstamped or already-stamped rows';
  assert (select cash_collected_at from public.orders where id='bbbb3920-0000-4000-8000-0000000000f1') is null,
    'F: order without a completed linked ride stays null';
end $$;

-- ── Full ledger snapshot: no earnings/commission/merchant rows appeared.
do $$
declare s record;
begin
  select * into s from zz_cash_ledger_snap;
  assert (select count(*) from public.driver_obligations)=s.obligations, 'driver_obligations unchanged';
  assert (select count(*) from public.merchant_ledger)=s.merchant_ledger, 'merchant_ledger unchanged';
  assert (select count(*) from public.platform_commissions)=s.commissions, 'platform_commissions unchanged';
  assert (select count(*) from public.driver_earnings)=s.earnings, 'driver_earnings unchanged';
end $$;

select 'PASS: oracle closed, completed-handoff gate both paths, never-resurrect sync, replay heals, per-resource audit, historical null-stamp, rating gate + completion check, no ledger writes' as result;
rollback;
