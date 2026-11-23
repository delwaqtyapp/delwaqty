-- Staging-only rollback suite for migration 395 (delay-apology platform
-- credit). Synthetic zz-test fixtures inside one rolled-back transaction.
-- Covers the reviewer-required cases: dedicated locked balance unreachable
-- by both wallet_pay overloads, net-at-settlement in both settlement
-- models with subsidy ledger entries, full-credit and credit-above-goods,
-- paid refund + retry, merchant reject + retry, idempotent replay,
-- coupon+gift stacking, net-only sweep, client lockdown, and the
-- admin payables path gated on global finance scope (owner/country only;
-- list / settle-once / idempotent / denied principals / void excluded),
-- and the v6 monthly customer apology cap (2 per Cairo calendar month:
-- last-month grants do not count, the third same-month redispatch grants
-- nothing and still hands off, event/ledger/notification consistency).
-- The two-session concurrency case lives in
-- 395_platform_credit_concurrency_staging.sql (committed fixtures; cannot
-- run inside this rollback).
begin;

-- Deterministic commission rules (same pattern as settlement_system_regression).
insert into public.commission_rules(entity_type,entity_key,rate,is_active,effective_from)
values('account_type','driver',7,true,current_date),('account_type','merchant',3,true,current_date);

create temporary table zz_ctx(
  c1 uuid, c2 uuid, c3 uuid, c4 uuid, c5 uuid, c6 uuid, c7 uuid, c8 uuid, c9 uuid,
  m uuid, m2 uuid, u1 uuid, d1 uuid, v1 uuid,
  store uuid, store2 uuid, product uuid, product2 uuid);
insert into zz_ctx
select gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),
       gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),
       gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid();

insert into auth.users(id,email)
select id, id::text||'@example.invalid' from (
  select c1 as id from zz_ctx union all select c2 from zz_ctx union all
  select c3 from zz_ctx union all select c4 from zz_ctx union all
  select c5 from zz_ctx union all select c6 from zz_ctx union all
  select c7 from zz_ctx union all select c8 from zz_ctx union all select c9 from zz_ctx union all
  select m from zz_ctx union all select m2 from zz_ctx union all select u1 from zz_ctx
) x;
-- handle_new_user auto-creates public.users from the auth.users insert.
update public.users set role='customer', user_type='customer', verification_status='approved'
where id in (select c1 from zz_ctx union select c2 from zz_ctx union select c3 from zz_ctx
             union select c4 from zz_ctx union select c5 from zz_ctx union select c6 from zz_ctx
             union select c7 from zz_ctx union select c8 from zz_ctx union select c9 from zz_ctx);
update public.users set role='merchant', user_type='merchant', verification_status='approved'
where id in (select m from zz_ctx union select m2 from zz_ctx);
update public.users set role='driver', user_type='driver', verification_status='approved'
where id = (select u1 from zz_ctx);

insert into public.merchants(id,owner_user_id,name,status,is_open,latitude,longitude,delivery_fee,type)
select store,m,'zz-credit-store','active',true,30,31,15,'restaurant' from zz_ctx;
insert into public.merchants(id,owner_user_id,name,status,is_open,latitude,longitude,delivery_fee,type)
select store2,m2,'zz-credit-store-2','active',true,30,31,15,'restaurant' from zz_ctx;
insert into public.products(id,merchant_id,name,price,is_available,stock_quantity)
select product,store,'zz-credit-product',25,true,100 from zz_ctx;
insert into public.products(id,merchant_id,name,price,is_available,stock_quantity)
select product2,store2,'zz-credit-product-2',25,true,100 from zz_ctx;
insert into public.drivers(id,user_id,full_name,status,is_verified,is_active,accepts_deliveries,current_latitude,current_longitude)
select d1,u1,'zz-credit-driver','online',true,true,true,30,31 from zz_ctx;
insert into public.vehicles(id,driver_id,category,plate_number,is_active)
select v1,d1,'motorcycle','ZZ-CREDIT',true from zz_ctx;
update public.drivers set active_vehicle_id=(select v1 from zz_ctx), location_updated_at=now()
where id=(select d1 from zz_ctx);

do $$ declare
  t record; r jsonb; a jsonb;
  o1 uuid; o2 uuid; o3 uuid; o4 uuid; o5 uuid; o6 uuid; o7 uuid;
  o8a uuid; o8b uuid; o8x uuid; o9a uuid; o9b uuid; o9c uuid;
  v_ride uuid; v_count int; v_amt numeric; v_out numeric; v_ob uuid;
  v_adm uuid := gen_random_uuid(); v_denied boolean;
  v_country uuid := gen_random_uuid(); v_regional uuid := gen_random_uuid();
  v_unassigned uuid := gen_random_uuid(); v_inactive uuid := gen_random_uuid();
  v_uid uuid; v_oid uuid; v_oid2 uuid;
begin
  select * into t from zz_ctx;

  -- ============ A. Spend mechanics (customer c1) ======================
  perform set_config('request.jwt.claim.sub', t.c1::text, true);

  -- A1. No credit: order untouched.
  r := public.create_order(t.store, jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',2)),
        'zz-test-address', 30.001, 31.001);
  assert r->>'ok' = 'true', format('create_order failed: %s', r);
  assert (r->>'total_amount')::numeric = 65 and (r->>'platform_credit_applied')::numeric = 0,
    'A1: no credit, no discount';
  o1 := (r->>'order_id')::uuid;

  -- A2. Grant 20; a second grant for the same order is a no-op.
  perform public._platform_credit_grant(t.c1, 20, o1);
  perform public._platform_credit_grant(t.c1, 20, o1);
  assert (select balance from public.platform_credit_accounts where user_id=t.c1) = 20,
    'A2: one grant per order';
  assert (select count(*) from public.platform_credit_ledger where user_id=t.c1 and kind='grant') = 1,
    'A2: single grant ledger row';
  assert exists(select 1 from public.activity_logs where action='PLATFORM_CREDIT_GRANTED'),
    'A2: grant audit row';

  -- A3. Read path shapes.
  r := public.my_platform_credit();
  assert r->>'ok'='true' and (r->>'available')::numeric=20 and (r->>'applies')::numeric=20, 'A3: null due';
  r := public.my_platform_credit(65);
  assert (r->>'applies')::numeric = 20, 'A3: due above balance';
  r := public.my_platform_credit(10);
  assert (r->>'applies')::numeric = 10, 'A3: due below balance';
  r := public.my_platform_credit(0);
  assert (r->>'applies')::numeric = 0, 'A3: zero due';

  -- A4. Credit smaller than total: 65 due -> 45.
  r := public.create_order(t.store, jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',2)),
        'zz-test-address', 30.001, 31.001);
  assert (r->>'total_amount')::numeric = 45 and (r->>'platform_credit_applied')::numeric = 20,
    'A4: credit applied';
  o2 := (r->>'order_id')::uuid;
  assert (select balance from public.platform_credit_accounts where user_id=t.c1) = 0, 'A4: spent once';
  assert (select count(*) from public.platform_credit_ledger
           where order_id=o2 and kind='spend' and amount=20 and balance_after=0) = 1, 'A4: spend ledger row';
  assert exists(select 1 from public.activity_logs where action='PLATFORM_CREDIT_SPENT' and resource_id=o2::text),
    'A4: spend audit row';
  assert (select platform_credit_applied from public.orders where id=o2) = 20, 'A4: order column';

  -- A5. Credit above goods but below total: goods 50, fee 15, gift 55 -> total 10.
  perform public._platform_credit_grant(t.c1, 55, null);
  r := public.create_order(t.store, jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',2)),
        'zz-test-address', 30.001, 31.001);
  assert (r->>'platform_credit_applied')::numeric = 55 and (r->>'total_amount')::numeric = 10,
    'A5: credit above goods';
  assert (select balance from public.platform_credit_accounts where user_id=t.c1) = 0, 'A5: fully spent';

  -- A6. Full-total credit: gift 100 vs 65 due -> total 0, remainder 35.
  perform public._platform_credit_grant(t.c1, 100, null);
  r := public.create_order(t.store, jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',2)),
        'zz-test-address', 30.001, 31.001);
  assert (r->>'total_amount')::numeric = 0 and (r->>'platform_credit_applied')::numeric = 65,
    'A6: credit cannot exceed the order total';
  o4 := (r->>'order_id')::uuid;
  assert (select balance from public.platform_credit_accounts where user_id=t.c1) = 35, 'A6: remainder survives';

  -- A7. Remainder applies to the next order, once.
  r := public.create_order(t.store, jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',2)),
        'zz-test-address', 30.001, 31.001);
  assert (r->>'total_amount')::numeric = 30 and (r->>'platform_credit_applied')::numeric = 35,
    'A7: remainder applies once';
  assert (select balance from public.platform_credit_accounts where user_id=t.c1) = 0, 'A7: remainder spent once';

  -- A8. Customer cancel restores the credit.
  r := public.cancel_order(o2, 'zz-test-cancel');
  assert r->>'ok' = 'true', format('A8: cancel failed: %s', r);
  assert (select balance from public.platform_credit_accounts where user_id=t.c1) = 20, 'A8: cancel restores';
  assert (select count(*) from public.platform_credit_ledger where order_id=o2 and kind='restore' and amount=20) = 1,
    'A8: restore ledger row';
  assert exists(select 1 from public.activity_logs where action='PLATFORM_CREDIT_RESTORED' and resource_id=o2::text),
    'A8: restore audit row';
  assert not exists(select 1 from public.wallets where user_id=t.c1),
    'A8: unpaid cash order touches no wallet';

  -- A9. Merchant rejection restores the credit; a retry does not double it.
  r := public.create_order(t.store, jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',2)),
        'zz-test-address', 30.001, 31.001);
  assert (r->>'platform_credit_applied')::numeric = 20, 'A9: re-applied';
  o5 := (r->>'order_id')::uuid;
  perform set_config('request.jwt.claim.sub', t.m::text, true);
  r := public.merchant_reject_order(o5, 'zz-test-reject');
  assert r->>'ok' = 'true', format('A9: reject failed: %s', r);
  perform set_config('request.jwt.claim.sub', t.c1::text, true);
  assert (select balance from public.platform_credit_accounts where user_id=t.c1) = 20, 'A9: reject restores';
  perform set_config('request.jwt.claim.sub', t.m::text, true);
  r := public.merchant_reject_order(o5, 'zz-test-reject-again');
  perform set_config('request.jwt.claim.sub', t.c1::text, true);
  assert r->>'ok' is distinct from 'true', 'A9: second reject refused';
  assert (select balance from public.platform_credit_accounts where user_id=t.c1) = 20,
    'A9: no double restore on reject retry';
  assert (select count(*) from public.platform_credit_ledger where order_id=o5 and kind='restore') = 1,
    'A9: single restore row';

  -- A10. Idempotent replay never double-spends.
  r := public.create_order(t.store, jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',2)),
        'zz-test-address', 30.001, 31.001, 'cash', null, null, 'zz-credit-replay-v2');
  assert (r->>'platform_credit_applied')::numeric = 20, 'A10: first call spends';
  o6 := (r->>'order_id')::uuid;
  r := public.create_order(t.store, jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',2)),
        'zz-test-address', 30.001, 31.001, 'cash', null, null, 'zz-credit-replay-v2');
  assert r->>'idempotent_replay' = 'true', 'A10: replay short-circuits';
  assert (select balance from public.platform_credit_accounts where user_id=t.c1) = 0, 'A10: no double spend';
  assert (select count(*) from public.platform_credit_ledger where order_id=o6 and kind='spend') = 1,
    'A10: single spend row';

  -- ============ B. Paid order + gift: refund and retry (customer c5) ==
  perform set_config('request.jwt.claim.sub', t.c5::text, true);
  perform public._platform_credit_grant(t.c5, 20, null);
  r := public.create_order(t.store, jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',2)),
        'zz-test-address', 30.001, 31.001, 'instapay');
  assert (r->>'platform_credit_applied')::numeric = 20 and (r->>'total_amount')::numeric = 45,
    'B: paid order credited';
  o7 := (r->>'order_id')::uuid;
  update public.orders set payment_status = 'paid' where id = o7;
  r := public.cancel_order(o7, 'zz-test-paid-cancel');
  assert r->>'ok' = 'true', format('B: paid cancel failed: %s', r);
  -- Refund returns what the customer actually paid (post-credit 45) and
  -- the gift comes back as credit (20). Nothing is refunded twice.
  assert (select balance from public.wallets where user_id=t.c5) = 45, 'B: wallet refund is post-credit amount';
  assert (select count(*) from public.wallet_transactions wt join public.wallets w on w.id=wt.wallet_id
           where w.user_id=t.c5 and wt.type='credit' and wt.reference_type='refund'
             and wt.reference_id=o7 and wt.amount=45) = 1, 'B: single refund row';
  assert (select balance from public.platform_credit_accounts where user_id=t.c5) = 20, 'B: credit restored';
  -- Retry paths: cancel again and a direct finalize call both no-op.
  r := public.cancel_order(o7, 'zz-test-paid-cancel-again');
  assert r->>'ok' is distinct from 'true', 'B: second cancel refused';
  perform public._finalize_order_cancel(o7, 'customer', 'zz-retry', true, true, true, 'system');
  assert (select balance from public.wallets where user_id=t.c5) = 45, 'B: no double refund';
  assert (select balance from public.platform_credit_accounts where user_id=t.c5) = 20, 'B: no double restore';
  assert (select count(*) from public.platform_credit_ledger where order_id=o7 and kind='restore') = 1,
    'B: single restore row after retries';

  -- ============ C. Coupon + gift (customer c6) ========================
  insert into public.coupons(code, description, discount_type, discount_value, minimum_order, is_active)
  values ('ZZ-GIFT-10', 'zz test coupon', 'fixed', 10, 0, true);
  perform set_config('request.jwt.claim.sub', t.c6::text, true);
  perform public._platform_credit_grant(t.c6, 20, null);
  r := public.create_order(t.store, jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',2)),
        'zz-test-address', 30.001, 31.001, 'cash', 'ZZ-GIFT-10');
  assert r->>'ok' = 'true', format('C: coupon order failed: %s', r);
  assert (r->>'discount')::numeric = 10 and (r->>'platform_credit_applied')::numeric = 20
     and (r->>'total_amount')::numeric = 35, 'C: coupon and gift stack';
  assert (select balance from public.platform_credit_accounts where user_id=t.c6) = 0, 'C: gift spent once';

  -- ============ D. Settlement conservation, platform model (c2) =======
  perform set_config('request.jwt.claim.sub', t.c2::text, true);
  perform public._platform_credit_grant(t.c2, 15, null);
  r := public.create_order(t.store, jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',2)),
        'zz-test-address', 30.001, 31.001);
  assert (r->>'platform_credit_applied')::numeric = 15 and (r->>'total_amount')::numeric = 50,
    'D: credited cash order';
  o1 := (r->>'order_id')::uuid;

  perform set_config('request.jwt.claim.sub', t.m::text, true);
  a := public.merchant_dispatch_order_driver(o1);
  assert a->>'ok' = 'true', format('D: dispatch failed: %s', a);
  select id into v_ride from public.rides where order_id=o1;
  perform set_config('request.jwt.claim.sub', t.u1::text, true);
  a := public.accept_ride_request(v_ride, t.d1);
  assert a->>'success' = 'true', format('D: accept failed: %s', a);
  a := public.driver_arrive(v_ride, t.d1);
  assert a->>'success' = 'true', format('D: arrive failed: %s', a);
  perform set_config('request.jwt.claim.sub', t.m::text, true);
  a := public.delivery_handoff_code('pickup', v_ride, null);
  perform set_config('request.jwt.claim.sub', t.u1::text, true);
  a := public.start_trip(v_ride, t.d1, a->>'code');
  assert a->>'success' = 'true', format('D: start failed: %s', a);
  perform set_config('request.jwt.claim.sub', t.c2::text, true);
  a := public.delivery_handoff_code('dropoff', v_ride, null);
  perform set_config('request.jwt.claim.sub', t.u1::text, true);
  a := public.complete_delivery(v_ride, t.d1, null, null, a->>'code');
  assert a->>'success' = 'true', format('D: completion failed: %s', a);

  -- Owner rule: merchant and captain are paid exactly as if there were no
  -- credit. Goods obligation is PRE-CREDIT (50+15-15 = 50), commission is
  -- 7% of the fare, merchant ledger is subtotal - 3%.
  assert exists(select 1 from public.driver_obligations
    where order_id=o1 and kind='goods' and amount=35 and owed_to='platform' and status='open'),
    'D: goods obligation is pre-credit goods minus the gift (net)';
  assert exists(select 1 from public.driver_obligations
    where order_id=o1 and kind='commission' and amount=round(15*0.07,2) and owed_to='platform'),
    'D: commission unchanged by credit';
  assert exists(select 1 from public.merchant_ledger
    where merchant_id=t.store and order_id=o1 and entry_type='credit' and amount=48.5),
    'D: merchant ledger credit unchanged by credit';
  -- The platform books the cash gap as a subsidy owed to the driver.
  assert exists(select 1 from public.platform_subsidies
    where order_id=o1 and kind='delay_apology_credit' and amount=15
      and settlement_model='platform' and status='netted'
      and remittance_reduction=15 and driver_payable=0 and merchant_payable=0),
    'D: subsidy netted (platform model)';
  assert exists(select 1 from public.activity_logs where action='PLATFORM_SUBSIDY_NETTED' and resource_id=o1::text),
    'D: subsidy audit row';
  -- The driver is told the platform covers the gap.
  assert exists(select 1 from public.notifications
    where user_id=t.u1 and type='settlement' and data->>'order_id'=o1::text and body like '%بتغطي%'),
    'D: settlement notification names the platform coverage';
  -- Earnings idempotency: a second pass creates nothing new.
  perform public._record_delivery_earnings(v_ride);
  select count(*) into v_count from public.platform_subsidies where order_id=o1;
  assert v_count = 1, 'D: subsidy idempotent on earnings replay';
  assert (select count(*) from public.driver_obligations where order_id=o1) = 2,
    'D: obligations idempotent on earnings replay';

  -- Dispatch cash-ceiling reads the NET obligation: d1 owes net 35 + 1.05
  -- commission here. A synthetic obligation sized so the pre-credit goods
  -- (50) would push him over the ceiling but the net (35) keeps him under
  -- must still let a cash dispatch reach him.
  select coalesce((select settlement_driver_cash_ceiling from public._settlement_settings()), 1000) into v_amt;
  select coalesce(sum(amount),0) into v_out from public.driver_obligations
   where driver_id=t.d1 and status in ('open','disputed');
  insert into public.driver_obligations(driver_id,kind,amount,owed_to,due_at)
  values (t.d1,'goods', v_amt - v_out - 5, 'platform', now() + interval '1 day');
  perform set_config('request.jwt.claim.sub', t.c2::text, true);
  r := public.create_order(t.store, jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',1)),
        'zz-test-address', 30.001, 31.001);
  assert r->>'ok' = 'true', format('D-ceiling: order failed: %s', r);
  o3 := (r->>'order_id')::uuid;
  perform set_config('request.jwt.claim.sub', t.m::text, true);
  a := public.merchant_dispatch_order_driver(o3);
  assert a->>'ok' = 'true', format('D-ceiling: dispatch failed: %s', a);
  select id into v_ride from public.rides where order_id=o3;
  assert exists(select 1 from public.ride_requests where ride_id=v_ride and driver_id=t.d1),
    'D-ceiling: net-below-ceiling driver must be offered cash dispatch';
  update public.rides set status='cancelled' where id=v_ride;
  delete from public.ride_requests where ride_id=v_ride;
  delete from public.orders where id=o3;
  delete from public.driver_obligations
   where driver_id=t.d1 and order_id is null;

  -- ============ E. Settlement conservation, direct model (c3) =========
  perform set_config('request.jwt.claim.sub', t.m2::text, true);
  a := public.merchant_set_settlement_model('direct');
  assert a->>'ok' = 'true', format('E: model switch failed: %s', a);
  perform set_config('request.jwt.claim.sub', t.c3::text, true);
  perform public._platform_credit_grant(t.c3, 15, null);
  r := public.create_order(t.store2, jsonb_build_array(jsonb_build_object('product_id',t.product2,'quantity',2)),
        'zz-test-address', 30.001, 31.001);
  assert (r->>'platform_credit_applied')::numeric = 15 and (r->>'total_amount')::numeric = 50,
    'E: credited cash order (direct)';
  o2 := (r->>'order_id')::uuid;

  perform set_config('request.jwt.claim.sub', t.m2::text, true);
  a := public.merchant_dispatch_order_driver(o2);
  assert a->>'ok' = 'true', format('E: dispatch failed: %s', a);
  select id into v_ride from public.rides where order_id=o2;
  perform set_config('request.jwt.claim.sub', t.u1::text, true);
  a := public.accept_ride_request(v_ride, t.d1);
  assert a->>'success' = 'true', format('E: accept failed: %s', a);
  a := public.driver_arrive(v_ride, t.d1);
  perform set_config('request.jwt.claim.sub', t.m2::text, true);
  a := public.delivery_handoff_code('pickup', v_ride, null);
  perform set_config('request.jwt.claim.sub', t.u1::text, true);
  a := public.start_trip(v_ride, t.d1, a->>'code');
  perform set_config('request.jwt.claim.sub', t.c3::text, true);
  a := public.delivery_handoff_code('dropoff', v_ride, null);
  perform set_config('request.jwt.claim.sub', t.u1::text, true);
  a := public.complete_delivery(v_ride, t.d1, null, null, a->>'code');
  assert a->>'success' = 'true', format('E: completion failed: %s', a);

  assert exists(select 1 from public.driver_obligations
    where order_id=o2 and kind='goods' and amount=35 and owed_to='merchant'),
    'E: direct-model goods obligation is net and owed to merchant';
  assert not exists(select 1 from public.merchant_ledger where order_id=o2),
    'E: direct model writes no merchant ledger credit';
  assert exists(select 1 from public.platform_subsidies
    where order_id=o2 and kind='delay_apology_credit' and amount=15
      and settlement_model='direct' and status='netted'
      and remittance_reduction=15 and driver_payable=0 and merchant_payable=15),
    'E: subsidy netted, merchant gap is a platform payable (direct model)';

  -- ============ F. Sweep sees only NET obligations ====================
  -- The gift is netted into the obligation rows themselves, so the sweep
  -- needs no subsidy awareness: an over-limit driver suspends, period.
  select coalesce((select settlement_suspension_amount from public._settlement_settings()), 1500) into v_amt;
  select coalesce(sum(amount),0) into v_out from public.driver_obligations
   where driver_id=t.d1 and status in ('open','disputed');
  insert into public.driver_obligations(driver_id,kind,amount,owed_to,due_at)
  values (t.d1,'goods', v_amt + 100 - v_out, 'platform', now() + interval '1 day');
  perform public._settlement_escalation_sweep();
  assert (select settlement_suspended_until from public.drivers where id=t.d1) is not null,
    'F: over-limit driver suspends on net obligations';
  -- Reset the driver for the remaining sections.
  update public.drivers set settlement_suspended_until=null, is_online=true where id=t.d1;
  update public.users set account_status='active' where id=t.u1;
  delete from public.driver_obligations where driver_id=t.d1;

  -- ============ H. Full-total credit, both settlement models ==========
  -- goods 50 + fee 15, gift 65 covers everything: no goods obligation is
  -- created (extinguished by the netting), the captain's 13.95 (fare less
  -- 7% commission) is still earned, and the platform books his whole fare
  -- as driver_payable. Direct model: the merchant's full goods become a
  -- platform payable.
  -- H1: platform model.
  perform set_config('request.jwt.claim.sub', t.c7::text, true);
  perform public._platform_credit_grant(t.c7, 65, null);
  r := public.create_order(t.store, jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',2)),
        'zz-test-address', 30.001, 31.001);
  assert (r->>'platform_credit_applied')::numeric = 65 and (r->>'total_amount')::numeric = 0,
    'H1: full-total credit';
  o1 := (r->>'order_id')::uuid;
  perform set_config('request.jwt.claim.sub', t.m::text, true);
  a := public.merchant_dispatch_order_driver(o1);
  assert a->>'ok' = 'true', format('H1: dispatch failed: %s', a);
  select id into v_ride from public.rides where order_id=o1;
  perform set_config('request.jwt.claim.sub', t.u1::text, true);
  a := public.accept_ride_request(v_ride, t.d1);
  a := public.driver_arrive(v_ride, t.d1);
  perform set_config('request.jwt.claim.sub', t.m::text, true);
  a := public.delivery_handoff_code('pickup', v_ride, null);
  perform set_config('request.jwt.claim.sub', t.u1::text, true);
  a := public.start_trip(v_ride, t.d1, a->>'code');
  perform set_config('request.jwt.claim.sub', t.c7::text, true);
  a := public.delivery_handoff_code('dropoff', v_ride, null);
  perform set_config('request.jwt.claim.sub', t.u1::text, true);
  a := public.complete_delivery(v_ride, t.d1, null, null, a->>'code');
  assert a->>'success' = 'true', format('H1: completion failed: %s', a);
  assert not exists(select 1 from public.driver_obligations where order_id=o1 and kind='goods'),
    'H1: full credit extinguishes the goods debt';
  assert exists(select 1 from public.driver_obligations
    where order_id=o1 and kind='commission' and amount=round(15*0.07,2)),
    'H1: captain commission obligation stands';
  assert exists(select 1 from public.driver_earnings
    where order_id=o1 and type='trip' and amount=15-round(15*0.07,2)),
    'H1: captain still earns 13.95';
  assert exists(select 1 from public.platform_subsidies
    where order_id=o1 and amount=65 and status='netted'
      and remittance_reduction=50 and driver_payable=15 and merchant_payable=0),
    'H1: platform books the fare shortfall as driver payable';
  assert exists(select 1 from public.merchant_ledger
    where merchant_id=t.store and order_id=o1 and entry_type='credit' and amount=48.5),
    'H1: merchant ledger credit unchanged';
  assert exists(select 1 from public.notifications
    where user_id=t.u1 and type='settlement' and data->>'order_id'=o1::text
      and body like '%مفيش توريد%'),
    'H1: captain told no remittance is due';

  -- H2: direct model.
  perform set_config('request.jwt.claim.sub', t.c8::text, true);
  perform public._platform_credit_grant(t.c8, 65, null);
  r := public.create_order(t.store2, jsonb_build_array(jsonb_build_object('product_id',t.product2,'quantity',2)),
        'zz-test-address', 30.001, 31.001);
  assert (r->>'platform_credit_applied')::numeric = 65 and (r->>'total_amount')::numeric = 0,
    'H2: full-total credit (direct)';
  o2 := (r->>'order_id')::uuid;
  perform set_config('request.jwt.claim.sub', t.m2::text, true);
  a := public.merchant_dispatch_order_driver(o2);
  assert a->>'ok' = 'true', format('H2: dispatch failed: %s', a);
  select id into v_ride from public.rides where order_id=o2;
  perform set_config('request.jwt.claim.sub', t.u1::text, true);
  a := public.accept_ride_request(v_ride, t.d1);
  a := public.driver_arrive(v_ride, t.d1);
  perform set_config('request.jwt.claim.sub', t.m2::text, true);
  a := public.delivery_handoff_code('pickup', v_ride, null);
  perform set_config('request.jwt.claim.sub', t.u1::text, true);
  a := public.start_trip(v_ride, t.d1, a->>'code');
  perform set_config('request.jwt.claim.sub', t.c8::text, true);
  a := public.delivery_handoff_code('dropoff', v_ride, null);
  perform set_config('request.jwt.claim.sub', t.u1::text, true);
  a := public.complete_delivery(v_ride, t.d1, null, null, a->>'code');
  assert a->>'success' = 'true', format('H2: completion failed: %s', a);
  assert not exists(select 1 from public.driver_obligations where order_id=o2 and kind='goods'),
    'H2: full credit extinguishes the goods debt';
  assert exists(select 1 from public.driver_earnings
    where order_id=o2 and type='trip' and amount=15-round(15*0.07,2)),
    'H2: captain still earns 13.95';
  assert not exists(select 1 from public.merchant_ledger where order_id=o2),
    'H2: direct model writes no merchant ledger credit';
  assert exists(select 1 from public.platform_subsidies
    where order_id=o2 and amount=65 and status='netted'
      and remittance_reduction=50 and driver_payable=15 and merchant_payable=50),
    'H2: platform owes the merchant full goods and the captain his fare';

  -- ============ I. Non-cash credited order: accounting row only =======
  perform set_config('request.jwt.claim.sub', t.c9::text, true);
  perform public._platform_credit_grant(t.c9, 15, null);
  r := public.create_order(t.store, jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',2)),
        'zz-test-address', 30.001, 31.001, 'instapay');
  assert (r->>'platform_credit_applied')::numeric = 15 and (r->>'total_amount')::numeric = 50,
    'I: non-cash credited order';
  o4 := (r->>'order_id')::uuid;
  perform set_config('request.jwt.claim.sub', t.m::text, true);
  a := public.merchant_dispatch_order_driver(o4);
  assert a->>'ok' = 'true', format('I: dispatch failed: %s', a);
  select id into v_ride from public.rides where order_id=o4;
  perform set_config('request.jwt.claim.sub', t.u1::text, true);
  a := public.accept_ride_request(v_ride, t.d1);
  a := public.driver_arrive(v_ride, t.d1);
  perform set_config('request.jwt.claim.sub', t.m::text, true);
  a := public.delivery_handoff_code('pickup', v_ride, null);
  perform set_config('request.jwt.claim.sub', t.u1::text, true);
  a := public.start_trip(v_ride, t.d1, a->>'code');
  perform set_config('request.jwt.claim.sub', t.c9::text, true);
  a := public.delivery_handoff_code('dropoff', v_ride, null);
  perform set_config('request.jwt.claim.sub', t.u1::text, true);
  a := public.complete_delivery(v_ride, t.d1, null, null, a->>'code');
  assert a->>'success' = 'true', format('I: completion failed: %s', a);
  assert not exists(select 1 from public.driver_obligations where order_id=o4 and kind='goods'),
    'I: non-cash has no goods obligation';
  assert exists(select 1 from public.platform_subsidies
    where order_id=o4 and kind='delay_apology_credit' and amount=15
      and status='netted_noncash'
      and remittance_reduction=0 and driver_payable=0 and merchant_payable=0),
    'I: non-cash subsidy recorded for accounting';

  -- ============ J. Admin payables path (manual settlement) ============
  -- H1's order (o1) carries driver_payable 15; H2's (o2) carries
  -- driver_payable 15 + merchant_payable 50; I's (o4) has zero payables.
  -- #97 access fixtures: owner, country admin (root region + descendants),
  -- regional admin (child region), unassigned admin, inactive admin.
  insert into auth.users(id,email)
  select id, id::text||'@example.invalid' from (values
    (v_adm),(v_country),(v_regional),(v_unassigned),(v_inactive)) x(id);
  update public.users set role='owner', user_type='owner', verification_status='approved'
   where id = v_adm;
  update public.users set role='admin', user_type='admin', verification_status='approved'
   where id in (v_country, v_regional, v_unassigned, v_inactive);
  insert into public.regions (id, code, parent_region_id, country_code, type, name_ar, name_en, is_active)
  values ('00000000-0000-0000-0000-000000000001','EG',null,'EG','country','مصر','Egypt',true),
         ('00000000-0000-0000-0000-000000000101','EG-ALX','00000000-0000-0000-0000-000000000001','EG','governorate','الإسكندرية','Alexandria',true)
  on conflict (id) do nothing;
  insert into public.admin_management(admin_id, supervisor_id, is_active)
  values (v_country, v_adm, true), (v_regional, v_adm, true),
         (v_unassigned, v_adm, true), (v_inactive, v_adm, false);
  insert into public.admin_region_assignments(admin_id, region_id, scope, created_by)
  values (v_country, '00000000-0000-0000-0000-000000000001', 'descendants', v_adm),
         (v_regional, '00000000-0000-0000-0000-000000000101', 'descendants', v_adm);

  -- J1. Access matrix (#97): customer, regional, unassigned and inactive
  -- admins are denied on BOTH RPCs and change nothing.
  for v_uid in select unnest(array[t.c1, v_regional, v_unassigned, v_inactive]) loop
    perform set_config('request.jwt.claim.sub', v_uid::text, true);
    v_denied := false;
    begin
      perform 1 from public.admin_open_platform_payables(null) limit 1;
    exception when others then
      v_denied := position('Not authorized' in sqlerrm) > 0;
    end;
    assert v_denied, 'J1: read denied for ' || v_uid;
    v_denied := false;
    begin
      r := public.mark_platform_payable_settled(o1, 'driver_payable', 'zz');
    exception when others then
      v_denied := position('Not authorized' in sqlerrm) > 0;
    end;
    assert v_denied, 'J1: settle denied for ' || v_uid;
  end loop;
  assert not exists(select 1 from public.platform_subsidies
    where order_id=o1 and driver_payable_settled_at is not null),
    'J1: denied calls changed nothing';

  -- J2. Owner and country admin read the outstanding payables, per order,
  -- with amounts; zero-payable rows are not listed.
  perform set_config('request.jwt.claim.sub', v_adm::text, true);
  assert exists(select 1 from public.admin_open_platform_payables(null)
    where order_id=o1 and driver_payable=15 and merchant_payable=0),
    'J2: owner reads payables';
  perform set_config('request.jwt.claim.sub', v_country::text, true);
  assert exists(select 1 from public.admin_open_platform_payables(null)
    where order_id=o2 and driver_payable=15 and merchant_payable=50),
    'J2: country admin reads payables';
  assert not exists(select 1 from public.admin_open_platform_payables(null)
    where order_id=o4),
    'J2: zero-payable (non-cash) row not listed';
  assert (select count(*) from public.admin_open_platform_payables(o2)) = 1,
    'J2: per-order filter';

  -- J3. Country admin settles: flips once, audits once with the reference,
  -- result says settlement recorded / no money moved; repeat is idempotent.
  r := public.mark_platform_payable_settled(o1, 'driver_payable', 'zz-transfer-114');
  assert r->>'ok'='true' and (r->>'amount')::numeric=15
     and r->>'already_settled'='false' and r->>'row_status'='settled'
     and r->>'settlement_recorded'='true' and r->>'money_moved'='false'
     and r->>'reference'='zz-transfer-114',
    'J3: settle result records settlement, moves no money';
  assert exists(select 1 from public.platform_subsidies
    where order_id=o1 and status='settled' and settled_at is not null
      and driver_payable_settled_at is not null),
    'J3: row settled';
  assert exists(select 1 from public.activity_logs
    where action='PLATFORM_PAYABLE_SETTLED' and resource_id=o1::text
      and details->>'reference'='zz-transfer-114'),
    'J3: audit row carries the reference';
  r := public.mark_platform_payable_settled(o1, 'driver_payable', 'duplicate');
  assert r->>'ok'='true' and r->>'already_settled'='true'
     and r->>'money_moved'='false' and r->>'reference'='zz-transfer-114',
    'J3: repeat idempotent, replays the ORIGINAL reference';
  assert (select count(*) from public.activity_logs
    where action='PLATFORM_PAYABLE_SETTLED' and resource_id=o1::text) = 1,
    'J3: still one audit row';
  assert not exists(select 1 from public.admin_open_platform_payables(o1)),
    'J3: settled payable leaves the open list';

  -- J4. Owner: a row with two payables settles per kind; the row stays open
  -- until every positive payable on it is settled.
  perform set_config('request.jwt.claim.sub', v_adm::text, true);
  r := public.mark_platform_payable_settled(o2, 'driver_payable', null);
  assert r->>'row_status'='netted', 'J4: partial settle keeps the row open';
  assert exists(select 1 from public.platform_subsidies
    where order_id=o2 and status='netted'
      and driver_payable_settled_at is not null
      and merchant_payable_settled_at is null),
    'J4: driver kind settled, merchant kind open';
  assert exists(select 1 from public.admin_open_platform_payables(o2)),
    'J4: merchant payable still outstanding';
  r := public.mark_platform_payable_settled(o2, 'merchant_payable', 'zz');
  assert r->>'row_status'='settled', 'J4: fully settled';
  assert exists(select 1 from public.platform_subsidies
    where order_id=o2 and status='settled' and settled_at is not null
      and merchant_payable_settled_at is not null),
    'J4: row settled';
  assert not exists(select 1 from public.admin_open_platform_payables(o2)),
    'J4: nothing outstanding';

  -- J5. Invalid kind, NULL kind (#98) and a missing/zero payable rejected.
  v_denied := false;
  begin
    r := public.mark_platform_payable_settled(o2, 'remittance_reduction', null);
  exception when others then v_denied := true;
  end;
  assert v_denied, 'J5: invalid kind rejected';
  v_denied := false;
  begin
    r := public.mark_platform_payable_settled(o2, null, null);
  exception when others then
    v_denied := position('invalid payable kind' in sqlerrm) > 0;
  end;
  assert v_denied, 'J5: NULL kind rejected explicitly';
  v_denied := false;
  begin
    r := public.mark_platform_payable_settled(o4, 'driver_payable', null);
  exception when others then v_denied := true;
  end;
  assert v_denied, 'J5: zero payable rejected';

  -- J6. Void subsidy rows are invisible to both RPCs (#98).
  select o.id into v_oid from public.orders o
   where o.user_id = t.c1
     and not exists (select 1 from public.platform_subsidies ps where ps.order_id = o.id)
   limit 1;
  insert into public.platform_subsidies(order_id, kind, amount, settlement_model, reimburses, driver_payable, status)
  values (v_oid, 'delay_apology_credit', 7, 'platform', 'driver', 7, 'void');
  assert not exists(select 1 from public.admin_open_platform_payables(null) where order_id=v_oid),
    'J6: void row not listed';
  v_denied := false;
  begin
    r := public.mark_platform_payable_settled(v_oid, 'driver_payable', null);
  exception when others then
    v_denied := position('no settleable' in sqlerrm) > 0;
  end;
  assert v_denied, 'J6: void row rejected by the setter';

  -- J7 fixtures: an open payable plus the country admin id, handed to the
  -- top-level real-role ACL checks through transaction-local settings.
  select o.id into v_oid2 from public.orders o
   where not exists (select 1 from public.platform_subsidies ps where ps.order_id = o.id)
   order by o.created_at desc
   limit 1;
  insert into public.platform_subsidies(order_id, kind, amount, settlement_model, reimburses, driver_payable, status)
  values (v_oid2, 'delay_apology_credit', 7, 'platform', 'driver', 7, 'netted');
  perform set_config('app.zz_acl_oid', v_oid2::text, true);
  perform set_config('app.zz_acl_country', v_country::text, true);

  -- ============ H. Monthly customer apology cap (v6) ==================
  -- c8: a captain-apology grant LAST month must not count toward this
  -- month's cap of 2; two fresh redispatches both grant. c9: two fresh
  -- grants, the third redispatch grants nothing and still hands off.
  -- Fixture helper inlined per order: create -> dispatch -> accept ->
  -- _driver_delay_redispatch (the grant path under test).

  perform set_config('request.jwt.claim.sub', t.c8::text, true);
  r := public.create_order(t.store, jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',2)),
        'zz-test-address', 30.001, 31.001);
  assert r->>'ok' = 'true', format('H: c8 order x failed: %s', r);
  o8x := (r->>'order_id')::uuid;
  r := public.create_order(t.store, jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',2)),
        'zz-test-address', 30.001, 31.001);
  assert r->>'ok' = 'true', format('H: c8 order a failed: %s', r);
  o8a := (r->>'order_id')::uuid;
  r := public.create_order(t.store, jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',2)),
        'zz-test-address', 30.001, 31.001);
  assert r->>'ok' = 'true', format('H: c8 order b failed: %s', r);
  o8b := (r->>'order_id')::uuid;
  perform set_config('request.jwt.claim.sub', t.m::text, true);
  perform public.merchant_dispatch_order_driver(o8x);
  perform public.merchant_dispatch_order_driver(o8a);
  perform public.merchant_dispatch_order_driver(o8b);

  -- Last month's grant for c8 (different order, so no per-order replay).
  insert into public.driver_delay_events
    (ride_id, order_id, driver_id, reported_by, reason,
     within_allowance, monthly_count, apology_amount, created_at)
  select r2.id, o8x, t.d1, 'driver', 'zz last month', true, 1, 5,
         (date_trunc('month', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo') - interval '1 day'
    from public.rides r2 where r2.order_id = o8x;

  perform set_config('request.jwt.claim.sub', t.u1::text, true);
  select id into v_ride from public.rides where order_id=o8a;
  a := public.accept_ride_request(v_ride, t.d1);
  assert a->>'success' = 'true', format('H: c8 accept a failed: %s', a);
  a := public._driver_delay_redispatch(v_ride, 'zz سبب تجريبي', 'driver');
  assert a->>'ok' = 'true', format('H: c8 redispatch a failed: %s', a);
  assert (a->>'apology_amount')::numeric = 4.55,
    'H: last month grant must not consume this month (c8 first)';
  select id into v_ride from public.rides where order_id=o8b;
  a := public.accept_ride_request(v_ride, t.d1);
  assert a->>'success' = 'true', format('H: c8 accept b failed: %s', a);
  a := public._driver_delay_redispatch(v_ride, 'zz سبب تجريبي', 'driver');
  assert a->>'ok' = 'true' and (a->>'apology_amount')::numeric = 4.55,
    'H: c8 second grant';
  assert (select balance from public.platform_credit_accounts where user_id=t.c8) = 9.10,
    'H: c8 balance 9.10 after two grants';
  assert (select count(*) from public.platform_credit_ledger
           where user_id=t.c8 and kind='grant' and order_id in (o8a, o8b)) = 2,
    'H: c8 two apology grant ledger rows';

  perform set_config('request.jwt.claim.sub', t.c9::text, true);
  r := public.create_order(t.store, jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',2)),
        'zz-test-address', 30.001, 31.001);
  assert r->>'ok' = 'true', format('H: c9 order a failed: %s', r);
  o9a := (r->>'order_id')::uuid;
  r := public.create_order(t.store, jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',2)),
        'zz-test-address', 30.001, 31.001);
  assert r->>'ok' = 'true', format('H: c9 order b failed: %s', r);
  o9b := (r->>'order_id')::uuid;
  r := public.create_order(t.store, jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',2)),
        'zz-test-address', 30.001, 31.001);
  assert r->>'ok' = 'true', format('H: c9 order c failed: %s', r);
  o9c := (r->>'order_id')::uuid;
  perform set_config('request.jwt.claim.sub', t.m::text, true);
  perform public.merchant_dispatch_order_driver(o9a);
  perform public.merchant_dispatch_order_driver(o9b);
  perform public.merchant_dispatch_order_driver(o9c);

  perform set_config('request.jwt.claim.sub', t.u1::text, true);
  select id into v_ride from public.rides where order_id=o9a;
  a := public.accept_ride_request(v_ride, t.d1);
  assert a->>'success' = 'true', format('H: c9 accept a failed: %s', a);
  a := public._driver_delay_redispatch(v_ride, 'zz سبب تجريبي', 'driver');
  assert a->>'ok' = 'true' and (a->>'apology_amount')::numeric = 4.55,
    'H: c9 first grant';
  select id into v_ride from public.rides where order_id=o9b;
  a := public.accept_ride_request(v_ride, t.d1);
  assert a->>'success' = 'true', format('H: c9 accept b failed: %s', a);
  a := public._driver_delay_redispatch(v_ride, 'zz سبب تجريبي', 'driver');
  assert a->>'ok' = 'true' and (a->>'apology_amount')::numeric = 4.55,
    'H: c9 second grant';

  -- Third redispatch in the same month: cap reached, nothing granted,
  -- handoff still succeeds.
  select id into v_ride from public.rides where order_id=o9c;
  a := public.accept_ride_request(v_ride, t.d1);
  assert a->>'success' = 'true', format('H: c9 accept c failed: %s', a);
  a := public._driver_delay_redispatch(v_ride, 'zz سبب تجريبي', 'driver');
  assert a->>'ok' = 'true', format('H: c9 third redispatch must still hand off: %s', a);
  assert (a->>'apology_amount')::numeric = 0
     and (a->>'monthly_grants')::int = 2 and (a->>'monthly_cap')::int = 2,
    format('H: c9 third must be capped, got %s', a);
  assert (select balance from public.platform_credit_accounts where user_id=t.c9) = 9.10,
    'H: c9 balance unchanged after capped event';
  assert (select count(*) from public.platform_credit_ledger
           where user_id=t.c9 and kind='grant' and order_id in (o9a, o9b)) = 2
     and not exists (select 1 from public.platform_credit_ledger
           where user_id=t.c9 and kind='grant' and order_id = o9c),
    'H: c9 still two apology grant ledger rows';
  assert (select apology_amount from public.driver_delay_events where order_id=o9c) = 0,
    'H: capped event row records apology_amount 0';
  assert (select count(*) from public.notifications
           where user_id=t.c9 and type='order' and body like '%هدية مننا%') = 2,
    'H: c9 gift text only on the two actual grants';
end $$;

-- ============ J7. Real-role ACL checks (authenticated + anon) ===========
-- Run under the real roles, not the postgres test runner: the EXECUTE
-- grant must reach authenticated and must NOT reach anon, and the
-- global-finance scope gate must still pass under the real role.
select set_config('request.jwt.claim.sub', current_setting('app.zz_acl_country'), true);
set local role authenticated;
do $$
declare
  v_oid uuid := current_setting('app.zz_acl_oid')::uuid;
  v_r jsonb;
begin
  assert exists(select 1 from public.admin_open_platform_payables(v_oid)
    where driver_payable = 7),
    'J7: authenticated role executes the read RPC (grant + gate)';
  v_r := public.mark_platform_payable_settled(v_oid, 'driver_payable', 'zz-acl-ref');
  assert v_r->>'ok'='true' and v_r->>'already_settled'='false'
     and v_r->>'money_moved'='false',
    'J7: authenticated role executes the setter (grant + gate)';
  v_r := public.mark_platform_payable_settled(v_oid, 'driver_payable', 'changed-note');
  assert v_r->>'already_settled'='true' and v_r->>'reference'='zz-acl-ref',
    'J7: replay returns the ORIGINAL audit reference';
end $$;
reset role;

set local role anon;
do $$
declare
  v_oid uuid := current_setting('app.zz_acl_oid')::uuid;
begin
  begin
    perform 1 from public.admin_open_platform_payables(v_oid) limit 1;
    raise exception 'J7: anon reached the read RPC';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.mark_platform_payable_settled(v_oid, 'driver_payable', null);
    raise exception 'J7: anon reached the setter';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- ============ G. wallet_pay immiscibility (#68) ========================
-- Both client-callable wallet_pay overloads must leave the gift balance
-- untouched, even when the caller forges gift-flavored reference strings.
do $$ declare t record; begin
  select * into t from zz_ctx;
  perform public._platform_credit_grant(t.c4, 30, null);
  perform public._wallet_credit(t.c4, 50, 'zz topup', 'topup', null);
end $$;

grant select on zz_ctx to authenticated;
set local role authenticated;
do $$ declare t record; a jsonb; v_denied boolean; begin
  select * into t from zz_ctx;
  perform set_config('request.jwt.claim.sub', t.c4::text, true);

  -- Overload 2 (self, text reference): gift-flavored reference type.
  a := public.wallet_pay(5, 'zz forged', 'delay_apology', null);
  assert a->>'ok' = 'true', format('G: wallet_pay overload 2 failed: %s', a);
  -- Overload 1 (uuid user, uuid reference): forged spend reference.
  a := public.wallet_pay(t.c4, 7, 'zz forged', 'delay_apology_spend', gen_random_uuid());
  assert a->>'ok' = 'true', format('G: wallet_pay overload 1 failed: %s', a);

  -- Client lockdown: helpers and tables are server-only.
  v_denied := false;
  begin perform public._platform_credit_grant(t.c4, 1, null);
  exception when insufficient_privilege then v_denied := true; end;
  assert v_denied, 'G: client must not call _platform_credit_grant';
  v_denied := false;
  begin perform public._platform_credit_spend(t.c4, gen_random_uuid(), 1);
  exception when insufficient_privilege then v_denied := true; end;
  assert v_denied, 'G: client must not call _platform_credit_spend';
  v_denied := false;
  begin perform public._platform_credit_restore(t.c4, 1, gen_random_uuid());
  exception when insufficient_privilege then v_denied := true; end;
  assert v_denied, 'G: client must not call _platform_credit_restore';
  v_denied := false;
  begin perform 1 from public.platform_credit_accounts limit 1;
  exception when insufficient_privilege then v_denied := true; end;
  assert v_denied, 'G: client must not read platform_credit_accounts';
  v_denied := false;
  begin perform 1 from public.platform_credit_ledger limit 1;
  exception when insufficient_privilege then v_denied := true; end;
  assert v_denied, 'G: client must not read platform_credit_ledger';
  v_denied := false;
  begin perform 1 from public.platform_subsidies limit 1;
  exception when insufficient_privilege then v_denied := true; end;
  assert v_denied, 'G: client must not read platform_subsidies';

  -- The v1 zero-argument read path is gone: a bare call now resolves to
  -- the v2 function (defaulted parameter), whose payload carries applies.
  a := public.my_platform_credit();
  assert a->>'ok' = 'true' and (a ? 'applies') and (a ? 'available'),
    'G: bare call returns the v2 shape';

  -- Anonymous read refused; own balance readable.
  perform set_config('request.jwt.claim.sub', '', true);
  a := public.my_platform_credit(65);
  assert a->>'ok' = 'false' and a->>'code' = 'UNAUTHENTICATED', 'G: anonymous read refused';

  -- A direct client write cannot forge the credit column on orders.
  begin
    update public.orders set platform_credit_applied = 999
     where id = (select id from public.orders where user_id = t.c4 limit 1);
  exception when others then
    if sqlerrm not like '%managed by the order RPCs%' then raise; end if;
  end;
  assert not exists(select 1 from public.orders where user_id=t.c4 and platform_credit_applied=999),
    'G: credit column frozen from clients';
end $$;
reset role;

-- Balance assertions over the locked tables run as the superuser.
do $$ declare t record; a jsonb; begin
  select * into t from zz_ctx;
  assert (select balance from public.platform_credit_accounts where user_id=t.c4) = 30,
    'G: wallet debits cannot touch the gift balance';
  assert (select count(*) from public.platform_credit_ledger where user_id=t.c4 and kind<>'grant') = 0,
    'G: no gift ledger rows from wallet_pay';
  assert (select balance from public.wallets where user_id=t.c4) = 38,
    'G: wallet itself was debited normally';
  perform set_config('request.jwt.claim.sub', t.c4::text, true);
  a := public.my_platform_credit(65);
  assert a->>'ok' = 'true' and (a->>'available')::numeric = 30 and (a->>'applies')::numeric = 30,
    'G: own credit readable';
end $$;

select 'PASS v6: monthly apology cap (boundary + cap + handoff) / v5: spend mechanics, one-grant-per-order, above-goods, full-total, remainder, cancel/reject restore + retry, paid refund + retry, coupon+gift, replay, net-at-settlement in both models + netted subsidy + payables, dispatch ceiling on net, sweep on net obligations, full-credit both models (goods extinguished, 13.95 earned, payables), non-cash netted_noncash, admin payables list + settle-once idempotent + per-kind partial settle + global-scope gate (owner/country OK; regional/unassigned/inactive/customer denied) + void excluded + NULL/invalid kind rejected + real-role ACL (authenticated granted, anon denied) + original-reference replay, wallet_pay immiscibility, client lockdown' as result;
rollback;
