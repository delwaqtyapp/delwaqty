-- 395 v2: two-session concurrency proof for platform credit checkout.
-- STAGING ONLY. This script COMMITS synthetic zz-race fixtures (rollback
-- cannot span two sessions) and the cleanup section deletes them again.
-- Run section by section: setup -> race_same_1 & race_same_2 (parallel)
-- -> race_diff_1 & race_diff_2 (parallel) -> verify -> cleanup.
-- Extract a section with: awk '/-- == NAME ==/{f=1;next}/-- == /{if(f)exit}f'

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
        'zz-race-product',25,true,100);
select public._platform_credit_grant('face0000-0000-4000-8000-0000000000c2', 20, null);
select public._platform_credit_grant('face0000-0000-4000-8000-0000000000c3', 20, null);

-- == race_same_1 ==
select set_config('request.jwt.claim.sub','face0000-0000-4000-8000-0000000000c2',true);
select pg_sleep(1.5);
select public.create_order('face0000-0000-4000-8000-000000000051',
  jsonb_build_array(jsonb_build_object('product_id','face0000-0000-4000-8000-000000000061','quantity',2)),
  'zz-race-address', 0.001, 0.001, 'cash', null, null, 'zz-race-same');

-- == race_same_2 ==
select set_config('request.jwt.claim.sub','face0000-0000-4000-8000-0000000000c2',true);
select pg_sleep(1.5);
select public.create_order('face0000-0000-4000-8000-000000000051',
  jsonb_build_array(jsonb_build_object('product_id','face0000-0000-4000-8000-000000000061','quantity',2)),
  'zz-race-address', 0.001, 0.001, 'cash', null, null, 'zz-race-same');

-- == race_diff_1 ==
select set_config('request.jwt.claim.sub','face0000-0000-4000-8000-0000000000c3',true);
select pg_sleep(1.5);
select public.create_order('face0000-0000-4000-8000-000000000051',
  jsonb_build_array(jsonb_build_object('product_id','face0000-0000-4000-8000-000000000061','quantity',2)),
  'zz-race-address', 0.001, 0.001, 'cash', null, null, 'zz-race-diff-1');

-- == race_diff_2 ==
select set_config('request.jwt.claim.sub','face0000-0000-4000-8000-0000000000c3',true);
select pg_sleep(1.5);
select public.create_order('face0000-0000-4000-8000-000000000051',
  jsonb_build_array(jsonb_build_object('product_id','face0000-0000-4000-8000-000000000061','quantity',2)),
  'zz-race-address', 0.001, 0.001, 'cash', null, null, 'zz-race-diff-2');

-- == verify ==
do $$
declare
  v_orders int; v_applied numeric; v_balance numeric; v_spends int; v_same int;
begin
  -- Same-key race: exactly one order exists for the key and it spent once.
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
select 'PASS: concurrent same-key single order/spend; concurrent different-key spends exactly the balance once' as race_result;

-- == cleanup ==
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
delete from public.order_items where order_id in
  (select id from public.orders where idempotency_key like 'zz-race-%');
delete from public.orders where idempotency_key like 'zz-race-%';
delete from public.products where id='face0000-0000-4000-8000-000000000061';
delete from public.merchants where id='face0000-0000-4000-8000-000000000051';
delete from auth.users where email like 'zz-race-%@example.invalid';
select 'zz-race fixtures removed' as cleanup;
