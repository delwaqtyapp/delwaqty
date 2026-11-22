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
  o1 uuid, o2 uuid, o3 uuid, o4 uuid, o5 uuid, o6 uuid, o7 uuid,
  r1 uuid, r2 uuid, r3 uuid, r5 uuid, r6 uuid, r7 uuid, r8 uuid, r9 uuid
);
insert into zz_cash_ctx
select gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
       gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
       gen_random_uuid(), gen_random_uuid(),
       gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
       gen_random_uuid(), gen_random_uuid(), gen_random_uuid();

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

-- Full settlement-ledger snapshot: collection must never add rows.
create temporary table zz_cash_ledger_snap as
select (select count(*) from public.driver_obligations) as obligations,
       (select count(*) from public.merchant_ledger) as merchant_ledger,
       (select count(*) from public.platform_commissions) as commissions;

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

  -- ── #73b: non-cash partner is never stamped cash-collected.
  r:=public.confirm_cash_collection('order',t.o7);
  assert r->>'ok'='true' and r->>'code'='COLLECTED', 'order with wallet ride collects: '||r::text;
  assert (select payment_status from public.rides where id=t.r7)='pending', 'wallet ride untouched';
  assert (select cash_collected_at from public.rides where id=t.r7) is null, 'wallet ride not stamped';
  assert jsonb_array_length(r->'pair_warnings')=1, 'non-cash partner surfaced: '||r::text;

  -- ── Historical null-stamp compatibility: replay heals stamp + audit.
  assert (select cash_collected_at from public.rides where id=t.r8) is null, 'fixture starts unstamped';
  r:=public.confirm_cash_collection('ride',t.r8);
  assert r->>'ok'='true' and r->>'code'='ALREADY_COLLECTED', 'historical paid ride replays: '||r::text;
  assert (select cash_collected_at from public.rides where id=t.r8) is not null, 'replay heals the missing stamp';
  assert (select count(*) from public.audit_log where action='CASH_COLLECTED' and resource='ride' and resource_id=t.r8::text)=1,
    'replay heals the missing audit row';
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

-- ── Full ledger snapshot: no earnings/commission/merchant rows appeared.
do $$
declare s record;
begin
  select * into s from zz_cash_ledger_snap;
  assert (select count(*) from public.driver_obligations)=s.obligations, 'driver_obligations unchanged';
  assert (select count(*) from public.merchant_ledger)=s.merchant_ledger, 'merchant_ledger unchanged';
  assert (select count(*) from public.platform_commissions)=s.commissions, 'platform_commissions unchanged';
end $$;

select 'PASS: oracle closed, completed-handoff gate both paths, never-resurrect sync, replay heals, per-resource audit, historical null-stamp, rating gate + completion check, no ledger writes' as result;
rollback;
