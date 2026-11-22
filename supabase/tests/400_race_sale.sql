-- Loser session of the deterministic two-session race (#96): started while
-- the winner (400_race_sale_winner.sql) still holds its transaction open,
-- so it blocks on pg_advisory_xact_lock and must return the idempotent
-- replay of the winner's committed sale.
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
commit;
