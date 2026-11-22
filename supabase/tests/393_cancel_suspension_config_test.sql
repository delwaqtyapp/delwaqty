-- Staging rollback-only. Requires migration 393. No outbound messaging.
-- Owner-controlled cancellation penalty: owner-only config setter, audit,
-- owner-only table guard, and cancel_order reading the configured duration.
begin;
create temporary table _t393(owner_id uuid, admin_id uuid, region_id uuid,
  cust_a uuid, cust_b uuid, merch_owner uuid, store uuid, product uuid,
  order_a uuid, order_b uuid);
insert into _t393
select gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
       gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
       gen_random_uuid(), gen_random_uuid(), null, null;

insert into auth.users(id,email,raw_user_meta_data)
select owner_id,'zz-test-393-owner@example.invalid','{"full_name":"zz-test-393-owner","user_type":"owner"}'::jsonb from _t393 union all
select admin_id,'zz-test-393-admin@example.invalid','{"full_name":"zz-test-393-admin","user_type":"admin"}'::jsonb from _t393 union all
select cust_a,'zz-test-393-cust-a@example.invalid','{"full_name":"zz-test-393-cust-a","user_type":"customer"}'::jsonb from _t393 union all
select cust_b,'zz-test-393-cust-b@example.invalid','{"full_name":"zz-test-393-cust-b","user_type":"customer"}'::jsonb from _t393 union all
select merch_owner,'zz-test-393-merchant@example.invalid','{"full_name":"zz-test-393-merchant","user_type":"merchant"}'::jsonb from _t393;

update public.users set role='owner',user_type='owner',verification_status='approved' where id=(select owner_id from _t393);
update public.users set role='admin',user_type='admin',verification_status='approved' where id=(select admin_id from _t393);
update public.users set role='customer',user_type='customer',verification_status='approved' where id in (select cust_a from _t393 union all select cust_b from _t393);
update public.users set role='merchant',user_type='merchant',verification_status='approved' where id=(select merch_owner from _t393);

-- Scoped (region) admin: active admin_management + a region assignment.
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

do $test$
declare
  t record;
  r jsonb;
  v_days int;
begin
  select * into t from _t393;

  -- Default stays 5.
  assert (select cancel_suspension_days from public.platform_settings where id='default') = 5,
    'default cancel suspension is 5 days';

  -- Negative: plain customer cannot set.
  perform set_config('request.jwt.claim.sub', t.cust_a::text, true);
  begin
    perform public.set_cancel_suspension_days(9);
    raise exception 'TEST_FAIL_CUSTOMER_SETTER_ACCEPTED';
  exception when others then
    if sqlerrm <> 'Only the platform owner can change the cancellation suspension duration' then raise; end if;
  end;

  -- Negative: active scoped (region) admin cannot set via RPC.
  perform set_config('request.jwt.claim.sub', t.admin_id::text, true);
  begin
    perform public.set_cancel_suspension_days(9, 'zz-test');
    raise exception 'TEST_FAIL_SCOPED_ADMIN_SETTER_ACCEPTED';
  exception when others then
    if sqlerrm <> 'Only the platform owner can change the cancellation suspension duration' then raise; end if;
  end;

  -- Negative: scoped admin cannot write the column directly (trigger guard
  -- behind the admin-writable RLS policy).
  begin
    update public.platform_settings set cancel_suspension_days = 9 where id = 'default';
    raise exception 'TEST_FAIL_SCOPED_ADMIN_DIRECT_UPDATE_ACCEPTED';
  exception when others then
    if sqlerrm <> 'Only the platform owner can change the cancellation suspension duration' then raise; end if;
  end;
  assert (select cancel_suspension_days from public.platform_settings where id='default') = 5,
    'blocked direct update left value unchanged';

  -- Owner range validation.
  perform set_config('request.jwt.claim.sub', t.owner_id::text, true);
  begin
    perform public.set_cancel_suspension_days(0);
    raise exception 'TEST_FAIL_ZERO_DAYS_ACCEPTED';
  exception when others then
    if sqlerrm <> 'Suspension duration must be between 1 and 365 days' then raise; end if;
  end;
  begin
    perform public.set_cancel_suspension_days(366);
    raise exception 'TEST_FAIL_366_DAYS_ACCEPTED';
  exception when others then
    if sqlerrm <> 'Suspension duration must be between 1 and 365 days' then raise; end if;
  end;

  -- Owner can extend (and the change is audited).
  v_days := public.set_cancel_suspension_days(7, 'zz-test-393 extend');
  assert v_days = 7, 'setter returns new value';
  assert (select cancel_suspension_days from public.platform_settings where id='default') = 7,
    'owner update persisted';
  assert exists(
    select 1 from public.activity_logs
    where action = 'PENALTY_CONFIG_CHANGED'
      and resource = 'platform_settings' and resource_id = 'default'
      and details->>'field' = 'cancel_suspension_days'
      and details->>'old_value' = '5' and details->>'new_value' = '7'),
    'config change audited';

  -- 2nd monthly cancel executes WITHOUT suspension (counting unchanged).
  insert into public.orders(user_id,merchant_id,status,subtotal,total_amount,cancelled_by,cancelled_at)
  values (t.cust_b,t.store,'cancelled',0,0,'customer',now());
  perform set_config('request.jwt.claim.sub', t.cust_b::text, true);
  r := public.create_order(t.store, jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',1)),
                           'zz-test-address',0.001,0.001,'cash',null,null,'zz-test-393-b');
  assert r->>'ok' = 'true', 'customer B order created';
  t.order_b := (r->>'order_id')::uuid;
  r := public.cancel_order(t.order_b, 'zz-test-393-b');
  assert r->>'ok' = 'true' and r->>'suspended' is null, '2nd monthly cancel does not suspend';

  -- Customer A: two prior cancels this Cairo month; the 3rd executes and
  -- suspends for the CONFIGURED 7 days.
  insert into public.orders(user_id,merchant_id,status,subtotal,total_amount,cancelled_by,cancelled_at)
  values (t.cust_a,t.store,'cancelled',0,0,'customer',now()),
         (t.cust_a,t.store,'cancelled',0,0,'customer',now());
  perform set_config('request.jwt.claim.sub', t.cust_a::text, true);
  r := public.create_order(t.store, jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',1)),
                           'zz-test-address',0.001,0.001,'cash',null,null,'zz-test-393-a');
  assert r->>'ok' = 'true', 'customer A order created';
  t.order_a := (r->>'order_id')::uuid;
  r := public.cancel_order(t.order_a, 'zz-test-393-a');
  assert r->>'ok' = 'true' and r->>'suspended' = 'true' and r->>'suspension_days' = '7',
    '3rd monthly cancel suspends for configured days';

  assert exists(
    select 1 from public.sanctions
    where target_user_id = t.cust_a and sanction_type = 'suspension'
      and duration_days = 7
      and end_date between now() + interval '6 days' and now() + interval '8 days'),
    'sanction carries configured duration and end_date';

  assert exists(
    select 1 from public.notifications
    where user_id = t.cust_a and type = 'account'
      and data->>'event' = 'cancel_suspension'
      and data->>'duration_days' = '7'
      and title like '%7 يوم%'
      and body like '%الدعم%'
      and deep_link = '/support'),
    'customer notification carries configured days, support path and deep link';

  -- Owner can shorten back to the default.
  perform set_config('request.jwt.claim.sub', t.owner_id::text, true);
  v_days := public.set_cancel_suspension_days(5, 'zz-test-393 restore');
  assert (select cancel_suspension_days from public.platform_settings where id='default') = 5,
    'owner can shorten the period';
end $test$;

-- Refusal suspension: same owner-only config treatment (393, owner follow-up).
create temporary table _t393b(cust_c uuid, driver_u uuid, driver_id uuid, order_c uuid, order_d uuid, order_old uuid);
insert into _t393b select gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), null, null, null;
insert into auth.users(id,email,raw_user_meta_data)
select cust_c,'zz-test-393-cust-c@example.invalid','{"full_name":"zz-test-393-cust-c","user_type":"customer"}'::jsonb from _t393b union all
select driver_u,'zz-test-393-driver@example.invalid','{"full_name":"zz-test-393-driver","user_type":"driver"}'::jsonb from _t393b;
update public.users set role='customer',user_type='customer',verification_status='approved' where id=(select cust_c from _t393b);
insert into public.drivers(id,user_id,full_name,is_active,is_verified,verification_status)
select driver_id,driver_u,'zz-test-393-driver',true,true,'verified' from _t393b;
insert into public.orders(id,user_id,merchant_id,driver_id,status,subtotal,total_amount)
select g.new_id,cust_c,store,driver_id,'delivering',0,0 from _t393b, _t393, (select gen_random_uuid() as new_id) g;
update _t393b set order_c=(select id from public.orders where user_id=(select cust_c from _t393b));
insert into public.orders(user_id,merchant_id,driver_id,status,subtotal,total_amount)
select cust_c,store,driver_id,'delivering',0,0 from _t393b, _t393;
update _t393b set order_d=(select id from public.orders where user_id=(select cust_c from _t393b) and id<>(select order_c from _t393b));
insert into public.orders(user_id,merchant_id,status,subtotal,total_amount)
select cust_c,store,'cancelled',0,0 from _t393b, _t393;
update _t393b set order_old=(select id from public.orders where user_id=(select cust_c from _t393b) and id not in (select order_c from _t393b union all select order_d from _t393b));

do $test$
declare
  b record;
  r jsonb;
  v_days int;
  v_admin uuid;
  v_owner uuid;
begin
  select * into b from _t393b;
  select admin_id, owner_id into v_admin, v_owner from _t393;

  -- Default stays 5.
  assert (select refusal_suspension_days from public.platform_settings where id='default') = 5,
    'default refusal suspension is 5 days';

  -- Negative: scoped admin cannot set refusal duration via RPC or directly.
  perform set_config('request.jwt.claim.sub', v_admin::text, true);
  begin
    perform public.set_refusal_suspension_days(9);
    raise exception 'TEST_FAIL_SCOPED_ADMIN_REFUSAL_SETTER_ACCEPTED';
  exception when others then
    if sqlerrm <> 'Only the platform owner can change the refusal suspension duration' then raise; end if;
  end;
  begin
    update public.platform_settings set refusal_suspension_days = 9 where id = 'default';
    raise exception 'TEST_FAIL_SCOPED_ADMIN_REFUSAL_DIRECT_UPDATE_ACCEPTED';
  exception when others then
    if sqlerrm <> 'Only the platform owner can change the refusal suspension duration' then raise; end if;
  end;
  assert (select refusal_suspension_days from public.platform_settings where id='default') = 5,
    'blocked refusal update left value unchanged';

  -- Owner shortens refusal suspension to 4 days, audited.
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  v_days := public.set_refusal_suspension_days(4, 'zz-test-393 refusal shorten');
  assert v_days = 4, 'refusal setter returns new value';
  assert exists(
    select 1 from public.activity_logs
    where action = 'PENALTY_CONFIG_CHANGED'
      and resource = 'platform_settings' and resource_id = 'default'
      and details->>'field' = 'refusal_suspension_days'
      and details->>'old_value' = '5' and details->>'new_value' = '4'),
    'refusal config change audited';

  -- Warning path quotes the CONFIGURED duration: 2nd monthly refusal.
  -- (The prior refusal references an older order: one report per order.)
  insert into public.refusal_events(user_id, order_id)
  select b.cust_c, b.order_old;
  perform set_config('request.jwt.claim.sub', b.driver_u::text, true);
  r := public.report_delivery_refusal(b.order_d, 'zz-test-393 refusal warn');
  assert r->>'action' = 'warning' and r->>'refusal_count' = '2',
    '2nd monthly refusal warns';
  assert exists(
    select 1 from public.notifications
    where user_id = b.cust_c and data->>'event' = 'refusal_warning'
      and body like '%4 يوم%'),
    'warning message carries configured duration';

  -- 3rd monthly refusal suspends for the CONFIGURED 4 days.
  r := public.report_delivery_refusal(b.order_c, 'zz-test-393 refusal final');
  assert r->>'action' = 'account_suspended' and r->>'suspension_days' = '4'
     and r->>'order_cancelled' = 'false',
    '3rd monthly refusal suspends for configured days, order stays';
  assert exists(
    select 1 from public.sanctions
    where target_user_id = b.cust_c and sanction_type = 'suspension'
      and duration_days = 4
      and end_date between now() + interval '3 days' and now() + interval '5 days'),
    'refusal sanction carries configured duration';
  assert exists(
    select 1 from public.notifications
    where user_id = b.cust_c and type = 'account'
      and data->>'event' = 'refusal_suspension'
      and data->>'duration_days' = '4'
      and title like '%4 يوم%'),
    'refusal suspension notification carries configured days';

  -- Owner restores the default.
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  v_days := public.set_refusal_suspension_days(5, 'zz-test-393 refusal restore');
  assert (select refusal_suspension_days from public.platform_settings where id='default') = 5,
    'owner restored refusal default';
end $test$;

select 'PASS393: owner-only setters, scoped-admin/customer negatives, trigger guards, audit, defaults 5, 2nd cancel free, 3rd cancel configured suspension + support message, refusal warning/3rd-refusal configured suspension' as result;
rollback;
