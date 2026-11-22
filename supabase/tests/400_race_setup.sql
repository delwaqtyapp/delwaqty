-- Committed fixtures for the two-session pos_create_sale race test (#96).
-- Cleaned up by 400_race_verify_cleanup.sql.
insert into auth.users(id,email,raw_user_meta_data)
values('40000000-0000-0000-0000-0000000000a1','zz-test-400-race-owner@example.invalid','{"full_name":"zz-test-400-race","user_type":"merchant"}'::jsonb);
insert into products(merchant_id,name,price,stock_quantity)
select m.id,'zz-test-400-race-prod',10,50 from merchants m
where m.owner_user_id='40000000-0000-0000-0000-0000000000a1';
select 'SETUP400RACE ok' result;
