-- Staging rollback-only. Requires migration 400. No outbound messaging.
begin;
create temporary table _t400(o1 uuid, o2 uuid);
insert into _t400 values(gen_random_uuid(),gen_random_uuid());
insert into auth.users(id,email,raw_user_meta_data)
select o1,'zz-test-400-owner1@example.invalid','{"full_name":"zz-test-400-o1","user_type":"merchant"}'::jsonb from _t400;
insert into auth.users(id,email,raw_user_meta_data)
select o2,'zz-test-400-owner2@example.invalid','{"full_name":"zz-test-400-o2","user_type":"merchant"}'::jsonb from _t400;
do $test$
declare m1 uuid;m2 uuid;
begin
select id into m1 from merchants where owner_user_id=(select o1 from _t400);
select id into m2 from merchants where owner_user_id=(select o2 from _t400);
assert m1 is not null and m2 is not null,'merchant signup triggers created stores';
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
insert into products(merchant_id,name,price) values(m1,'zz-test-400-e',10);
insert into products(merchant_id,name,price,barcode) values(m1,'zz-test-400-f',10,'');
insert into products(merchant_id,name,price,barcode) values(m1,'zz-test-400-g',10,'  ');
insert into products(merchant_id,name,price,barcode) values(m2,'zz-test-400-h',10,'6221000001');
assert (select count(*) from products where merchant_id=m1)=6,'store 1 keeps 6 rows';
assert (select count(*) from products where merchant_id=m2)=1,'store 2 keeps 1 row';
end $test$;
select 'PASS400: duplicate barcode rejected per store (insert+update), NULL/blank exempt, cross-store allowed' result;
rollback;
