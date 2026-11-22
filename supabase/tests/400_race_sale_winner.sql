-- Winner session of the deterministic two-session race (#96). Holds its
-- transaction open with pg_sleep AFTER the sale insert so the loser
-- (400_race_sale.sql, started ~1.5s later) is guaranteed to block on the
-- advisory lock until this COMMIT, then replay the committed row.
begin;
select set_config('request.jwt.claim.sub','40000000-0000-0000-0000-0000000000a1',true);
select public.pos_create_sale(
  (select id from merchants where owner_user_id='40000000-0000-0000-0000-0000000000a1'),
  jsonb_build_array(jsonb_build_object(
    'product_id',(select p.id from products p join merchants m on m.id=p.merchant_id
      where m.owner_user_id='40000000-0000-0000-0000-0000000000a1'
        and p.name='zz-test-400-race-prod'),
    'qty',2)),
  0,'cash',null,null,'zz-400-race-key') as result;
select pg_sleep(4);
-- last statement so the API returns it: the committed row the loser replays
select id as sale_id, idempotency_key, total_amount from public.pos_sales
where idempotency_key='zz-400-race-key';
commit;
