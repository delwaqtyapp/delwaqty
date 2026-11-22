-- Staging rollback-only. Requires migration 393. No outbound messaging.
-- Owner-controlled cancellation + refusal penalties: owner-only setters and
-- table guards, singleton lifecycle (no client DELETE of the default row),
-- trigger-level audit (RPC and direct UPDATE each produce exactly one row),
-- and cancel_order / report_delivery_refusal reading the configured days.
-- Authorization negatives run under SET ROLE authenticated so real RLS and
-- trigger paths are exercised, not only JWT claims.
begin;

-- ================= fixtures (postgres, no claims) =================
create temporary table _t393(owner_id uuid, admin_id uuid, region_id uuid,
  cust_a uuid, cust_b uuid, merch_owner uuid, store uuid, product uuid,
  order_a uuid, order_b uuid, cust_c uuid, driver_u uuid, driver_id uuid,
  order_c uuid, order_d uuid, order_old uuid);
insert into _t393
select gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
       gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
       gen_random_uuid(), gen_random_uuid(), null, null,
       gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
       null, null, null;

insert into auth.users(id,email,raw_user_meta_data)
select owner_id,'zz-test-393-owner@example.invalid','{"full_name":"zz-test-393-owner","user_type":"owner"}'::jsonb from _t393 union all
select admin_id,'zz-test-393-admin@example.invalid','{"full_name":"zz-test-393-admin","user_type":"admin"}'::jsonb from _t393 union all
select cust_a,'zz-test-393-cust-a@example.invalid','{"full_name":"zz-test-393-cust-a","user_type":"customer"}'::jsonb from _t393 union all
select cust_b,'zz-test-393-cust-b@example.invalid','{"full_name":"zz-test-393-cust-b","user_type":"customer"}'::jsonb from _t393 union all
select merch_owner,'zz-test-393-merchant@example.invalid','{"full_name":"zz-test-393-merchant","user_type":"merchant"}'::jsonb from _t393 union all
select cust_c,'zz-test-393-cust-c@example.invalid','{"full_name":"zz-test-393-cust-c","user_type":"customer"}'::jsonb from _t393 union all
select driver_u,'zz-test-393-driver@example.invalid','{"full_name":"zz-test-393-driver","user_type":"driver"}'::jsonb from _t393;

update public.users set role='owner',user_type='owner',verification_status='approved' where id=(select owner_id from _t393);
update public.users set role='admin',user_type='admin',verification_status='approved' where id=(select admin_id from _t393);
update public.users set role='customer',user_type='customer',verification_status='approved' where id in (select cust_a from _t393 union all select cust_b from _t393 union all select cust_c from _t393);
update public.users set role='merchant',user_type='merchant',verification_status='approved' where id=(select merch_owner from _t393);

-- COUNTRY admin: active admin + descendants assignment on a root region
-- (parent_region_id IS NULL), matching _is_country_admin_uid (356).
insert into public.regions(id,code,type,name_ar,name_en)
select region_id,'ZZ393','city','منطقة اختبار 393','zz-test-393-region' from _t393;
insert into public.admin_management(admin_id,supervisor_id,is_active)
select admin_id,owner_id,true from _t393;
insert into public.admin_region_assignments(admin_id,region_id,scope)
select admin_id,region_id,'descendants' from _t393;

insert into public.merchants(id,owner_user_id,name,status,is_open,latitude,longitude,delivery_fee)
select store,merch_owner,'zz-test-393-store','active',true,0,0,15 from _t393;
insert into public.products(id,merchant_id,name,price,is_available,stock_quantity)
select product,store,'zz-test-393-product',25,true,100 from _t393;
insert into public.drivers(id,user_id,full_name,is_active,is_verified,verification_status)
select driver_id,driver_u,'zz-test-393-driver',true,true,'verified' from _t393;

-- Deterministic seed (no claim set -> lifecycle/audit triggers skip).
update public.platform_settings
set cancel_suspension_days = 5, refusal_suspension_days = 5
where id = 'default';

-- Prior monthly activity: cust_b has 1 cancel, cust_a has 2 cancels,
-- cust_c has 1 refusal (on an older order: one report per order).
insert into public.orders(user_id,merchant_id,status,subtotal,total_amount,cancelled_by,cancelled_at)
select cust_b,store,'cancelled',0,0,'customer',now() from _t393 union all
select cust_a,store,'cancelled',0,0,'customer',now() from _t393 union all
select cust_a,store,'cancelled',0,0,'customer',now() from _t393;
insert into public.orders(user_id,merchant_id,driver_id,status,subtotal,total_amount)
select cust_c,store,driver_id,'delivering',0,0 from _t393 union all
select cust_c,store,driver_id,'delivering',0,0 from _t393 union all
select cust_c,store,null,'cancelled',0,0 from _t393;
update _t393 set
  order_c = (select id from public.orders where user_id = cust_c and status='delivering' order by id asc limit 1),
  order_d = (select id from public.orders where user_id = cust_c and status='delivering' order by id desc limit 1),
  order_old = (select id from public.orders where user_id = cust_c and status='cancelled' limit 1);
insert into public.refusal_events(user_id, order_id)
select cust_c, order_old from _t393;

-- Real cancellable orders for cust_a and cust_b via the canonical RPC.
do $$
declare t record; r jsonb;
begin
  select * into t from _t393;
  perform set_config('request.jwt.claim.sub', t.cust_a::text, true);
  r := public.create_order(t.store, jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',1)),
                           'zz-test-address',0.001,0.001,'cash',null,null,'zz-test-393-a');
  assert r->>'ok' = 'true', 'customer A order created';
  update _t393 set order_a = (r->>'order_id')::uuid;
  perform set_config('request.jwt.claim.sub', t.cust_b::text, true);
  r := public.create_order(t.store, jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',1)),
                           'zz-test-address',0.001,0.001,'cash',null,null,'zz-test-393-b');
  assert r->>'ok' = 'true', 'customer B order created';
  update _t393 set order_b = (r->>'order_id')::uuid;
  perform set_config('request.jwt.claim.sub', '', true);
end $$;

-- ===== authorization negatives under the REAL authenticated role =====
grant select on _t393 to authenticated;
set local role authenticated;
do $neg$
declare
  t record;
begin
  select * into t from _t393;

  -- No-auth: setters reject.
  perform set_config('request.jwt.claim.sub', '', true);
  begin
    perform public.set_cancel_suspension_days(9);
    raise exception 'TEST_FAIL_NOAUTH_SETTER_ACCEPTED';
  exception when others then
    if sqlerrm <> 'UNAUTHENTICATED' then raise; end if;
  end;

  -- Plain customer cannot set.
  perform set_config('request.jwt.claim.sub', t.cust_a::text, true);
  begin
    perform public.set_cancel_suspension_days(9);
    raise exception 'TEST_FAIL_CUSTOMER_SETTER_ACCEPTED';
  exception when others then
    if sqlerrm <> 'Only the platform owner can change the cancellation suspension duration' then raise; end if;
  end;

  -- Non-owner COUNTRY admin, real RLS (367 policies) + triggers.
  perform set_config('request.jwt.claim.sub', t.admin_id::text, true);
  begin
    perform public.set_cancel_suspension_days(9, 'zz-test');
    raise exception 'TEST_FAIL_ADMIN_CANCEL_SETTER_ACCEPTED';
  exception when others then
    if sqlerrm <> 'Only the platform owner can change the cancellation suspension duration' then raise; end if;
  end;
  begin
    perform public.set_refusal_suspension_days(9);
    raise exception 'TEST_FAIL_ADMIN_REFUSAL_SETTER_ACCEPTED';
  exception when others then
    if sqlerrm <> 'Only the platform owner can change the refusal suspension duration' then raise; end if;
  end;
  begin
    update public.platform_settings set cancel_suspension_days = 9 where id = 'default';
    raise exception 'TEST_FAIL_ADMIN_DIRECT_UPDATE_ACCEPTED';
  exception when others then
    if sqlerrm <> 'Only the platform owner can change the cancellation suspension duration' then raise; end if;
  end;
  begin
    update public.platform_settings set refusal_suspension_days = 9 where id = 'default';
    raise exception 'TEST_FAIL_ADMIN_REFUSAL_DIRECT_UPDATE_ACCEPTED';
  exception when others then
    if sqlerrm <> 'Only the platform owner can change the refusal suspension duration' then raise; end if;
  end;

  -- #74: country-admin DELETE of the singleton is blocked.
  begin
    delete from public.platform_settings where id = 'default';
    raise exception 'TEST_FAIL_ADMIN_DELETE_ACCEPTED';
  exception when others then
    if sqlerrm <> 'The default platform settings row cannot be deleted' then raise; end if;
  end;
  -- Shadow settings rows cannot be created by a non-owner.
  begin
    insert into public.platform_settings(id) values ('zz393-shadow');
    raise exception 'TEST_FAIL_ADMIN_SHADOW_INSERT_ACCEPTED';
  exception when others then
    if sqlerrm <> 'Only the platform owner can create platform settings rows' then raise; end if;
  end;
end $neg$;
reset role;

-- Singleton survived every attempt above.
do $$
begin
  assert (select cancel_suspension_days from public.platform_settings where id='default') = 5
     and (select refusal_suspension_days from public.platform_settings where id='default') = 5,
    'singleton row intact after admin attacks';
end $$;

-- ===== owner paths + trigger-level audit (postgres claims) =====
do $owner$
declare
  t record;
  v_days int;
begin
  select * into t from _t393;
  perform set_config('request.jwt.claim.sub', t.owner_id::text, true);

  -- Range validation (both setters).
  begin
    perform public.set_cancel_suspension_days(0);
    raise exception 'TEST_FAIL_ZERO_DAYS_ACCEPTED';
  exception when others then
    if sqlerrm <> 'Suspension duration must be between 1 and 365 days' then raise; end if;
  end;
  begin
    perform public.set_refusal_suspension_days(366);
    raise exception 'TEST_FAIL_366_DAYS_ACCEPTED';
  exception when others then
    if sqlerrm <> 'Suspension duration must be between 1 and 365 days' then raise; end if;
  end;

  -- RPC path: exactly ONE audit row, with actor + old + new + reason.
  v_days := public.set_cancel_suspension_days(7, 'zz-test-393 extend');
  assert v_days = 7, 'cancel setter returns new value';
  assert (select count(*) from public.activity_logs
          where action = 'PENALTY_CONFIG_CHANGED'
            and details->>'field' = 'cancel_suspension_days'
            and details->>'new_value' = '7'
            and details->>'old_value' = '5'
            and details->>'reason' = 'zz-test-393 extend'
            and user_id = t.owner_id::text) = 1,
    'RPC path writes exactly one audit row';

  -- Direct owner UPDATE: also exactly ONE audit row (trigger, not setter).
  update public.platform_settings set cancel_suspension_days = 9 where id = 'default';
  assert (select count(*) from public.activity_logs
          where action = 'PENALTY_CONFIG_CHANGED'
            and details->>'field' = 'cancel_suspension_days'
            and details->>'new_value' = '9'
            and details->>'old_value' = '7'
            and user_id = t.owner_id::text) = 1,
    'direct owner UPDATE writes exactly one audit row';

  -- Refusal setter: exactly one audit row.
  v_days := public.set_refusal_suspension_days(4, 'zz-test-393 refusal shorten');
  assert v_days = 4, 'refusal setter returns new value';
  assert (select count(*) from public.activity_logs
          where action = 'PENALTY_CONFIG_CHANGED'
            and details->>'field' = 'refusal_suspension_days'
            and details->>'new_value' = '4'
            and details->>'old_value' = '5'
            and user_id = t.owner_id::text) = 1,
    'refusal RPC path writes exactly one audit row';

  -- Owner cannot DELETE the singleton either (lifecycle enforcement).
  begin
    delete from public.platform_settings where id = 'default';
    raise exception 'TEST_FAIL_OWNER_DELETE_ACCEPTED';
  exception when others then
    if sqlerrm <> 'The default platform settings row cannot be deleted' then raise; end if;
  end;

  perform set_config('request.jwt.claim.sub', '', true);
end $owner$;

-- ===== functional flows at the configured durations =====
do $flow$
declare
  t record;
  r jsonb;
begin
  select * into t from _t393;

  -- 2nd monthly cancel executes WITHOUT suspension (counting unchanged).
  perform set_config('request.jwt.claim.sub', t.cust_b::text, true);
  r := public.cancel_order(t.order_b, 'zz-test-393-b');
  assert r->>'ok' = 'true' and r->>'suspended' is null, '2nd monthly cancel does not suspend';

  -- 3rd monthly cancel: executes and suspends for the CONFIGURED 9 days
  -- (left by the direct owner UPDATE above), support message included.
  perform set_config('request.jwt.claim.sub', t.cust_a::text, true);
  r := public.cancel_order(t.order_a, 'zz-test-393-a');
  assert r->>'ok' = 'true' and r->>'suspended' = 'true' and r->>'suspension_days' = '9',
    '3rd monthly cancel suspends for configured days';
  assert exists(
    select 1 from public.sanctions
    where target_user_id = t.cust_a and sanction_type = 'suspension'
      and duration_days = 9
      and end_date between now() + interval '8 days' and now() + interval '10 days'),
    'cancel sanction carries configured duration and end_date';
  assert exists(
    select 1 from public.notifications
    where user_id = t.cust_a and type = 'account'
      and data->>'event' = 'cancel_suspension'
      and data->>'duration_days' = '9'
      and title like '%9 يوم%'
      and body like '%الدعم%'
      and deep_link = '/support'),
    'cancel notification carries configured days, support path and deep link';

  -- Refusal warning quotes the CONFIGURED 4 days; 3rd refusal suspends 4.
  perform set_config('request.jwt.claim.sub', t.driver_u::text, true);
  r := public.report_delivery_refusal(t.order_d, 'zz-test-393 refusal warn');
  assert r->>'action' = 'warning' and r->>'refusal_count' = '2',
    '2nd monthly refusal warns';
  assert exists(
    select 1 from public.notifications
    where user_id = t.cust_c and data->>'event' = 'refusal_warning'
      and body like '%4 يوم%'),
    'warning message carries configured duration';
  r := public.report_delivery_refusal(t.order_c, 'zz-test-393 refusal final');
  assert r->>'action' = 'account_suspended' and r->>'suspension_days' = '4'
     and r->>'order_cancelled' = 'false',
    '3rd monthly refusal suspends for configured days, order stays';
  assert exists(
    select 1 from public.sanctions
    where target_user_id = t.cust_c and sanction_type = 'suspension'
      and duration_days = 4
      and end_date between now() + interval '3 days' and now() + interval '5 days'),
    'refusal sanction carries configured duration';
  assert exists(
    select 1 from public.notifications
    where user_id = t.cust_c and type = 'account'
      and data->>'event' = 'refusal_suspension'
      and data->>'duration_days' = '4'
      and title like '%4 يوم%'),
    'refusal suspension notification carries configured days';

  perform set_config('request.jwt.claim.sub', '', true);
end $flow$;

-- ===== missing singleton row: setters fail loud, cancel falls back to 5 =====
-- Backend context (auth.uid() IS NULL) may delete the row; clients cannot.
delete from public.platform_settings where id = 'default';
do $missing$
declare
  t record;
  r jsonb;
  v_new_order uuid;
  v_cust_d uuid;
begin
  select * into t from _t393;
  perform set_config('request.jwt.claim.sub', t.owner_id::text, true);
  begin
    perform public.set_cancel_suspension_days(5);
    raise exception 'TEST_FAIL_SETTER_ON_MISSING_ROW_ACCEPTED';
  exception when others then
    if sqlerrm <> 'Platform settings row missing' then raise; end if;
  end;
  begin
    perform public.set_refusal_suspension_days(5);
    raise exception 'TEST_FAIL_REFUSAL_SETTER_ON_MISSING_ROW_ACCEPTED';
  exception when others then
    if sqlerrm <> 'Platform settings row missing' then raise; end if;
  end;

  -- cancel_order falls back to the hardcoded 5-day default when the row is
  -- gone (fail-safe), and still works end to end. Fresh customer (cust_a is
  -- already suspended and cannot order).
  v_cust_d := gen_random_uuid();
  insert into auth.users(id,email,raw_user_meta_data)
  values (v_cust_d,'zz-test-393-cust-d@example.invalid','{"full_name":"zz-test-393-cust-d","user_type":"customer"}'::jsonb);
  update public.users set role='customer',user_type='customer',verification_status='approved' where id = v_cust_d;
  insert into public.orders(user_id,merchant_id,status,subtotal,total_amount,cancelled_by,cancelled_at)
  values (v_cust_d,t.store,'cancelled',0,0,'customer',now()),
         (v_cust_d,t.store,'cancelled',0,0,'customer',now());
  perform set_config('request.jwt.claim.sub', v_cust_d::text, true);
  r := public.create_order(t.store, jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',1)),
                           'zz-test-address',0.001,0.001,'cash',null,null,'zz-test-393-d');
  v_new_order := (r->>'order_id')::uuid;
  r := public.cancel_order(v_new_order, 'zz-test-393-d');
  assert r->>'suspended' = 'true' and r->>'suspension_days' = '5',
    'missing settings row falls back to 5 days';
  perform set_config('request.jwt.claim.sub', '', true);
end $missing$;

-- Restore the singleton for any later tests in the same session.
insert into public.platform_settings(id, cancel_suspension_days, refusal_suspension_days)
values ('default', 5, 5);

select 'PASS393: no-auth/customer/country-admin negatives under SET ROLE authenticated, DELETE+shadow-insert blocked, owner audit exactly-one (RPC and direct), range validation, cancel+refusal configured durations, missing-row fail-safe' as result;
rollback;
