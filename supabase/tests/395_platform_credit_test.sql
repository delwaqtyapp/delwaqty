-- Staging-only rollback suite for migration 395 (delay-apology platform
-- credit spendable at checkout). Synthetic zz-test fixtures; every row and
-- the schema change effects under test are rolled back. No real accounts,
-- no real balances: all wallet writes happen inside this transaction.
begin;
create temporary table zz_credit_ctx(c uuid,m uuid,store uuid,product uuid,o1 uuid,o2 uuid,o3 uuid,o4 uuid,o5 uuid,o6 uuid);
insert into zz_credit_ctx(c,m,store,product) values(gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid());
-- auth.users rows are required because write_audit dual-writes audit_log,
-- whose actor FK points at auth.users. handle_new_user auto-creates the
-- public.users profile from the auth.users insert, so only patch it here.
insert into auth.users(id,email)
select c,'zz-test-credit-c@example.invalid' from zz_credit_ctx union all
select m,'zz-test-credit-m@example.invalid' from zz_credit_ctx;
update public.users set full_name='zz-test-credit-c', role='customer', user_type='customer', verification_status='approved' where id=(select c from zz_credit_ctx);
update public.users set full_name='zz-test-credit-m', role='merchant', user_type='merchant', verification_status='approved' where id=(select m from zz_credit_ctx);
insert into public.merchants(id,owner_user_id,name,status,is_open,latitude,longitude,delivery_fee)
select store,m,'zz-test-credit-store','active',true,0,0,15 from zz_credit_ctx;
insert into public.products(id,merchant_id,name,price,is_available,stock_quantity)
select product,store,'zz-test-credit-product',25,true,100 from zz_credit_ctx;

do $$ declare t record; r jsonb; begin
 select * into t from zz_credit_ctx;
 perform set_config('request.jwt.claim.sub',t.c::text,true);

 -- 1) No credit: order is untouched.
 r:=public.create_order(t.store,jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',2)),'zz-test-address',0.001,0.001);
 assert r->>'ok'='true' and (r->>'total_amount')::numeric=65 and (r->>'platform_credit_applied')::numeric=0, 'no credit, no discount';
 update zz_credit_ctx set o1=(r->>'order_id')::uuid;

 -- The delay handler's own grant path: a 20 EGP apology gift.
 perform public._wallet_credit(t.c,20,'zz-test apology grant','delay_apology',(select o1 from zz_credit_ctx));
 assert public._platform_credit_available(t.c)=20, 'grant visible as platform credit';
 assert (select (public.my_platform_credit())->>'available')::numeric=20, 'app read path sees the gift';

 -- 2) Credit smaller than the total: 65 due -> 45 after 20 credit.
 r:=public.create_order(t.store,jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',2)),'zz-test-address',0.001,0.001);
 assert (r->>'total_amount')::numeric=45 and (r->>'platform_credit_applied')::numeric=20, 'credit applied to next order';
 update zz_credit_ctx set o2=(r->>'order_id')::uuid; select * into t from zz_credit_ctx;
 assert public._platform_credit_available(t.c)=0, 'credit is spent once';
 assert (select balance from public.wallets where user_id=t.c)=0, 'wallet debited by the applied credit';
 assert (select count(*) from public.wallet_transactions wt join public.wallets w on w.id=wt.wallet_id
         where w.user_id=t.c and wt.type='debit' and wt.reference_type='delay_apology_spend'
           and wt.reference_id=t.o2 and wt.amount=20 and wt.balance_after=0)=1, 'spend ledger row with order reference';
 assert exists(select 1 from public.activity_logs where action='PLATFORM_CREDIT_APPLIED' and resource_id=t.o2::text), 'spend audit row';
 assert (select platform_credit_applied from public.orders where id=t.o2)=20, 'order records the credit';

 -- 3) Credit larger than the total: 100 gift vs 65 due -> total 0, never negative.
 perform public._wallet_credit(t.c,100,'zz-test apology grant 2','delay_apology',t.o2);
 r:=public.create_order(t.store,jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',2)),'zz-test-address',0.001,0.001);
 assert (r->>'total_amount')::numeric=0 and (r->>'platform_credit_applied')::numeric=65, 'credit cannot exceed the order total';
 update zz_credit_ctx set o3=(r->>'order_id')::uuid; select * into t from zz_credit_ctx;
 assert public._platform_credit_available(t.c)=35, 'unspent remainder survives';
 assert (select balance from public.wallets where user_id=t.c)=35, 'wallet keeps the remainder';

 -- 4) The remainder applies to the following order.
 r:=public.create_order(t.store,jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',2)),'zz-test-address',0.001,0.001);
 assert (r->>'total_amount')::numeric=30 and (r->>'platform_credit_applied')::numeric=35, 'remainder applies once';
 update zz_credit_ctx set o4=(r->>'order_id')::uuid; select * into t from zz_credit_ctx;
 assert public._platform_credit_available(t.c)=0, 'remainder spent once';
 assert (select balance from public.wallets where user_id=t.c)=0, 'wallet fully spent';

 -- 5) Customer cancel returns the credit (same rule as coupons).
 r:=public.cancel_order(t.o2,'zz-test-cancel');
 assert r->>'ok'='true', 'cancel executes';
 assert public._platform_credit_available(t.c)=20, 'cancel restores the credit';
 assert (select balance from public.wallets where user_id=t.c)=20, 'wallet re-credited';
 assert (select count(*) from public.wallet_transactions wt join public.wallets w on w.id=wt.wallet_id
         where w.user_id=t.c and wt.type='credit' and wt.reference_type='delay_apology_restore'
           and wt.reference_id=t.o2 and wt.amount=20)=1, 'restore ledger row';
 assert exists(select 1 from public.activity_logs where action='PLATFORM_CREDIT_RESTORED' and resource_id=t.o2::text), 'restore audit row';

 -- 6) Merchant rejection also returns the credit.
 r:=public.create_order(t.store,jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',2)),'zz-test-address',0.001,0.001);
 assert (r->>'platform_credit_applied')::numeric=20, 'credit re-applied';
 update zz_credit_ctx set o5=(r->>'order_id')::uuid; select * into t from zz_credit_ctx;
 perform set_config('request.jwt.claim.sub',t.m::text,true);
 r:=public.merchant_reject_order(t.o5,'zz-test-reject');
 assert r->>'ok'='true', 'merchant reject executes';
 perform set_config('request.jwt.claim.sub',t.c::text,true);
 assert public._platform_credit_available(t.c)=20, 'merchant reject restores the credit';

 -- 7) Idempotent replay never double-spends.
 r:=public.create_order(t.store,jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',2)),'zz-test-address',0.001,0.001,'cash',null,null,'zz-credit-replay');
 assert (r->>'platform_credit_applied')::numeric=20, 'first call spends';
 update zz_credit_ctx set o6=(r->>'order_id')::uuid; select * into t from zz_credit_ctx;
 r:=public.create_order(t.store,jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',2)),'zz-test-address',0.001,0.001,'cash',null,null,'zz-credit-replay');
 assert r->>'idempotent_replay'='true', 'replay short-circuits';
 assert public._platform_credit_available(t.c)=0, 'no double spend on replay';
 assert (select count(*) from public.wallet_transactions wt join public.wallets w on w.id=wt.wallet_id
         where w.user_id=t.c and wt.type='debit' and wt.reference_type='delay_apology_spend'
           and wt.reference_id=t.o6)=1, 'single spend ledger row for the replayed order';
end $$;

-- Client-surface checks as the authenticated role.
grant select on zz_credit_ctx to authenticated;
set local role authenticated;
do $$ declare t record; r jsonb; v_denied boolean; begin
 select * into t from zz_credit_ctx;

 -- The spend helper is internal: a client cannot mint discounts.
 v_denied:=false;
 begin
  perform public._platform_credit_spend(t.c,t.o1,10);
 exception when insufficient_privilege then v_denied:=true; end;
 assert v_denied, 'client must not call _platform_credit_spend';

 v_denied:=false;
 begin
  perform public._platform_credit_available(t.c);
 exception when insufficient_privilege then v_denied:=true; end;
 assert v_denied, 'client must not call _platform_credit_available directly';

 -- The ledger view for the app requires a signed-in user.
 perform set_config('request.jwt.claim.sub','',true);
 r:=public.my_platform_credit();
 assert r->>'ok'='false' and r->>'code'='UNAUTHENTICATED', 'anonymous read refused';
 perform set_config('request.jwt.claim.sub',t.c::text,true);
 r:=public.my_platform_credit();
 assert r->>'ok'='true' and (r->>'available')::numeric=0, 'own credit readable';

 -- A direct client write cannot forge or tamper with the credit column.
 begin
  update public.orders set platform_credit_applied=999 where id=t.o1;
 exception when others then
  if sqlerrm not like '%managed by the order RPCs%' then raise; end if;
 end;
 assert (select platform_credit_applied from public.orders where id=t.o1)=0, 'credit column frozen from clients';
end $$;
reset role;
select 'PASS: apply, cap at total, single spend, remainder, cancel/reject restore, replay, client lockdown' as result;
rollback;
