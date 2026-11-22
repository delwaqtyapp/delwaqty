-- Staging rollback-only. Requires migration 400. No outbound messaging.
begin;
create temporary table _t400(o1 uuid, o2 uuid, m1 uuid, m2 uuid);
insert into _t400 values(gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid());
insert into auth.users(id,email,raw_user_meta_data)
select o1,'zz-test-400-owner1@example.invalid','{"full_name":"zz-test-400-o1","user_type":"merchant"}'::jsonb from _t400;
insert into auth.users(id,email,raw_user_meta_data)
select o2,'zz-test-400-owner2@example.invalid','{"full_name":"zz-test-400-o2","user_type":"merchant"}'::jsonb from _t400;
update _t400 set m1=(select id from merchants where owner_user_id=o1),m2=(select id from merchants where owner_user_id=o2);
do $test$
declare m1 uuid:=(select m1 from _t400);m2 uuid:=(select m2 from _t400);o1 uuid:=(select o1 from _t400);o2 uuid:=(select o2 from _t400);
declare pid uuid;drug uuid;r jsonb;sale1 uuid;sale2 uuid;
begin
assert m1 is not null and m2 is not null,'merchant signup triggers created stores';
-- core uniqueness (insert + update), NULL exempt, cross-store allowed
insert into products(merchant_id,name,price,barcode,stock_quantity) values(m1,'zz-test-400-a',10,'6221000001',5);
begin
insert into products(merchant_id,name,price,barcode) values(m1,'zz-test-400-b',20,'6221000001');
raise exception 'duplicate barcode accepted in same store';
exception when unique_violation then null;
end;
insert into products(merchant_id,name,price,barcode) values(m1,'zz-test-400-c',30,'6221000002');
begin
update products set barcode='6221000001' where merchant_id=m1 and name='zz-test-400-c';
raise exception 'duplicate barcode update accepted';
exception when unique_violation then null;
end;
insert into products(merchant_id,name,price) values(m1,'zz-test-400-d',10);
insert into products(merchant_id,name,price,barcode,stock_quantity) values(m2,'zz-test-400-h',10,'6221000001',5);
-- #77 whitespace canonicalization: padded forms trim on write and collide
insert into products(merchant_id,name,price,barcode) values(m1,'zz-test-400-i',10,'  6221000009  ');
assert (select barcode from products where merchant_id=m1 and name='zz-test-400-i')='6221000009','trigger trims on insert';
begin
insert into products(merchant_id,name,price,barcode) values(m1,'zz-test-400-j',10,'6221000009');
raise exception 'padded/trimmed twins accepted';
exception when unique_violation then null;
end;
update products set barcode=' 6221000010 ' where merchant_id=m1 and name='zz-test-400-i';
assert (select barcode from products where merchant_id=m1 and name='zz-test-400-i')='6221000010','trigger trims on update';
update products set barcode='   ' where merchant_id=m1 and name='zz-test-400-i';
assert (select barcode from products where merchant_id=m1 and name='zz-test-400-i') is null,'blank canonicalizes to NULL';
-- import path canonicalization + sequential idempotency (the unique_violation
-- catch covers true two-till concurrency; one session cannot fork a race)
insert into drug_catalog(name_en,name_ar,barcode,official_price_egp,is_active)
values('ZZ TEST 400 DRUG','دواء اختبار',' 6330000001 ',33,true) returning id into drug;
perform set_config('request.jwt.claim.sub',o1::text,true);
select pharmacy_import_drug(drug,m1,33,0) into r;
assert (r->>'ok')::boolean is true and (r->>'duplicate') is null,'first import creates';
assert (select barcode from products where id=(r->>'product_id')::uuid)='6330000001','import writes canonical trimmed barcode';
select pharmacy_import_drug(drug,m1,33,0) into r;
assert (r->>'duplicate')::boolean is true,'re-import returns duplicate:true';
assert (select count(*) from products where merchant_id=m1 and barcode='6330000001')=1,'one product per drug barcode';
-- final sale pricing: server-priced from the products table (client price
-- ignored), discount clamped, per-merchant idempotency with tenant isolation
insert into products(merchant_id,name,price,stock_quantity) values(m1,'zz-test-400-p1',10,100) returning id into pid;
insert into products(merchant_id,name,price,stock_quantity) values(m1,'zz-test-400-p2',25.5,100);
select pos_create_sale(m1,jsonb_build_array(
  jsonb_build_object('product_id',pid,'qty',2,'price',999),
  jsonb_build_object('product_id',(select id from products where merchant_id=m1 and name='zz-test-400-p2'),'qty',1)),
  5,'instapay',null,null,'zz-400-key-1') into r;
assert (r->>'subtotal')::numeric=45.5,'server prices from products table, client price ignored';
assert (r->>'discount')::numeric=5,'discount kept';
assert (r->>'total')::numeric=40.5,'total = subtotal - discount';
sale1:=(r->>'sale_id')::uuid;
select pos_create_sale(m1,jsonb_build_array(
  jsonb_build_object('product_id',pid,'qty',2,'price',999),
  jsonb_build_object('product_id',(select id from products where merchant_id=m1 and name='zz-test-400-p2'),'qty',1)),
  5,'instapay',null,null,'zz-400-key-1') into r;
assert (r->>'idempotent')::boolean is true and (r->>'sale_id')::uuid=sale1,'same-store replay returns original sale';
perform set_config('request.jwt.claim.sub',o2::text,true);
select pos_create_sale(m2,jsonb_build_array(
  jsonb_build_object('product_id',(select id from products where merchant_id=m2 and name='zz-test-400-h'),'qty',1)),
  0,'cash',null,null,'zz-400-key-1') into r;
assert (r->>'idempotent') is null,'same key at another store is a new sale';
sale2:=(r->>'sale_id')::uuid;
assert sale2 is distinct from sale1,'tenant isolation of idempotency keys';
-- security HIGH: offline sync still works against the per-merchant index
-- (the old global constraint is gone; the fixed ON CONFLICT target must
-- match pos_sales_merchant_idempotency_uq, predicate included)
perform set_config('request.jwt.claim.sub',o1::text,true);
select cashier_sync_push(m1,jsonb_build_array(jsonb_build_object(
  'type','sale','op_id','11111111-1111-1111-1111-111111111111',
  'payload',jsonb_build_object(
    'items',jsonb_build_array(jsonb_build_object(
      'product_id',(select id from products where merchant_id=m1 and name='zz-test-400-p1'),
      'qty',1,'unit_price',10)),
    'discount_amount',0,
    'payments',jsonb_build_array(jsonb_build_object('method','cash','amount',10)))))) into r;
assert (r->'results'->0->>'ok')::boolean is true,'offline sale push accepted after 400, got: ' || coalesce(r::text,'null');
assert (r->'results'->0->>'duplicate') is null,'first push is not a duplicate';
select cashier_sync_push(m1,jsonb_build_array(jsonb_build_object(
  'type','sale','op_id','11111111-1111-1111-1111-111111111111',
  'payload',jsonb_build_object(
    'items',jsonb_build_array(jsonb_build_object(
      'product_id',(select id from products where merchant_id=m1 and name='zz-test-400-p1'),
      'qty',1,'unit_price',10)),
    'discount_amount',0,
    'payments',jsonb_build_array(jsonb_build_object('method','cash','amount',10)))))) into r;
assert (r->'results'->0->>'ok')::boolean is true and (r->'results'->0->>'duplicate')::boolean is true,
  'offline sale replay is idempotent after 400';
end $test$;
select 'PASS400: uniqueness+canonicalization, import idempotency, server pricing, per-merchant idempotency, offline sync' result;
rollback;
