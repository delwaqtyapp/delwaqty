-- Staging rollback-only. Requires migration 397. No outbound messaging.
-- Covers: auth gates (non-admin), region scoping (in/out-of-scope admin,
-- NULL-region provider), validation ranges, category defaults
-- (owner/country only), scoped listing, provider self view, and the
-- provisioning default seeding.
begin;
create temporary table _t397(
  owner_id uuid, country_admin_id uuid, region_admin_id uuid, customer_id uuid,
  provider_a_user uuid, provider_b_user uuid, provider_c_user uuid,
  provider_a uuid, provider_b uuid, provider_c uuid
);
insert into _t397 values (
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid()
);

-- users (signup trigger builds public.users rows)
insert into auth.users(id,email,raw_user_meta_data)
select owner_id,'zz-test-397-owner@example.invalid','{"full_name":"zz-test-397-owner","user_type":"customer"}'::jsonb from _t397;
insert into auth.users(id,email,raw_user_meta_data)
select country_admin_id,'zz-test-397-cadmin@example.invalid','{"full_name":"zz-test-397-cadmin","user_type":"customer"}'::jsonb from _t397;
insert into auth.users(id,email,raw_user_meta_data)
select region_admin_id,'zz-test-397-radmin@example.invalid','{"full_name":"zz-test-397-radmin","user_type":"customer"}'::jsonb from _t397;
insert into auth.users(id,email,raw_user_meta_data)
select customer_id,'zz-test-397-customer@example.invalid','{"full_name":"zz-test-397-customer","user_type":"customer"}'::jsonb from _t397;
insert into auth.users(id,email,raw_user_meta_data)
select provider_a_user,'zz-test-397-prova@example.invalid','{"full_name":"zz-test-397-prova","user_type":"provider"}'::jsonb from _t397;
insert into auth.users(id,email,raw_user_meta_data)
select provider_b_user,'zz-test-397-provb@example.invalid','{"full_name":"zz-test-397-provb","user_type":"provider"}'::jsonb from _t397;
insert into auth.users(id,email,raw_user_meta_data)
select provider_c_user,'zz-test-397-provc@example.invalid','{"full_name":"zz-test-397-provc","user_type":"provider"}'::jsonb from _t397;

-- roles: owner, country admin (root region, descendants), region admin
-- (Cairo governorate only, descendants), plain customer.
update public.users set role='owner', user_type='owner', verification_status='approved'
 where id=(select owner_id from _t397);
update public.users set role='admin', user_type='admin', verification_status='approved'
 where id in (select country_admin_id from _t397 union select region_admin_id from _t397);
insert into public.admin_management(admin_id, supervisor_id, is_active)
select country_admin_id, owner_id, true from _t397
union all select region_admin_id, country_admin_id, true from _t397;
insert into public.admin_region_assignments(admin_id, region_id, scope)
select country_admin_id, '00000000-0000-0000-0000-000000000001'::uuid, 'descendants' from _t397
union all
select region_admin_id, '00000000-0000-0000-0000-000000000107'::uuid, 'descendants' from _t397;

-- providers: A in Cairo (Qasr El Nil point), B in Alexandria (Bab Sharqi
-- point), C with no coordinates (NULL region).
insert into public.service_providers(id, user_id, name, category_type, is_verified, is_available, hourly_rate, latitude, longitude)
select provider_a, provider_a_user, 'zz-test-397-plumber-a', 'plumbing', true, true, 180, 30.0444, 31.2357 from _t397;
insert into public.service_providers(id, user_id, name, category_type, is_verified, is_available, hourly_rate, latitude, longitude)
select provider_b, provider_b_user, 'zz-test-397-plumber-b', 'plumbing', true, true, 200, 31.2001, 29.9187 from _t397;
insert into public.service_providers(id, user_id, name, category_type, is_verified, is_available, hourly_rate)
select provider_c, provider_c_user, 'zz-test-397-plumber-c', 'plumbing', true, true, 210 from _t397;

do $test$
declare
  v_owner uuid:=(select owner_id from _t397);
  v_cadmin uuid:=(select country_admin_id from _t397);
  v_radmin uuid:=(select region_admin_id from _t397);
  v_customer uuid:=(select customer_id from _t397);
  v_pa_user uuid:=(select provider_a_user from _t397);
  v_pa uuid:=(select provider_a from _t397);
  v_pb uuid:=(select provider_b from _t397);
  v_pc uuid:=(select provider_c from _t397);
  v_err text;
  v_res jsonb;
  v_new_user uuid:=gen_random_uuid();
  v_new_sp uuid;
begin
  -- geography sanity: A under Cairo gov, B outside it
  assert public._admin_covers_region(v_radmin, public._point_region_id(30.0444, 31.2357)),
    'region admin covers Cairo point';
  assert not public._admin_covers_region(v_radmin, public._point_region_id(31.2001, 29.9187)),
    'region admin does not cover Alex point';

  -- 1. non-admin caller refused
  perform set_config('request.jwt.claim.sub', v_customer::text, true);
  begin
    perform public.admin_set_provider_pricing(v_pa, 250, null, null, 'x');
    raise exception 'expected insufficient_privilege';
  exception when others then
    v_err := sqlerrm;
    assert v_err like '%insufficient_privilege%', 'customer refused, got: ' || v_err;
  end;

  -- anonymous caller refused
  perform set_config('request.jwt.claim.sub', '', true);
  begin
    perform public.admin_set_provider_pricing(v_pa, 250, null, null, 'x');
    raise exception 'expected insufficient_privilege';
  exception when others then
    v_err := sqlerrm;
    assert v_err like '%insufficient_privilege%', 'anon refused, got: ' || v_err;
  end;

  -- 2. region admin edits in-scope provider
  perform set_config('request.jwt.claim.sub', v_radmin::text, true);
  v_res := public.admin_set_provider_pricing(v_pa, 250, 300, 500, 'raise for cairo');
  assert (v_res->>'success')::boolean, 'region admin in-scope set ok';
  assert exists(select 1 from public.service_providers
    where id=v_pa and hourly_rate=250 and fixed_price_min=300 and fixed_price_max=500),
    'provider A rates stored';
  assert exists(select 1 from public.activity_logs
    where action='PROVIDER_PRICING_CHANGED' and resource_id=v_pa::text
      and user_id=v_radmin::text),
    'provider pricing audit row written';

  -- 3. region admin refused on out-of-scope provider
  begin
    perform public.admin_set_provider_pricing(v_pb, 999, null, null, null);
    raise exception 'expected outside_region_scope';
  exception when others then
    v_err := sqlerrm;
    assert v_err like '%outside_region_scope%', 'out-of-scope refused, got: ' || v_err;
  end;
  assert exists(select 1 from public.service_providers where id=v_pb and hourly_rate=200),
    'provider B unchanged after refused write';

  -- 4. NULL-region provider is owner/country only
  begin
    perform public.admin_set_provider_pricing(v_pc, 999, null, null, null);
    raise exception 'expected outside_region_scope';
  exception when others then
    v_err := sqlerrm;
    assert v_err like '%outside_region_scope%', 'null-region refused, got: ' || v_err;
  end;

  -- 5. validation ranges (caller otherwise authorized)
  perform set_config('request.jwt.claim.sub', v_cadmin::text, true);
  begin
    perform public.admin_set_provider_pricing(v_pb, -1, null, null, null);
    raise exception 'expected invalid_hourly_rate';
  exception when others then
    v_err := sqlerrm;
    assert v_err like '%invalid_hourly_rate%', 'negative rate refused, got: ' || v_err;
  end;
  begin
    perform public.admin_set_provider_pricing(v_pb, 10001, null, null, null);
    raise exception 'expected invalid_hourly_rate';
  exception when others then
    v_err := sqlerrm;
    assert v_err like '%invalid_hourly_rate%', 'rate above cap refused, got: ' || v_err;
  end;
  begin
    perform public.admin_set_provider_pricing(v_pb, null, 900, 100, null);
    raise exception 'expected fixed_price_min_above_max';
  exception when others then
    v_err := sqlerrm;
    assert v_err like '%fixed_price_min_above_max%', 'min>max refused, got: ' || v_err;
  end;

  -- 6. country admin edits out-of-Cairo provider; owner clears custom rates
  v_res := public.admin_set_provider_pricing(v_pb, 320, null, null, 'country admin');
  assert (v_res->>'success')::boolean, 'country admin set ok';
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  v_res := public.admin_set_provider_pricing(v_pc, null, null, null, 'clear custom');
  assert (v_res->>'success')::boolean, 'owner clears rates ok';
  assert exists(select 1 from public.service_providers
    where id=v_pc and hourly_rate is null and fixed_price_min is null and fixed_price_max is null),
    'provider C rates cleared';

  -- 7. category defaults: region admin and customer refused, country ok
  perform set_config('request.jwt.claim.sub', v_radmin::text, true);
  begin
    perform public.admin_set_category_pricing('plumbing', 220, null, null, 'x');
    raise exception 'expected insufficient_privilege';
  exception when others then
    v_err := sqlerrm;
    assert v_err like '%insufficient_privilege%', 'region admin category write refused, got: ' || v_err;
  end;
  perform set_config('request.jwt.claim.sub', v_customer::text, true);
  begin
    perform public.admin_set_category_pricing('plumbing', 220, null, null, 'x');
    raise exception 'expected insufficient_privilege';
  exception when others then
    v_err := sqlerrm;
    assert v_err like '%insufficient_privilege%', 'customer category write refused, got: ' || v_err;
  end;
  perform set_config('request.jwt.claim.sub', v_cadmin::text, true);
  v_res := public.admin_set_category_pricing('Plumbing', 220, 400, 800, 'country default');
  assert (v_res->>'success')::boolean and v_res->>'category_type' = 'plumbing',
    'category default upserted with canonical type';
  assert exists(select 1 from public.service_category_pricing
    where category_type='plumbing' and hourly_rate=220 and fixed_price_min=400 and fixed_price_max=800),
    'category default stored';
  assert exists(select 1 from public.activity_logs
    where action='CATEGORY_PRICING_CHANGED' and resource_id='plumbing'),
    'category pricing audit row written';
  begin
    perform public.admin_set_category_pricing('no_such_category', 220, null, null, null);
    raise exception 'expected invalid_category';
  exception when others then
    v_err := sqlerrm;
    assert v_err like '%invalid_category%', 'unknown category refused, got: ' || v_err;
  end;

  -- 8. scoped listing: region admin sees A (in scope) but not B or C
  perform set_config('request.jwt.claim.sub', v_radmin::text, true);
  v_res := public.admin_list_provider_pricing('zz-test-397', null, 50, 0);
  assert (v_res->>'total')::int = 1, 'region admin list total=1, got ' || (v_res->>'total');
  assert (select count(*) from jsonb_array_elements(v_res->'items') e
          where e->>'provider_id' = v_pa::text) = 1, 'region admin sees provider A';
  -- customer gets an empty set
  perform set_config('request.jwt.claim.sub', v_customer::text, true);
  v_res := public.admin_list_provider_pricing('zz-test-397', null, 50, 0);
  assert (v_res->>'total')::int = 0, 'customer list empty';
  -- country admin sees A and B and C
  perform set_config('request.jwt.claim.sub', v_cadmin::text, true);
  v_res := public.admin_list_provider_pricing('zz-test-397', null, 50, 0);
  assert (v_res->>'total')::int = 3, 'country admin list total=3, got ' || (v_res->>'total');
  assert (select count(*) from jsonb_array_elements(v_res->'items') e
          where e->>'provider_id' = v_pa::text and (e->>'effective_hourly_rate')::numeric = 250
            and e->>'hourly_source' = 'provider') = 1,
    'provider A effective custom rate in list';

  -- 9. provider self view: A sees own row; category default fills cleared C
  perform set_config('request.jwt.claim.sub', v_pa_user::text, true);
  v_res := public.provider_get_my_pricing();
  assert (select count(*) from jsonb_array_elements(v_res->'items') e
          where e->>'provider_id' = v_pa::text and (e->>'effective_hourly_rate')::numeric = 250
            and e->>'hourly_source' = 'provider') = 1,
    'provider A self view shows custom rate';
  assert (select count(*) from jsonb_array_elements(v_res->'items') e
          where e->>'provider_id' = v_pc::text) = 0,
    'provider A does not see provider C';
  perform set_config('request.jwt.claim.sub', (select provider_c_user from _t397)::text, true);
  v_res := public.provider_get_my_pricing();
  assert (select count(*) from jsonb_array_elements(v_res->'items') e
          where e->>'provider_id' = v_pc::text and (e->>'effective_hourly_rate')::numeric = 220
            and e->>'hourly_source' = 'category') = 1,
    'cleared provider C falls back to category default 220';
  perform set_config('request.jwt.claim.sub', v_customer::text, true);
  v_res := public.provider_get_my_pricing();
  assert jsonb_array_length(v_res->'items') = 0, 'customer self view empty';

  -- 10. provisioning seeds category default, 150 fallback preserved
  insert into auth.users(id,email,raw_user_meta_data)
  values (v_new_user,'zz-test-397-newprov@example.invalid','{"full_name":"zz-test-397-newprov","user_type":"customer"}'::jsonb);
  v_res := public._provision_business_target(v_new_user, 'plumbing', 'zz-test-397-newplumber');
  v_new_sp := (v_res->>'service_provider_id')::uuid;
  assert exists(select 1 from public.service_providers where id=v_new_sp and hourly_rate=220),
    'new provider seeded with category default 220';
  delete from public.service_providers where id=v_new_sp;
  delete from public.service_category_pricing where category_type='electrical';
  v_res := public._provision_business_target(v_new_user, 'electrical', 'zz-test-397-newelectrician');
  v_new_sp := (v_res->>'service_provider_id')::uuid;
  assert exists(select 1 from public.service_providers where id=v_new_sp and hourly_rate=150),
    'no category default keeps 150 fallback';

  perform set_config('request.jwt.claim.sub', '', true);
end $test$;
select 'PASS397: auth gates, region scope, null region, validation, category defaults, scoped list, self view, provisioning defaults' result;
rollback;
