-- Staging rollback-only. Requires migration 397. No outbound messaging.
-- Runs the permission matrix under SET LOCAL ROLE authenticated/anon with
-- request.jwt.claim.sub (PostgREST semantics), not JWT-sub-only privilege:
-- owner, country admin, region admin in/out of scope, NULL-region provider,
-- inactive admin, unassigned admin, provider, customer, anon; plus direct
-- table-write refusals, partial-call/clear semantics, inherited-pricing
-- resolver behavior, booking floor parity, pagination, audit correctness,
-- and provisioning inheritance.
begin;

create temporary table _t397(
  owner_id uuid, country_admin_id uuid, region_admin_id uuid,
  inactive_admin_id uuid, unassigned_admin_id uuid,
  customer_id uuid,
  provider_a_user uuid, provider_b_user uuid, provider_c_user uuid,
  provider_e_user uuid, provider_f_user uuid,
  provider_a uuid, provider_b uuid, provider_c uuid,
  provider_e uuid, provider_f uuid
);
insert into _t397 values (
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
  gen_random_uuid(), gen_random_uuid(),
  gen_random_uuid(),
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
  gen_random_uuid(), gen_random_uuid(),
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
  gen_random_uuid(), gen_random_uuid()
);

grant select on _t397 to anon, authenticated;

-- ---------- fixtures (as postgres; rolled back at the end) ----------
insert into auth.users(id,email,raw_user_meta_data)
select owner_id,'zz-test-397-owner@example.invalid','{"full_name":"zz-test-397-owner","user_type":"customer"}'::jsonb from _t397
union all select country_admin_id,'zz-test-397-cadmin@example.invalid','{"full_name":"zz-test-397-cadmin","user_type":"customer"}'::jsonb from _t397
union all select region_admin_id,'zz-test-397-radmin@example.invalid','{"full_name":"zz-test-397-radmin","user_type":"customer"}'::jsonb from _t397
union all select inactive_admin_id,'zz-test-397-iadmin@example.invalid','{"full_name":"zz-test-397-iadmin","user_type":"customer"}'::jsonb from _t397
union all select unassigned_admin_id,'zz-test-397-uadmin@example.invalid','{"full_name":"zz-test-397-uadmin","user_type":"customer"}'::jsonb from _t397
union all select customer_id,'zz-test-397-customer@example.invalid','{"full_name":"zz-test-397-customer","user_type":"customer"}'::jsonb from _t397
union all select provider_a_user,'zz-test-397-prova@example.invalid','{"full_name":"zz-test-397-prova","user_type":"provider"}'::jsonb from _t397
union all select provider_b_user,'zz-test-397-provb@example.invalid','{"full_name":"zz-test-397-provb","user_type":"provider"}'::jsonb from _t397
union all select provider_c_user,'zz-test-397-provc@example.invalid','{"full_name":"zz-test-397-provc","user_type":"provider"}'::jsonb from _t397
union all select provider_e_user,'zz-test-397-prove@example.invalid','{"full_name":"zz-test-397-prove","user_type":"provider"}'::jsonb from _t397
union all select provider_f_user,'zz-test-397-provf@example.invalid','{"full_name":"zz-test-397-provf","user_type":"provider"}'::jsonb from _t397;

update public.users set role='owner', user_type='owner', verification_status='approved'
 where id=(select owner_id from _t397);
update public.users set role='admin', user_type='admin', verification_status='approved'
 where id in (select country_admin_id from _t397
              union select region_admin_id from _t397
              union select inactive_admin_id from _t397
              union select unassigned_admin_id from _t397);

-- active country admin, active region admin, INACTIVE admin (row present,
-- is_active false), UNASSIGNED admin (active row, no region assignment).
insert into public.admin_management(admin_id, supervisor_id, is_active)
select country_admin_id, owner_id, true from _t397
union all select region_admin_id, country_admin_id, true from _t397
union all select inactive_admin_id, owner_id, false from _t397
union all select unassigned_admin_id, owner_id, true from _t397;
insert into public.admin_region_assignments(admin_id, region_id, scope)
select country_admin_id, '00000000-0000-0000-0000-000000000001'::uuid, 'descendants' from _t397
union all
select region_admin_id, '00000000-0000-0000-0000-000000000107'::uuid, 'descendants' from _t397
union all
select inactive_admin_id, '00000000-0000-0000-0000-000000000001'::uuid, 'descendants' from _t397;

-- providers: A in Cairo, B in Alexandria, C no coordinates (NULL region),
-- E 'electrical' (used for the platform-fallback case), F booking parity.
insert into public.service_providers(id, user_id, name, category_type, is_verified, is_available, hourly_rate, latitude, longitude)
select provider_a, provider_a_user, 'zz-test-397-plumber-a', 'plumbing', true, true, 180, 30.0444, 31.2357 from _t397;
insert into public.service_providers(id, user_id, name, category_type, is_verified, is_available, hourly_rate, latitude, longitude)
select provider_b, provider_b_user, 'zz-test-397-plumber-b', 'plumbing', true, true, 200, 31.2001, 29.9187 from _t397;
insert into public.service_providers(id, user_id, name, category_type, is_verified, is_available, hourly_rate)
select provider_c, provider_c_user, 'zz-test-397-plumber-c', 'plumbing', true, true, 210 from _t397;
insert into public.service_providers(id, user_id, name, category_type, is_verified, is_available, latitude, longitude)
select provider_e, provider_e_user, 'zz-test-397-electrician-e', 'electrical', true, true, 30.0444, 31.2357 from _t397;
insert into public.service_providers(id, user_id, name, category_type, is_verified, is_available, latitude, longitude)
select provider_f, provider_f_user, 'zz-test-397-plumber-f', 'plumbing', true, true, 30.0444, 31.2357 from _t397;

-- ---------- S1. permission gates (valid arg shapes: the call must reach
-- the auth check, never a parse error) ----------
-- true anon role: EXECUTE revoked, permission denied.
set local role anon;
do $test$
declare v_err text; v_pa uuid:=(select provider_a from _t397);
begin
  begin
    perform public.admin_set_provider_pricing(v_pa, 250, null, null, '{}'::text[], 'x');
    raise exception 'expected refusal for anon';
  exception when others then
    v_err := sqlerrm;
    assert v_err like '%permission denied%' or v_err like '%insufficient_privilege%',
      'anon refused, got: ' || v_err;
  end;
end $test$;
reset role;

-- authenticated with no JWT sub: treated as unauthenticated.
set local role authenticated;
select set_config('request.jwt.claim.sub', '', true);
do $test$
declare v_err text; v_pa uuid:=(select provider_a from _t397);
begin
  begin
    perform public.admin_set_provider_pricing(v_pa, 250, null, null, '{}'::text[], 'x');
    raise exception 'expected insufficient_privilege';
  exception when others then
    v_err := sqlerrm;
    assert v_err like '%insufficient_privilege%', 'no-sub refused, got: ' || v_err;
  end;
end $test$;
reset role;

-- customer
set local role authenticated;
select set_config('request.jwt.claim.sub', (select customer_id::text from _t397), true);
do $test$
declare v_err text; v_pa uuid:=(select provider_a from _t397);
begin
  begin
    perform public.admin_set_provider_pricing(v_pa, 250, null, null, '{}'::text[], 'x');
    raise exception 'expected insufficient_privilege';
  exception when others then
    v_err := sqlerrm;
    assert v_err like '%insufficient_privilege%', 'customer refused, got: ' || v_err;
  end;
  begin
    perform public.admin_set_category_pricing('plumbing', 220, null, null, 'x');
    raise exception 'expected insufficient_privilege';
  exception when others then
    v_err := sqlerrm;
    assert v_err like '%insufficient_privilege%', 'customer category refused, got: ' || v_err;
  end;
  assert (public.admin_list_provider_pricing('zz-test-397', null, 50, 0)->>'total')::int = 0,
    'customer list empty';
end $test$;
reset role;

-- provider (not an admin)
set local role authenticated;
select set_config('request.jwt.claim.sub', (select provider_a_user::text from _t397), true);
do $test$
declare v_err text; v_pa uuid:=(select provider_a from _t397);
begin
  begin
    perform public.admin_set_provider_pricing(v_pa, 250, null, null, '{}'::text[], null);
    raise exception 'expected insufficient_privilege';
  exception when others then
    v_err := sqlerrm;
    assert v_err like '%insufficient_privilege%', 'provider refused, got: ' || v_err;
  end;
end $test$;
reset role;

-- inactive admin (admin_management row present but is_active false)
set local role authenticated;
select set_config('request.jwt.claim.sub', (select inactive_admin_id::text from _t397), true);
do $test$
declare v_err text; v_pa uuid:=(select provider_a from _t397);
begin
  begin
    perform public.admin_set_provider_pricing(v_pa, 250, null, null, '{}'::text[], null);
    raise exception 'expected insufficient_privilege';
  exception when others then
    v_err := sqlerrm;
    assert v_err like '%insufficient_privilege%', 'inactive admin refused, got: ' || v_err;
  end;
end $test$;
reset role;

-- unassigned admin (active, no region assignment): active but scope-empty.
set local role authenticated;
select set_config('request.jwt.claim.sub', (select unassigned_admin_id::text from _t397), true);
do $test$
declare v_err text; v_pa uuid:=(select provider_a from _t397);
begin
  begin
    perform public.admin_set_provider_pricing(v_pa, 250, null, null, '{}'::text[], null);
    raise exception 'expected outside_region_scope';
  exception when others then
    v_err := sqlerrm;
    assert v_err like '%outside_region_scope%', 'unassigned admin refused, got: ' || v_err;
  end;
  begin
    perform public.admin_set_category_pricing('plumbing', 220, null, null, null);
    raise exception 'expected insufficient_privilege';
  exception when others then
    v_err := sqlerrm;
    assert v_err like '%insufficient_privilege%', 'unassigned category refused, got: ' || v_err;
  end;
  assert (public.admin_list_provider_pricing('zz-test-397', null, 50, 0)->>'total')::int = 0,
    'unassigned admin list empty';
end $test$;
reset role;

-- ---------- S2. region admin: in-scope ok, out-of-scope + NULL-region refused ----------
set local role authenticated;
select set_config('request.jwt.claim.sub', (select region_admin_id::text from _t397), true);
do $test$
declare
  v_err text; v_res jsonb;
  v_pa uuid:=(select provider_a from _t397);
  v_pb uuid:=(select provider_b from _t397);
  v_pc uuid:=(select provider_c from _t397);
begin
  v_res := public.admin_set_provider_pricing(v_pa, 250, 300, 500, '{}'::text[], 'raise for cairo');
  assert (v_res->>'success')::boolean, 'region admin in-scope set ok';
  assert (v_res->>'hourly_rate')::numeric = 250
     and (v_res->>'fixed_price_min')::numeric = 300
     and (v_res->>'fixed_price_max')::numeric = 500, 'stored triple returned';

  begin
    perform public.admin_set_provider_pricing(v_pb, 999, null, null, '{}'::text[], null);
    raise exception 'expected outside_region_scope';
  exception when others then
    v_err := sqlerrm;
    assert v_err like '%outside_region_scope%', 'out-of-scope refused, got: ' || v_err;
  end;

  begin
    perform public.admin_set_provider_pricing(v_pc, 999, null, null, '{}'::text[], null);
    raise exception 'expected outside_region_scope';
  exception when others then
    v_err := sqlerrm;
    assert v_err like '%outside_region_scope%', 'null-region refused, got: ' || v_err;
  end;

  begin
    perform public.admin_set_category_pricing('plumbing', 220, null, null, 'x');
    raise exception 'expected insufficient_privilege';
  exception when others then
    v_err := sqlerrm;
    assert v_err like '%insufficient_privilege%', 'region admin category refused, got: ' || v_err;
  end;

  -- scoped list: sees only the Cairo fixtures (A, E, F), never B or C
  v_res := public.admin_list_provider_pricing('zz-test-397', null, 50, 0);
  assert (v_res->>'total')::int = 3, 'region admin list total=3 (A,E,F), got ' || (v_res->>'total');
  assert (select count(*) from jsonb_array_elements(v_res->'items') e
          where e->>'provider_id' in (v_pa::text,
            (select provider_e from _t397)::text,
            (select provider_f from _t397)::text)) = 3,
    'region admin sees exactly the Cairo providers';
  assert (select count(*) from jsonb_array_elements(v_res->'items') e
          where e->>'provider_id' in (v_pb::text, v_pc::text)) = 0,
    'region admin does not see out-of-scope or NULL-region providers';
end $test$;
reset role;

-- privileged assertions for S2
do $test$
declare
  v_pa uuid:=(select provider_a from _t397);
  v_pb uuid:=(select provider_b from _t397);
  v_radmin uuid:=(select region_admin_id from _t397);
begin
  assert exists(select 1 from public.service_providers
    where id=v_pa and hourly_rate=250 and fixed_price_min=300 and fixed_price_max=500),
    'provider A rates stored';
  assert exists(select 1 from public.service_providers where id=v_pb and hourly_rate=200),
    'provider B unchanged after refused write';
  assert exists(select 1 from public.activity_logs
    where action='PROVIDER_PRICING_CHANGED' and resource_id=v_pa::text and user_id=v_radmin::text),
    'provider pricing audit row written';
  -- the fixture INSERT of A also audited (old = null); the RPC write adds
  -- exactly one row carrying a real old value
  assert (select count(*) from public.activity_logs
    where action='PROVIDER_PRICING_CHANGED' and resource_id=v_pa::text
      and details->>'old' is not null) = 1,
    'exactly one audit row for the RPC write (trigger + RPC share one entry)';
end $test$;

-- ---------- S3. country admin: validation, provider + category writes, pagination ----------
set local role authenticated;
select set_config('request.jwt.claim.sub', (select country_admin_id::text from _t397), true);
do $test$
declare
  v_err text; v_res jsonb;
  v_pb uuid:=(select provider_b from _t397);
begin
  begin
    perform public.admin_set_provider_pricing(v_pb, -1, null, null, '{}'::text[], null);
    raise exception 'expected invalid_hourly_rate';
  exception when others then
    v_err := sqlerrm;
    assert v_err like '%invalid_hourly_rate%', 'negative rate refused, got: ' || v_err;
  end;
  begin
    perform public.admin_set_provider_pricing(v_pb, 10001, null, null, '{}'::text[], null);
    raise exception 'expected invalid_hourly_rate';
  exception when others then
    v_err := sqlerrm;
    assert v_err like '%invalid_hourly_rate%', 'rate above cap refused, got: ' || v_err;
  end;
  begin
    perform public.admin_set_provider_pricing(v_pb, null, 900, 100, '{}'::text[], null);
    raise exception 'expected fixed_price_min_above_max';
  exception when others then
    v_err := sqlerrm;
    assert v_err like '%fixed_price_min_above_max%', 'min>max refused, got: ' || v_err;
  end;
  begin
    perform public.admin_set_provider_pricing(v_pb, null, null, null, '{bogus_field}'::text[], null);
    raise exception 'expected invalid_clear_fields';
  exception when others then
    v_err := sqlerrm;
    assert v_err like '%invalid_clear_fields%', 'bogus clear field refused, got: ' || v_err;
  end;

  v_res := public.admin_set_provider_pricing(v_pb, 320, null, null, '{}'::text[], 'country admin');
  assert (v_res->>'success')::boolean, 'country admin set ok';

  -- category default: case-insensitive input, canonical storage
  v_res := public.admin_set_category_pricing('Plumbing', 220, 400, 900, 'country default');
  assert (v_res->>'success')::boolean and v_res->>'category_type' = 'plumbing',
    'category default upserted with canonical type';
  begin
    perform public.admin_set_category_pricing('no_such_category', 220, null, null, null);
    raise exception 'expected invalid_category';
  exception when others then
    v_err := sqlerrm;
    assert v_err like '%invalid_category%', 'unknown category refused, got: ' || v_err;
  end;

  -- pagination: 4 plumbing fixtures (A,B,C,F), stable order by lower(name)
  v_res := public.admin_list_provider_pricing('zz-test-397-plumber-', null, 2, 0);
  assert (v_res->>'total')::int = 4, 'country list total=4, got ' || (v_res->>'total');
  assert jsonb_array_length(v_res->'items') = 2, 'page 1 has 2 items';
  assert (select count(*) from jsonb_array_elements(v_res->'items') e
          where e->>'provider_id' in (select provider_a::text from _t397
                                      union select provider_b::text from _t397)) = 2,
    'page 1 = providers A and B';
  v_res := public.admin_list_provider_pricing('zz-test-397-plumber-', null, 2, 2);
  assert jsonb_array_length(v_res->'items') = 2, 'page 2 has 2 items';
  assert (select count(*) from jsonb_array_elements(v_res->'items') e
          where e->>'provider_id' in (select provider_c::text from _t397
                                      union select provider_f::text from _t397)) = 2,
    'page 2 = providers C and F';
end $test$;
reset role;

do $test$
declare
  v_cadmin uuid:=(select country_admin_id from _t397);
begin
  assert exists(select 1 from public.service_category_pricing
    where category_type='plumbing' and hourly_rate=220 and fixed_price_min=400 and fixed_price_max=900),
    'category default stored';
  assert exists(select 1 from public.activity_logs
    where action='CATEGORY_PRICING_CHANGED' and resource_id='plumbing' and user_id=v_cadmin::text),
    'category pricing audit row written';
end $test$;

-- ---------- S4. partial-call semantics: NULL = unchanged, clear = explicit ----------
set local role authenticated;
select set_config('request.jwt.claim.sub', (select country_admin_id::text from _t397), true);
do $test$
declare
  v_res jsonb;
  v_pb uuid:=(select provider_b from _t397);
begin
  -- pair-only call: hourly must stay 320
  v_res := public.admin_set_provider_pricing(v_pb, null, 700, 800, '{}'::text[], 'set pair only');
  assert (v_res->>'hourly_rate')::numeric = 320
     and (v_res->>'fixed_price_min')::numeric = 700
     and (v_res->>'fixed_price_max')::numeric = 800,
    'pair-only call kept hourly, set pair';

  -- hourly-only call: pair must stay 700..800
  v_res := public.admin_set_provider_pricing(v_pb, 333, null, null, '{}'::text[], 'hourly only');
  assert (v_res->>'hourly_rate')::numeric = 333
     and (v_res->>'fixed_price_min')::numeric = 700
     and (v_res->>'fixed_price_max')::numeric = 800,
    'hourly-only call did not wipe the fixed pair';

  -- explicit clear of the pair: hourly untouched
  v_res := public.admin_set_provider_pricing(v_pb, null, null, null,
    '{fixed_price_min,fixed_price_max}'::text[], 'clear pair');
  assert (v_res->>'hourly_rate')::numeric = 333
     and v_res->>'fixed_price_min' is null
     and v_res->>'fixed_price_max' is null,
    'explicit clear wiped only the pair';
end $test$;
reset role;

-- ---------- S5. owner clears provider C completely -> inherits category ----------
set local role authenticated;
select set_config('request.jwt.claim.sub', (select owner_id::text from _t397), true);
do $test$
declare
  v_res jsonb;
  v_pc uuid:=(select provider_c from _t397);
begin
  v_res := public.admin_set_provider_pricing(v_pc, null, null, null,
    '{hourly_rate,fixed_price_min,fixed_price_max}'::text[], 'clear custom');
  assert (v_res->>'success')::boolean, 'owner clears rates ok';
  assert (v_res->'pricing'->>'hourly_source') = 'category'
     and (v_res->'pricing'->>'hourly_rate')::numeric = 220
     and (v_res->'pricing'->>'fixed_price_min')::numeric = 400
     and (v_res->'pricing'->>'fixed_price_max')::numeric = 900
     and (v_res->'pricing'->>'fixed_source') = 'category',
    'cleared provider C inherits the category default live';
end $test$;
reset role;

do $test$
declare v_pc uuid:=(select provider_c from _t397);
begin
  assert exists(select 1 from public.service_providers
    where id=v_pc and hourly_rate is null and fixed_price_min is null and fixed_price_max is null),
    'provider C rates cleared to NULL';
end $test$;

-- ---------- S6. live inheritance: category change flows through; provider override wins ----------
set local role authenticated;
select set_config('request.jwt.claim.sub', (select country_admin_id::text from _t397), true);
do $test$
declare v_res jsonb;
begin
  v_res := public.admin_set_category_pricing('plumbing', 230, 400, 900, 'bump hourly');
  assert (v_res->>'success')::boolean, 'category hourly bumped';
end $test$;
reset role;

do $test$
declare
  v_pa uuid:=(select provider_a from _t397);
  v_pc uuid:=(select provider_c from _t397);
  v_eff jsonb;
begin
  v_eff := public.service_provider_effective_pricing(v_pc);
  assert (v_eff->>'hourly_rate')::numeric = 230 and v_eff->>'hourly_source' = 'category',
    'category change flows to inheriting provider C live';
  v_eff := public.service_provider_effective_pricing(v_pa);
  assert (v_eff->>'hourly_rate')::numeric = 250 and v_eff->>'hourly_source' = 'provider'
     and (v_eff->>'fixed_price_min')::numeric = 300 and (v_eff->>'fixed_price_max')::numeric = 500
     and v_eff->>'fixed_source' = 'provider',
    'provider override wins over category default';
end $test$;

-- ---------- S7. platform fallback 150 when no category default exists ----------
delete from public.service_category_pricing where category_type='electrical';
do $test$
declare
  v_pe uuid:=(select provider_e from _t397);
  v_eff jsonb;
begin
  v_eff := public.service_provider_effective_pricing(v_pe);
  assert (v_eff->>'hourly_rate')::numeric = 150 and v_eff->>'hourly_source' = 'platform'
     and v_eff->>'fixed_price_min' is null and v_eff->>'fixed_source' = 'none',
    'no category default -> platform fallback 150';
end $test$;

-- ---------- S8. booking floor parity with the resolver ----------
do $test$
declare
  v_pf uuid:=(select provider_f from _t397);
  v_cust uuid:=(select customer_id from _t397);
  v_est numeric;
begin
  -- category plumbing fixed pair currently 400..900, provider F pair NULL
  insert into public.service_bookings(user_id, provider_id, scheduled_date, scheduled_time, estimated_price)
  values (v_cust, v_pf, current_date + 1, '10:00', 100)
  returning estimated_price into v_est;
  assert v_est = 400, 'booking floor = category fixed min 400, got ' || v_est;

  insert into public.service_bookings(user_id, provider_id, scheduled_date, scheduled_time, estimated_price)
  values (v_cust, v_pf, current_date + 1, '11:00', null)
  returning estimated_price into v_est;
  assert v_est = 400, 'null estimate lifts to floor 400, got ' || v_est;

  insert into public.service_bookings(user_id, provider_id, scheduled_date, scheduled_time, estimated_price)
  values (v_cust, v_pf, current_date + 1, '12:00', 600)
  returning estimated_price into v_est;
  assert v_est = 600, 'estimate above floor untouched, got ' || v_est;
end $test$;

set local role authenticated;
select set_config('request.jwt.claim.sub', (select country_admin_id::text from _t397), true);
do $test$
declare v_res jsonb; v_pf uuid:=(select provider_f from _t397);
begin
  v_res := public.admin_set_category_pricing('plumbing', 230, 450, 900, 'raise floor');
  assert (v_res->>'success')::boolean, 'category floor raised';
end $test$;
reset role;

do $test$
declare
  v_pf uuid:=(select provider_f from _t397);
  v_cust uuid:=(select customer_id from _t397);
  v_est numeric;
begin
  insert into public.service_bookings(user_id, provider_id, scheduled_date, scheduled_time, estimated_price)
  values (v_cust, v_pf, current_date + 1, '10:00', 100)
  returning estimated_price into v_est;
  assert v_est = 450, 'category change flows to booking floor 450, got ' || v_est;
end $test$;

set local role authenticated;
select set_config('request.jwt.claim.sub', (select country_admin_id::text from _t397), true);
do $test$
declare v_res jsonb; v_pf uuid:=(select provider_f from _t397);
begin
  v_res := public.admin_set_provider_pricing(v_pf, null, 700, 800, '{}'::text[], 'provider pair');
  assert (v_res->>'success')::boolean, 'provider pair set';
end $test$;
reset role;

do $test$
declare
  v_pf uuid:=(select provider_f from _t397);
  v_cust uuid:=(select customer_id from _t397);
  v_est numeric;
begin
  insert into public.service_bookings(user_id, provider_id, scheduled_date, scheduled_time, estimated_price)
  values (v_cust, v_pf, current_date + 1, '10:00', 100)
  returning estimated_price into v_est;
  assert v_est = 700, 'provider pair override wins in booking floor, got ' || v_est;

  -- half pair (min only) is NOT an override: the whole pair follows the category
  update public.service_providers
     set fixed_price_min = 500, fixed_price_max = null
   where id = v_pf;
  insert into public.service_bookings(user_id, provider_id, scheduled_date, scheduled_time, estimated_price)
  values (v_cust, v_pf, current_date + 1, '11:00', 100)
  returning estimated_price into v_est;
  assert v_est = 450, 'half pair falls back to category floor 450, got ' || v_est;
end $test$;

-- ---------- S9. direct table writes ----------
-- provider editing own row: sensitive-fields guard refuses pricing columns
set local role authenticated;
select set_config('request.jwt.claim.sub', (select provider_a_user::text from _t397), true);
do $test$
declare v_err text; v_pa uuid:=(select provider_a from _t397);
begin
  begin
    update public.service_providers set hourly_rate = 999 where id = v_pa;
    raise exception 'expected guard refusal';
  exception when others then
    v_err := sqlerrm;
    assert v_err like '%managed by the admin RPCs%', 'provider direct write refused, got: ' || v_err;
  end;
end $test$;
reset role;

-- customer direct update: no RLS grant, silently affects 0 rows
set local role authenticated;
select set_config('request.jwt.claim.sub', (select customer_id::text from _t397), true);
do $test$
declare v_pa uuid:=(select provider_a from _t397);
begin
  update public.service_providers set hourly_rate = 999 where id = v_pa;
end $test$;
reset role;
do $test$
declare v_pa uuid:=(select provider_a from _t397);
begin
  assert exists(select 1 from public.service_providers where id=v_pa and hourly_rate=250),
    'customer direct update changed nothing';
end $test$;

-- region admin direct table write: allowed by policy, validated + audited
set local role authenticated;
select set_config('request.jwt.claim.sub', (select region_admin_id::text from _t397), true);
do $test$
declare v_err text; v_pa uuid:=(select provider_a from _t397);
begin
  update public.service_providers set hourly_rate = 260 where id = v_pa;
  begin
    update public.service_providers set hourly_rate = -5 where id = v_pa;
    raise exception 'expected invalid_hourly_rate';
  exception when others then
    v_err := sqlerrm;
    assert v_err like '%invalid_hourly_rate%', 'direct write validated, got: ' || v_err;
  end;
end $test$;
reset role;
do $test$
declare
  v_pa uuid:=(select provider_a from _t397);
  v_radmin uuid:=(select region_admin_id from _t397);
begin
  assert exists(select 1 from public.service_providers where id=v_pa and hourly_rate=260),
    'admin direct write stored';
  assert exists(select 1 from public.activity_logs
    where action='PROVIDER_PRICING_CHANGED' and resource_id=v_pa::text and user_id=v_radmin::text
      and (details->'new'->>'hourly_rate')::numeric = 260),
    'admin direct write audited';
end $test$;

-- category table: no direct writes for authenticated at all (even an admin)
set local role authenticated;
select set_config('request.jwt.claim.sub', (select country_admin_id::text from _t397), true);
do $test$
declare v_err text;
begin
  begin
    insert into public.service_category_pricing(category_type, hourly_rate)
    values ('plumbing', 1);
    raise exception 'expected permission denied';
  exception when others then
    v_err := sqlerrm;
    assert v_err like '%permission denied%', 'category direct insert refused, got: ' || v_err;
  end;
  begin
    update public.service_category_pricing set hourly_rate = 1 where category_type='plumbing';
    raise exception 'expected permission denied';
  exception when others then
    v_err := sqlerrm;
    assert v_err like '%permission denied%', 'category direct update refused, got: ' || v_err;
  end;
  begin
    delete from public.service_category_pricing where category_type='plumbing';
    raise exception 'expected permission denied';
  exception when others then
    v_err := sqlerrm;
    assert v_err like '%permission denied%', 'category direct delete refused, got: ' || v_err;
  end;
end $test$;
reset role;

-- ---------- S10. audit correctness across consecutive category edits ----------
set local role authenticated;
select set_config('request.jwt.claim.sub', (select country_admin_id::text from _t397), true);
do $test$
declare v_res jsonb;
begin
  v_res := public.admin_set_category_pricing('plumbing', 240, 450, 900, 'second bump');
  assert (v_res->>'success')::boolean, 'second category bump ok';
end $test$;
reset role;
do $test$
declare v_old numeric; v_new numeric;
begin
  -- all rows share the transaction timestamp, so match by the new value
  select (details->'old'->>'hourly_rate')::numeric,
         (details->'new'->>'hourly_rate')::numeric
    into v_old, v_new
    from public.activity_logs
   where action='CATEGORY_PRICING_CHANGED' and resource_id='plumbing'
     and (details->'new'->>'hourly_rate')::numeric = 240;
  assert v_old = 230 and v_new = 240,
    'audit row logs the true old value (row locked FOR UPDATE), got '
      || v_old || ' -> ' || v_new;
end $test$;

-- ---------- S11. provider self view ----------
set local role authenticated;
select set_config('request.jwt.claim.sub', (select provider_a_user::text from _t397), true);
do $test$
declare
  v_res jsonb;
  v_pa uuid:=(select provider_a from _t397);
  v_pc uuid:=(select provider_c from _t397);
begin
  v_res := public.provider_get_my_pricing();
  assert (select count(*) from jsonb_array_elements(v_res->'items') e
          where e->>'provider_id' = v_pa::text
            and (e->>'effective_hourly_rate')::numeric = 260
            and e->>'hourly_source' = 'provider'
            and e->>'fixed_source' = 'provider'
            and (e->>'admin_managed')::boolean) = 1,
    'provider A self view shows own effective rates + sources';
  assert (select count(*) from jsonb_array_elements(v_res->'items') e
          where e->>'provider_id' = v_pc::text) = 0,
    'provider A does not see provider C';
end $test$;
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', (select provider_c_user::text from _t397), true);
do $test$
declare
  v_res jsonb;
  v_pc uuid:=(select provider_c from _t397);
begin
  v_res := public.provider_get_my_pricing();
  assert (select count(*) from jsonb_array_elements(v_res->'items') e
          where e->>'provider_id' = v_pc::text
            and (e->>'effective_hourly_rate')::numeric = 240
            and e->>'hourly_source' = 'category') = 1,
    'cleared provider C self view inherits the category default';
end $test$;
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', (select customer_id::text from _t397), true);
do $test$
declare v_res jsonb;
begin
  v_res := public.provider_get_my_pricing();
  assert jsonb_array_length(v_res->'items') = 0, 'customer self view empty';
end $test$;
reset role;

-- ---------- S12. provisioning inherits live (NULL override) ----------
do $test$
declare
  v_new_user uuid:=gen_random_uuid();
  v_res jsonb;
  v_new_sp uuid;
  v_eff jsonb;
begin
  insert into auth.users(id,email,raw_user_meta_data)
  values (v_new_user,'zz-test-397-newprov@example.invalid','{"full_name":"zz-test-397-newprov","user_type":"customer"}'::jsonb);
  v_res := public._provision_business_target(v_new_user, 'plumbing', 'zz-test-397-newplumber');
  v_new_sp := (v_res->>'service_provider_id')::uuid;
  assert exists(select 1 from public.service_providers where id=v_new_sp and hourly_rate is null),
    'new provider stored with NULL override (inherits live)';
  v_eff := public.service_provider_effective_pricing(v_new_sp);
  assert (v_eff->>'hourly_rate')::numeric = 240 and v_eff->>'hourly_source' = 'category',
    'new provider resolves to the live category default';
end $test$;

-- ---------- S13. pagination beyond 200 rows: the 201st is reachable ----------
insert into public.service_providers(id, user_id, name, category_type, is_verified, is_available, latitude, longitude)
select gen_random_uuid(), (select provider_a_user from _t397),
       'zz-test-397p-bulk-' || lpad(g::text, 3, '0'), 'plumbing', true, true,
       30.0444, 31.2357
  from generate_series(1, 205) g;

set local role authenticated;
select set_config('request.jwt.claim.sub', (select country_admin_id::text from _t397), true);
do $test$
declare
  v_res jsonb;
  v_ids text[] := '{}';
  v_page text[];
  v_off int;
  v_expected uuid;
begin
  -- five fixed-size pages of 50 must cover all 205 rows exactly once
  for v_off in select generate_series(0, 200, 50) loop
    v_res := public.admin_list_provider_pricing('zz-test-397p-bulk', null, 50, v_off);
    assert (v_res->>'total')::int = 205, 'bulk total=205, got ' || (v_res->>'total');
    assert jsonb_array_length(v_res->'items') = least(50, 205 - v_off),
      'page at offset ' || v_off || ' size wrong';
    select array_agg(x->>'provider_id') into v_page
      from jsonb_array_elements(v_res->'items') x;
    v_ids := v_ids || v_page;
  end loop;
  v_ids := (select array_agg(distinct unn) from (select unnest(v_ids) unn) u);
  assert array_length(v_ids, 1) = 205,
    'pages cover 205 distinct rows (201st reachable), got ' || coalesce(array_length(v_ids, 1), 0);

  -- stable order: page 5's first row is the 201st of lower(name), id
  select id into v_expected
    from public.service_providers
   where name like 'zz-test-397p-bulk%'
   order by lower(name), id
   offset 200 limit 1;
  v_res := public.admin_list_provider_pricing('zz-test-397p-bulk', null, 50, 200);
  assert (v_res->'items'->0->>'provider_id')::uuid = v_expected,
    'offset 200 first row = 201st by lower(name), id';
end $test$;
reset role;

-- ---------- S14. customer-facing view shows the resolved price ----------
update public.service_providers set is_available = false
 where id = (select provider_b from _t397);

set local role anon;
do $test$
declare
  v_pa uuid:=(select provider_a from _t397);
  v_pb uuid:=(select provider_b from _t397);
  v_pc uuid:=(select provider_c from _t397);
  v_pf uuid:=(select provider_f from _t397);
  v_rec record;
begin
  -- provider override shows as-is
  select effective_hourly_rate, hourly_source into v_rec
    from public.service_providers_with_effective_pricing where id = v_pa;
  assert v_rec.effective_hourly_rate = 260 and v_rec.hourly_source = 'provider',
    'view: provider override shown';

  -- inherited NULL hourly shows the live category rate
  select effective_hourly_rate, hourly_source into v_rec
    from public.service_providers_with_effective_pricing where id = v_pc;
  assert v_rec.effective_hourly_rate = 240 and v_rec.hourly_source = 'category',
    'view: inherited NULL hourly shows category rate';

  -- half fixed pair shows what the booking normalizer uses (category pair)
  select effective_fixed_price_min, effective_fixed_price_max, fixed_source into v_rec
    from public.service_providers_with_effective_pricing where id = v_pf;
  assert v_rec.effective_fixed_price_min = 450 and v_rec.effective_fixed_price_max = 900
     and v_rec.fixed_source = 'category',
    'view: half pair resolves to the booking-truth category pair';

  -- base-table RLS still applies through the view
  assert not exists(select 1 from public.service_providers_with_effective_pricing where id = v_pb),
    'view: unavailable provider hidden from anon';
end $test$;
reset role;

-- ---------- S15. guard covers INSERT: validation + audit on create ----------
set local role authenticated;
select set_config('request.jwt.claim.sub', (select region_admin_id::text from _t397), true);
do $test$
declare
  v_err text;
  v_id uuid := gen_random_uuid();
  v_user uuid := (select provider_e_user from _t397);
begin
  begin
    insert into public.service_providers(id, user_id, name, category_type, is_verified, is_available, hourly_rate, latitude, longitude)
    values (v_id, v_user, 'zz-test-397-insert-bad', 'plumbing', true, true, -5, 30.0444, 31.2357);
    raise exception 'expected invalid_hourly_rate';
  exception when others then
    v_err := sqlerrm;
    assert v_err like '%invalid_hourly_rate%', 'insert validated, got: ' || v_err;
  end;

  insert into public.service_providers(id, user_id, name, category_type, is_verified, is_available, hourly_rate, latitude, longitude)
  values (v_id, v_user, 'zz-test-397-insert-ok', 'plumbing', true, true, 300, 30.0444, 31.2357);
end $test$;
reset role;
do $test$
declare v_radmin uuid:=(select region_admin_id from _t397);
begin
  assert exists(select 1 from public.activity_logs
    where action='PROVIDER_PRICING_CHANGED' and user_id=v_radmin::text
      and details->>'old' is null
      and (details->'new'->>'hourly_rate')::numeric = 300),
    'insert with pricing audited (old = null)';
end $test$;

-- ---------- S16. category first-time insert logs a true (empty) old row ----------
delete from public.service_category_pricing where category_type = 'painting';
set local role authenticated;
select set_config('request.jwt.claim.sub', (select country_admin_id::text from _t397), true);
do $test$
declare v_res jsonb;
begin
  v_res := public.admin_set_category_pricing('painting', 180, null, null, 'first paint default');
  assert (v_res->>'success')::boolean, 'first-time category insert ok';
end $test$;
reset role;
do $test$
begin
  assert exists(select 1 from public.activity_logs
    where action='CATEGORY_PRICING_CHANGED' and resource_id='painting'
      and details->'old'->>'hourly_rate' is null
      and (details->'new'->>'hourly_rate')::numeric = 180),
    'first-time category insert audited with empty old row';
end $test$;

select set_config('request.jwt.claim.sub', '', true);
select 'PASS397: set-role matrix (owner/country/region/in+out/null/inactive/unassigned/provider/customer/anon), validation, partial+clear semantics, inheritance + fallback 150, booking floor parity, direct-write refusals + admin audit, audit sequence, self view, 205-row pagination reaching the 201st, customer view resolver parity + RLS, insert guard, category first-insert audit, provisioning' result;
rollback;
