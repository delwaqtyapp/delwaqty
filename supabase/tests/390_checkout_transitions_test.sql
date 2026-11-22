-- Staging-only rollback suite after migration 390.
begin;
create temporary table zz_checkout_context(c uuid,m uuid,store uuid,product uuid,o uuid);
insert into zz_checkout_context values(gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),null);
insert into public.users(id,email,full_name,role,user_type,verification_status)
select c,'zz-test-checkout-c@example.invalid','zz-test-checkout-c','customer','customer','approved' from zz_checkout_context union all
select m,'zz-test-checkout-m@example.invalid','zz-test-checkout-m','merchant','merchant','approved' from zz_checkout_context;
insert into public.merchants(id,owner_user_id,name,status,is_open,latitude,longitude,delivery_fee)
select store,m,'zz-test-checkout-store','active',true,0,0,15 from zz_checkout_context;
insert into public.products(id,merchant_id,name,price,is_available,stock_quantity)
select product,store,'zz-test-checkout-product',25,true,100 from zz_checkout_context;
do $$ declare t record; r jsonb; begin
 select * into t from zz_checkout_context;
 perform set_config('request.jwt.claim.sub',t.c::text,true);
 update public.merchants set status='suspended' where id=t.store;
 begin
  perform public.create_order(t.store,jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',1)),'zz-test-address',0.001,0.001);
  raise exception 'TEST_FAIL_SUSPENDED_STORE_ACCEPTED';
 exception when others then if sqlerrm<>'MERCHANT_UNAVAILABLE' then raise; end if; end;
 update public.merchants set status='active',is_open=false where id=t.store;
 begin
  perform public.create_order(t.store,jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',1)),'zz-test-address',0.001,0.001);
  raise exception 'TEST_FAIL_CLOSED_STORE_ACCEPTED';
 exception when others then if sqlerrm<>'MERCHANT_CLOSED' then raise; end if; end;
 update public.merchants set is_open=true where id=t.store;
 r:=public.create_order(t.store,jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',2,'unit_price',0.01)),'zz-test-address',0.001,0.001,'cash',null,null,'zz-test-checkout-replay');
 assert r->>'ok'='true' and (r->>'total_amount')::numeric=65, 'server pricing';
 update zz_checkout_context set o=(r->>'order_id')::uuid;
 r:=public.create_order(t.store,jsonb_build_array(jsonb_build_object('product_id',t.product,'quantity',2)),'zz-test-address',0.001,0.001,'cash',null,null,'zz-test-checkout-replay');
 assert r->>'idempotent_replay'='true', 'checkout replay';
 select * into t from zz_checkout_context;
 assert (select stock_quantity from public.products where id=t.product)=98, 'stock decrement once';
 perform set_config('request.jwt.claim.sub',t.m::text,true);
 r:=public.update_order_status(t.o,'delivered');
 assert r->>'ok'='false' and r->>'code'='USE_COMPLETION_FLOW','cannot skip to delivery';
 r:=public.update_order_status(t.o,'ready');
 assert r->>'ok'='false' and r->>'code'='INVALID_TRANSITION','cannot skip preparation';
 r:=public.update_order_status(t.o,'confirmed'); assert r->>'ok'='true','merchant accepts';
 r:=public.update_order_status(t.o,'preparing'); assert r->>'ok'='true','merchant prepares';
 r:=public.update_order_status(t.o,'ready'); assert r->>'ok'='true','merchant ready';
 r:=public.update_order_status(t.o,'delivering'); assert r->>'code'='DRIVER_REQUIRED','no phantom delivery';
 r:=public.update_order_status(t.o,'preparing'); assert r->>'code'='INVALID_TRANSITION','no backwards move';
 perform set_config('request.jwt.claim.sub',t.c::text,true);
 r:=public.update_order_status(t.o,'confirmed'); assert r->>'code'='FORBIDDEN','customer cannot fulfill';
 r:=public.cancel_order(t.o,'zz-test-cleanup'); assert r->>'ok'='true','customer cancellation';
 assert (select stock_quantity from public.products where id=t.product)=100, 'stock restored';
 perform set_config('request.jwt.claim.sub',t.m::text,true);
 r:=public.update_order_status(t.o,'confirmed'); assert r->>'code'='TERMINAL_STATE','terminal frozen';
end $$;
select 'PASS: availability, pricing/replay, lifecycle, authorization, cancellation stock' as result;
rollback;
