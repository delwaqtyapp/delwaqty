-- Verify + cleanup for the two-session race test (#96).
do $$
declare v_m uuid; v_sale uuid; v_stock int; v_sales int; v_comm int;
begin
  select id into v_m from merchants where owner_user_id='40000000-0000-0000-0000-0000000000a1';
  select count(*) into v_sales from pos_sales
   where merchant_id=v_m and idempotency_key='zz-400-race-key';
  select id into v_sale from pos_sales
   where merchant_id=v_m and idempotency_key='zz-400-race-key'
   order by created_at limit 1;
  assert v_sales = 1, 'exactly one sale for the raced key, got ' || v_sales;
  select stock_quantity into v_stock from products
   where merchant_id=v_m and name='zz-test-400-race-prod';
  assert v_stock = 48, 'stock decremented exactly once (50-2), got ' || v_stock;
  select count(*) into v_comm from platform_commissions
   where reference_type='pos_sale' and reference_id=v_sale;
  assert v_comm <= 1, 'commission posted at most once, got ' || v_comm;
  delete from platform_commissions where reference_type='pos_sale' and reference_id=v_sale;
  delete from pos_sales where id=v_sale;
  delete from products where merchant_id=v_m;
  delete from merchants where id=v_m;
  delete from auth.users where id='40000000-0000-0000-0000-0000000000a1';
end $$;
select 'PASS400RACE: one sale, stock -2 once, commission at most once, fixtures cleaned' result;
