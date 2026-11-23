-- Staging rollback-only. Requires migration 398. No outbound messaging.
-- Schedule fixture (day 0=Sunday..6=Saturday, OPENING day):
--   Sat 12:00-01:00 overnight, Sun closed, Mon 09:00-23:00,
--   Tue 00:00-00:00 (24h), Wed 23:30-00:00 (ends at midnight).
-- Dates: 2026-11-21 Sat, 22 Sun, 23 Mon, 24 Tue, 25 Wed, 26 Thu, 27 Fri.
-- Cairo is UTC+2 in late November (DST ended), so +02 instants are local.
begin;
create temporary table _t398(customer_id uuid, merchant_user uuid, writer_user uuid, store uuid, store2 uuid, store3 uuid, sched_store uuid, product3 uuid);
insert into _t398 values(gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid());
insert into public.users(id,email,full_name,role,user_type,verification_status)
select customer_id,'zz-test-398-c@example.invalid','zz-test-398-c','customer','customer','approved' from _t398 union all
select merchant_user,'zz-test-398-m@example.invalid','zz-test-398-m','merchant','merchant','approved' from _t398 union all
select writer_user,'zz-test-398-w@example.invalid','zz-test-398-w','merchant','merchant','approved' from _t398;
insert into public.merchants(id,owner_user_id,name,type,status,is_open)
select store,merchant_user,'zz-test-398-store','restaurant','active',true from _t398 union all
select store2,merchant_user,'zz-test-398-allclosed','restaurant','active',true from _t398 union all
select store3,merchant_user,'zz-test-398-always24','restaurant','active',true from _t398 union all
select sched_store,writer_user,'zz-test-398-writer','restaurant','active',true from _t398;
insert into public.working_hours(merchant_id,day_of_week,open_time,close_time,is_closed)
select store,6,'12:00'::time,'01:00'::time,false from _t398 union all
select store,0,'09:00'::time,'23:00'::time,true from _t398 union all
select store,1,'09:00'::time,'23:00'::time,false from _t398 union all
select store,2,'00:00'::time,'00:00'::time,false from _t398 union all
select store,3,'23:30'::time,'00:00'::time,false from _t398;
insert into public.working_hours(merchant_id,day_of_week,open_time,close_time,is_closed)
select store2,d,'09:00'::time,'23:00'::time,true from _t398, generate_series(0,6) d;
insert into public.working_hours(merchant_id,day_of_week,open_time,close_time,is_closed)
select store3,d,'00:00'::time,'00:00'::time,false from _t398, generate_series(0,6) d;
insert into public.products(id,merchant_id,name,price,is_available,stock_quantity)
select product3,store3,'zz-test-398-product',25,true,100 from _t398;
do $test$
declare
  t record; r jsonb; m uuid; sched_store uuid;
begin
  select * into t from _t398;

  -- Overnight window: evening part open, pre-open closed, spill into the
  -- closed Sunday, close exclusive at the rollover, closed day otherwise.
  assert public.working_hours_open_at(t.store,'2026-11-21 13:00:00+02'), 'sat evening open';
  assert public.working_hours_open_at(t.store,'2026-11-21 23:59:00+02'), 'sat before midnight open';
  assert not public.working_hours_open_at(t.store,'2026-11-21 11:59:00+02'), 'sat pre-open closed';
  assert public.working_hours_open_at(t.store,'2026-11-22 00:30:00+02'), 'overnight spills into closed sunday';
  assert not public.working_hours_open_at(t.store,'2026-11-22 01:00:00+02'), 'close exclusive at rollover';
  assert not public.working_hours_open_at(t.store,'2026-11-22 12:00:00+02'), 'closed sunday stays closed';

  -- Same-day window unchanged: inclusive open, exclusive close.
  assert not public.working_hours_open_at(t.store,'2026-11-23 08:59:00+02'), 'mon pre-open closed';
  assert public.working_hours_open_at(t.store,'2026-11-23 09:00:00+02'), 'mon open inclusive';
  assert public.working_hours_open_at(t.store,'2026-11-23 22:59:00+02'), 'mon evening open';
  assert not public.working_hours_open_at(t.store,'2026-11-23 23:00:00+02'), 'mon close exclusive';

  -- 24h day covers its whole day only; a window ending 00:00 dies at midnight.
  assert public.working_hours_open_at(t.store,'2026-11-24 00:00:00+02'), '24h day at midnight';
  assert public.working_hours_open_at(t.store,'2026-11-24 15:00:00+02'), '24h day afternoon';
  assert not public.working_hours_open_at(t.store,'2026-11-25 03:00:00+02'), '24h day does not spill';
  assert public.working_hours_open_at(t.store,'2026-11-25 23:45:00+02'), 'wed window open';
  assert not public.working_hours_open_at(t.store,'2026-11-26 00:00:00+02'), 'midnight close exclusive';

  -- Day with no row is closed; a merchant with no schedule is unconstrained.
  assert not public.working_hours_open_at(t.store,'2026-11-27 12:00:00+02'), 'friday no row closed';
  assert public.working_hours_open_at(gen_random_uuid(),'2026-11-23 12:00:00+02') is null, 'no schedule unconstrained';

  -- Writer accepts overnight and 24h windows and round-trips them. The
  -- writer user owns exactly one store, so resolve_my_merchant picks it.
  perform set_config('request.jwt.claim.sub',t.writer_user::text,true);
  sched_store := t.sched_store;
  r := public.provider_set_working_hours(jsonb_build_array(
    jsonb_build_object('day',6,'open','12:00','close','01:00','closed',false),
    jsonb_build_object('day',1,'open','00:00','close','00:00','closed',false)));
  assert r->>'ok'='true' and (r->>'rows')::int=2, 'writer accepts overnight and 24h';
  assert exists(select 1 from public.working_hours
    where merchant_id=sched_store and day_of_week=6 and open_time='12:00' and close_time='01:00' and not is_closed),
    'overnight row stored as opening day';
  assert public.working_hours_open_at(sched_store,'2026-11-22 00:30:00+02'), 'written overnight computes open';

  -- Writer still rejects garbage.
  begin
    perform public.provider_set_working_hours(jsonb_build_array(jsonb_build_object('day',7,'open','09:00','close','23:00')));
    raise exception 'TEST_FAIL_DAY7_ACCEPTED';
  exception when others then if sqlerrm not like 'Invalid day of week%' then raise; end if; end;
  begin
    perform public.provider_set_working_hours(jsonb_build_array(jsonb_build_object('day',1,'open','9:00','close','23:00')));
    raise exception 'TEST_FAIL_UNPADDED_ACCEPTED';
  exception when others then if sqlerrm not like 'Invalid time format%' then raise; end if; end;
  begin
    perform public.provider_set_working_hours(jsonb_build_array(jsonb_build_object('day',1,'open','09:00','close','24:00')));
    raise exception 'TEST_FAIL_2400_ACCEPTED';
  exception when others then if sqlerrm not like 'Invalid time format%' then raise; end if; end;

  -- Checkout honors the schedule at any wall-clock time: the always-closed
  -- store rejects, the always-24h store accepts, and a schedule-less store
  -- keeps the old manual-flag-only behavior (covered by the 390 suite).
  perform set_config('request.jwt.claim.sub',t.customer_id::text,true);
  begin
    perform public.create_order(t.store2,jsonb_build_array(jsonb_build_object('product_id',t.product3,'quantity',1)),'zz-test-address',0.001,0.001);
    raise exception 'TEST_FAIL_ALLCLOSED_ACCEPTED';
  exception when others then if sqlerrm<>'MERCHANT_CLOSED' then raise; end if; end;
  r := public.create_order(t.store3,jsonb_build_array(jsonb_build_object('product_id',t.product3,'quantity',1)),'zz-test-address',0.001,0.001,'cash',null,null,'zz-test-398-order');
  assert r->>'ok'='true', 'always-24h store takes orders';

  -- Schedule-less store keeps the manual-flag-only behavior at any time.
  insert into public.merchants(id,owner_user_id,name,type,status,is_open)
  values(gen_random_uuid(),t.merchant_user,'zz-test-398-nosched','restaurant','active',true)
  returning id into m;
  insert into public.products(id,merchant_id,name,price,is_available,stock_quantity)
  values(gen_random_uuid(),m,'zz-test-398-product2',25,true,100)
  returning id into sched_store; -- reuse var as product id
  begin
    perform public.create_order(m,jsonb_build_array(jsonb_build_object('product_id',sched_store,'quantity',1)),'zz-test-address',0.001,0.001,'cash',null,null,'zz-test-398-nosched-open');
  exception when others then
    raise exception 'TEST_FAIL_NOSCHED_OPEN: %', sqlerrm;
  end;
  update public.merchants set is_open=false where id=m;
  begin
    perform public.create_order(m,jsonb_build_array(jsonb_build_object('product_id',sched_store,'quantity',1)),'zz-test-address',0.001,0.001);
    raise exception 'TEST_FAIL_NOSCHED_CLOSED_ACCEPTED';
  exception when others then if sqlerrm<>'MERCHANT_CLOSED' then raise; end if; end;

  -- Grants: authenticated may call it, anon may not.
  assert has_function_privilege('authenticated','public.working_hours_open_at(uuid,timestamp with time zone)','EXECUTE'),
    'authenticated execute granted';
  assert not has_function_privilege('anon','public.working_hours_open_at(uuid,timestamp with time zone)','EXECUTE'),
    'anon execute revoked';

  -- A rejected writer call preserves the previously stored rows.
  perform set_config('request.jwt.claim.sub',t.writer_user::text,true);
  r := public.provider_set_working_hours(jsonb_build_array(
    jsonb_build_object('day',2,'open','10:00','close','22:00','closed',false)));
  assert r->>'ok'='true', 'baseline schedule stored';
  begin
    perform public.provider_set_working_hours(jsonb_build_array(
      jsonb_build_object('day',2,'open','11:00','close','23:00','closed',false),
      jsonb_build_object('day',9,'open','11:00','close','23:00','closed',false)));
    raise exception 'TEST_FAIL_INVALID_WRITER_ACCEPTED';
  exception when others then if sqlerrm not like 'Invalid day of week%' then raise; end if; end;
  assert exists(select 1 from public.working_hours
    where merchant_id=t.sched_store and day_of_week=2 and open_time='10:00' and close_time='22:00'),
    'rejected writer call preserved old rows';
end $test$;
select 'PASS398: overnight spill, midnight and 24h edges, closed-day rollover, same-day parity, writer validation, checkout wiring' result;
rollback;
