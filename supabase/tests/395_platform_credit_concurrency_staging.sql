-- 395 v3: two-session concurrency proof for platform credit checkout.
-- *** COMMITTED-FIXTURE STAGING TEST — NOT a rollback-only suite. ***
-- Real two-session races need committed rows, so every section commits.
-- Run section by section: setup -> race_same_1 & race_same_2 (parallel)
-- -> race_diff_1 & race_diff_2 (parallel) -> verify -> cleanup.
-- Extract a section with: awk '/-- == NAME ==/{f=1;next}/-- == /{if(f)exit}f'
-- Each race section is one explicit transaction so set_config(...,true)
-- covers the create_order call.

-- == setup ==
insert into auth.users(id,email) values
  ('face0000-0000-4000-8000-0000000000c2','zz-race-c2@example.invalid'),
  ('face0000-0000-4000-8000-0000000000c3','zz-race-c3@example.invalid'),
  ('face0000-0000-4000-8000-0000000000aa','zz-race-m@example.invalid')
on conflict (id) do nothing;
update public.users set role='customer', user_type='customer', verification_status='approved'
where id in ('face0000-0000-4000-8000-0000000000c2','face0000-0000-4000-8000-0000000000c3');
update public.users set role='merchant', user_type='merchant', verification_status='approved'
where id = 'face0000-0000-4000-8000-0000000000aa';
insert into public.merchants(id,owner_user_id,name,status,is_open,latitude,longitude,delivery_fee,type)
values ('face0000-0000-4000-8000-000000000051','face0000-0000-4000-8000-0000000000aa',
        'zz-race-store','active',true,0,0,15,'restaurant');
insert into public.products(id,merchant_id,name,price,is_available,stock_quantity)
values ('face0000-0000-4000-8000-000000000061','face0000-0000-4000-8000-000000000051',
        'zz-race-product',25,true,100),
       ('face0000-0000-4000-8000-000000000062','face0000-0000-4000-8000-000000000051',
        'zz-race-product-2',25,true,100);
insert into public.coupons(code, description, discount_type, discount_value, minimum_order, usage_limit, is_active)
values ('ZZ-RACE5', 'zz race coupon', 'fixed', 5, 0, 10, true);
select public._platform_credit_grant('face0000-0000-4000-8000-0000000000c2', 20, null);
select public._platform_credit_grant('face0000-0000-4000-8000-0000000000c3', 20, null);

-- == race_same_1 ==
begin;
select set_config('request.jwt.claim.sub','face0000-0000-4000-8000-0000000000c2',true);
select pg_sleep(1.5);
select public.create_order('face0000-0000-4000-8000-000000000051',
  jsonb_build_array(jsonb_build_object('product_id','face0000-0000-4000-8000-000000000061','quantity',2)),
  'zz-race-address', 0.001, 0.001, 'cash', 'ZZ-RACE5', null, 'zz-race-same');
commit;

-- == race_same_2 ==
begin;
select set_config('request.jwt.claim.sub','face0000-0000-4000-8000-0000000000c2',true);
select pg_sleep(1.5);
select public.create_order('face0000-0000-4000-8000-000000000051',
  jsonb_build_array(jsonb_build_object('product_id','face0000-0000-4000-8000-000000000061','quantity',2)),
  'zz-race-address', 0.001, 0.001, 'cash', 'ZZ-RACE5', null, 'zz-race-same');
commit;

-- == race_diff_1 ==
begin;
select set_config('request.jwt.claim.sub','face0000-0000-4000-8000-0000000000c3',true);
select pg_sleep(1.5);
select public.create_order('face0000-0000-4000-8000-000000000051',
  jsonb_build_array(jsonb_build_object('product_id','face0000-0000-4000-8000-000000000062','quantity',2)),
  'zz-race-address', 0.001, 0.001, 'cash', null, null, 'zz-race-diff-1');
commit;

-- == race_diff_2 ==
begin;
select set_config('request.jwt.claim.sub','face0000-0000-4000-8000-0000000000c3',true);
select pg_sleep(1.5);
select public.create_order('face0000-0000-4000-8000-000000000051',
  jsonb_build_array(jsonb_build_object('product_id','face0000-0000-4000-8000-000000000062','quantity',2)),
  'zz-race-address', 0.001, 0.001, 'cash', null, null, 'zz-race-diff-2');
commit;

-- == verify ==
do $$
declare
  v_orders int; v_applied numeric; v_spends int; v_same int;
  v_stock numeric; v_used int; v_redemptions int;
begin
  -- Same-key race: exactly one order, one gift spend, one stock
  -- decrement, one coupon redemption — the loser's side effects must not
  -- commit (the advisory lock replays it before any mutation).
  select count(*) into v_same from public.orders
   where user_id='face0000-0000-4000-8000-0000000000c2' and idempotency_key='zz-race-same';
  assert v_same = 1, 'same-key race must create exactly one order, got ' || v_same;
  select count(*) into v_spends from public.platform_credit_ledger l
   join public.orders o on o.id = l.order_id
   where o.user_id='face0000-0000-4000-8000-0000000000c2' and l.kind='spend';
  assert v_spends = 1, 'same-key race must spend exactly once, got ' || v_spends;
  assert (select balance from public.platform_credit_accounts
           where user_id='face0000-0000-4000-8000-0000000000c2') = 0,
    'same-key race must spend the 20 once';
  select stock_quantity into v_stock from public.products
   where id='face0000-0000-4000-8000-000000000061';
  assert v_stock = 98, 'same-key race must decrement stock once (2 units), stock=' || v_stock;
  select used_count into v_used from public.coupons where code='ZZ-RACE5';
  assert v_used = 1, 'same-key race must redeem the coupon once, used_count=' || v_used;
  select count(*) into v_redemptions from public.coupon_redemptions cr
   join public.coupons cp on cp.id = cr.coupon_id
   where cp.code='ZZ-RACE5' and cr.user_id='face0000-0000-4000-8000-0000000000c2';
  assert v_redemptions = 1, 'same-key race must write one redemption row, got ' || v_redemptions;

  -- Different-key race: two orders, but the 20 covers only one of them.
  select count(*), coalesce(sum(platform_credit_applied),0) into v_orders, v_applied
    from public.orders
   where user_id='face0000-0000-4000-8000-0000000000c3'
     and idempotency_key in ('zz-race-diff-1','zz-race-diff-2');
  assert v_orders = 2, 'diff-key race must create two orders, got ' || v_orders;
  assert v_applied = 20, 'diff-key race must spend exactly 20 across both orders, got ' || v_applied;
  assert (select balance from public.platform_credit_accounts
           where user_id='face0000-0000-4000-8000-0000000000c3') = 0,
    'diff-key race leaves balance 0';
  assert (select count(*) from public.platform_credit_ledger l
           join public.orders o on o.id = l.order_id
           where o.user_id='face0000-0000-4000-8000-0000000000c3' and l.kind='spend') = 1,
    'diff-key race: only the lock winner writes a spend row';
  assert (select greatest(max(total_amount), 0) from public.orders
           where user_id='face0000-0000-4000-8000-0000000000c3'
             and idempotency_key in ('zz-race-diff-1','zz-race-diff-2')) = 65,
    'diff-key race: the loser pays full price (no negative, no over-spend)';
end $$;
select 'PASS: same-key race -> single order/spend/stock decrement/coupon redemption; diff-key race -> balance spent exactly once' as race_result;

-- == cleanup ==
delete from public.notifications where data->>'order_id' in
  (select id::text from public.orders where idempotency_key like 'zz-race-%');
delete from public.platform_subsidies where order_id in
  (select id from public.orders where idempotency_key like 'zz-race-%');
delete from public.platform_credit_ledger where user_id in
  ('face0000-0000-4000-8000-0000000000c2','face0000-0000-4000-8000-0000000000c3');
delete from public.platform_credit_accounts where user_id in
  ('face0000-0000-4000-8000-0000000000c2','face0000-0000-4000-8000-0000000000c3');
delete from public.activity_logs where user_id in
  ('face0000-0000-4000-8000-0000000000c2','face0000-0000-4000-8000-0000000000c3',
   'face0000-0000-4000-8000-0000000000aa');
delete from public.audit_log where actor in
  ('face0000-0000-4000-8000-0000000000c2','face0000-0000-4000-8000-0000000000c3',
   'face0000-0000-4000-8000-0000000000aa');
delete from public.coupon_redemptions where user_id in
  ('face0000-0000-4000-8000-0000000000c2','face0000-0000-4000-8000-0000000000c3');
delete from public.coupons where code='ZZ-RACE5';
delete from public.order_items where order_id in
  (select id from public.orders where idempotency_key like 'zz-race-%');
delete from public.orders where idempotency_key like 'zz-race-%';
delete from public.products where id in ('face0000-0000-4000-8000-000000000061','face0000-0000-4000-8000-000000000062');
delete from public.merchants where id='face0000-0000-4000-8000-000000000051';
delete from auth.users where email like 'zz-race-%@example.invalid';
select 'zz-race fixtures removed' as cleanup;
