-- Delwaqty: pgTAP gate for the 439..451 hardening postures (builder, Nov 26 2026)
-- Run by CI job "pgTAP RLS negative tests" after redteam_pgtap_negative_rls.sql.
-- Requires: usebasejump/supabase-test-helpers (same setup as the redteam suite).
--
-- Every expectation was verified against the deterministic 439..451 chain
-- (h435_template + 439..448 + prod PostGIS posture + 449 + 451) on 2026-11-26.
-- If one of these fails, a migration has reopened a hole or dropped a revoke.
-- Never "fix" a failure by deleting the test.
--
-- Deliberately NOT pinned here (known, intentional, tracked elsewhere):
--   * base-table SELECT on merchants/products/service_providers (452 HELD)
--   * anon EXECUTE on _merchant_is_active / _owns_merchant_row (policy
--     helpers; revocation is a recorded LOW follow-up)
--   * RLS flags on individual tables (the redteam suite's generic
--     RLS-on-every-table test owns that gate)

begin;

select plan(35);

select tests.create_supabase_user('gate_customer', 'gate-customer@example.invalid');

-- ------------------------------------------------------------------
-- 1. 448 anon write lockdown: anon holds no INSERT/UPDATE/DELETE on
--    the money / PII / staff tables (9 tests).
-- ------------------------------------------------------------------
select ok(
  not has_table_privilege('anon', 'public.wallets', 'INSERT')
  and not has_table_privilege('anon', 'public.wallets', 'UPDATE')
  and not has_table_privilege('anon', 'public.wallets', 'DELETE'),
  'anon: no INSERT/UPDATE/DELETE on wallets');
select ok(
  not has_table_privilege('anon', 'public.wallet_transactions', 'INSERT')
  and not has_table_privilege('anon', 'public.wallet_transactions', 'UPDATE')
  and not has_table_privilege('anon', 'public.wallet_transactions', 'DELETE'),
  'anon: no INSERT/UPDATE/DELETE on wallet_transactions');
select ok(
  not has_table_privilege('anon', 'public.orders', 'INSERT')
  and not has_table_privilege('anon', 'public.orders', 'UPDATE')
  and not has_table_privilege('anon', 'public.orders', 'DELETE'),
  'anon: no INSERT/UPDATE/DELETE on orders');
select ok(
  not has_table_privilege('anon', 'public.users', 'INSERT')
  and not has_table_privilege('anon', 'public.users', 'UPDATE')
  and not has_table_privilege('anon', 'public.users', 'DELETE'),
  'anon: no INSERT/UPDATE/DELETE on users');
select ok(
  not has_table_privilege('anon', 'public.audit_log', 'INSERT')
  and not has_table_privilege('anon', 'public.audit_log', 'UPDATE')
  and not has_table_privilege('anon', 'public.audit_log', 'DELETE'),
  'anon: no INSERT/UPDATE/DELETE on audit_log');
select ok(
  not has_table_privilege('anon', 'public.coupons', 'INSERT')
  and not has_table_privilege('anon', 'public.coupons', 'UPDATE')
  and not has_table_privilege('anon', 'public.coupons', 'DELETE'),
  'anon: no INSERT/UPDATE/DELETE on coupons');
select ok(
  not has_table_privilege('anon', 'public.merchant_staff', 'INSERT')
  and not has_table_privilege('anon', 'public.merchant_staff', 'UPDATE')
  and not has_table_privilege('anon', 'public.merchant_staff', 'DELETE'),
  'anon: no INSERT/UPDATE/DELETE on merchant_staff');
select ok(
  not has_table_privilege('anon', 'public.staff_provisioning', 'INSERT')
  and not has_table_privilege('anon', 'public.staff_provisioning', 'UPDATE')
  and not has_table_privilege('anon', 'public.staff_provisioning', 'DELETE'),
  'anon: no INSERT/UPDATE/DELETE on staff_provisioning');
select ok(
  not has_table_privilege('anon', 'public.staff_admin_refusals', 'INSERT')
  and not has_table_privilege('anon', 'public.staff_admin_refusals', 'UPDATE')
  and not has_table_privilege('anon', 'public.staff_admin_refusals', 'DELETE'),
  'anon: no INSERT/UPDATE/DELETE on staff_admin_refusals');

-- ------------------------------------------------------------------
-- 2. Staff/internal tables are not client-readable at all (4 tests).
-- ------------------------------------------------------------------
select ok(
  not has_table_privilege('anon', 'public.staff_provisioning', 'SELECT'),
  'anon: staff_provisioning unreadable');
select ok(
  not has_table_privilege('authenticated', 'public.staff_provisioning', 'SELECT'),
  'authenticated: staff_provisioning unreadable');
select ok(
  not has_table_privilege('anon', 'public.staff_admin_refusals', 'SELECT'),
  'anon: staff_admin_refusals unreadable');
select ok(
  not has_table_privilege('authenticated', 'public.staff_admin_refusals', 'SELECT'),
  'authenticated: staff_admin_refusals unreadable');

-- ------------------------------------------------------------------
-- 3. Function EXECUTE postures (14 tests).
-- ------------------------------------------------------------------
-- 451 owner/admin surfaces: executable by signed-in users, never anon.
select ok(
  not has_function_privilege('anon', 'public.get_my_merchant_profile(uuid)', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.get_my_merchant_profile(uuid)', 'EXECUTE'),
  '451: get_my_merchant_profile(uuid) authenticated-only');
select ok(
  not has_function_privilege('anon', 'public.get_my_products_count(uuid)', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.get_my_products_count(uuid)', 'EXECUTE'),
  '451: get_my_products_count(uuid) authenticated-only');
select ok(
  not has_function_privilege('anon', 'public.get_my_products_by_ids(uuid,uuid[])', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.get_my_products_by_ids(uuid,uuid[])', 'EXECUTE'),
  '451: get_my_products_by_ids(uuid,uuid[]) authenticated-only');
select ok(
  not has_function_privilege('anon', 'public.admin_get_merchants_count()', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.admin_get_merchants_count()', 'EXECUTE'),
  '451: admin_get_merchants_count() authenticated-only');
-- 449 zero-arg profile: never anon.
select ok(
  not has_function_privilege('anon', 'public.get_my_merchant_profile()', 'EXECUTE'),
  '449: get_my_merchant_profile() not executable by anon');
-- 445 cashier-type helper: never anon.
select ok(
  not has_function_privilege('anon', 'public.is_cashier_type(text)', 'EXECUTE'),
  '445: is_cashier_type(text) not executable by anon');
-- 444 service-only attestation: neither client role.
select ok(
  not has_function_privilege('anon', 'public._staff_sync_attested(uuid,uuid,text)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public._staff_sync_attested(uuid,uuid,text)', 'EXECUTE'),
  '444: _staff_sync_attested service-only');
-- 444 caller-JWT executors: anon must never reach them.
select ok(
  not has_function_privilege('anon', 'public.staff_admin_provision_begin(uuid,text,text,text,uuid,text)', 'EXECUTE'),
  '444: staff_admin_provision_begin not executable by anon');
select ok(
  not has_function_privilege('anon', 'public.staff_admin_provision_complete(uuid,uuid)', 'EXECUTE'),
  '444: staff_admin_provision_complete not executable by anon');
select ok(
  not has_function_privilege('anon', 'public.staff_admin_provision_abort(uuid,text)', 'EXECUTE'),
  '444: staff_admin_provision_abort not executable by anon');
select ok(
  not has_function_privilege('anon', 'public.staff_admin_sync_complete(uuid,uuid)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.staff_admin_sync_failed(uuid,uuid)', 'EXECUTE'),
  '444: staff_admin_sync_complete/sync_failed not executable by anon');
select ok(
  not has_function_privilege('anon', 'public.staff_admin_mark_password_rotated(uuid,uuid)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.staff_admin_record_password_reset(uuid)', 'EXECUTE'),
  '444: staff_admin password-proof RPCs not executable by anon');
-- 448 POS sale path: never anon.
select ok(
  not has_function_privilege('anon', 'public.staff_create_walk_in_sale(jsonb,jsonb,uuid,numeric,uuid,uuid,text)', 'EXECUTE'),
  '448: staff_create_walk_in_sale not executable by anon');
-- account deletion engine: service-only.
select ok(
  not has_function_privilege('anon', 'public.delete_user_data(uuid,text)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.delete_user_data(uuid,text)', 'EXECUTE'),
  'delete_user_data(uuid,text) service-only');

-- ------------------------------------------------------------------
-- 4. 449 public view surface drift (2 tests). merchants_public may keep
--    phone/address/coords (public by design); it must never gain email,
--    owner_user_id or staff_settings. products_public must never gain
--    stock_quantity (inventory counts stay merchant-private).
-- ------------------------------------------------------------------
select is(
  (select count(*)::int from information_schema.columns
    where table_schema = 'public' and table_name = 'merchants_public'
      and column_name in ('email','owner_user_id','staff_settings')),
  0,
  'merchants_public: no email/owner_user_id/staff_settings columns');
select is(
  (select count(*)::int from information_schema.columns
    where table_schema = 'public' and table_name = 'products_public'
      and column_name in ('stock_quantity')),
  0,
  'products_public: no stock_quantity column');

-- ------------------------------------------------------------------
-- 5. Behavioral negatives as a signed-in non-owner (5 tests... see plan):
-- ------------------------------------------------------------------
select tests.authenticate_as('gate_customer');

-- the admin count RPC refuses non-admins
select throws_like(
  $$ select public.admin_get_merchants_count() $$,
  '%not authorized%',
  'customer: admin_get_merchants_count() raises not authorized');

-- a non-owner never gets a merchant profile
select is(
  (select public.get_my_merchant_profile()),
  null,
  'customer: get_my_merchant_profile() returns NULL');

-- merchant_staff direct reads are revoked from client roles (42501)
select throws_like(
  $$ select * from public.merchant_staff limit 1 $$,
  '%permission denied%',
  'customer: merchant_staff direct SELECT denied');
-- the 444 column-grant set drifts only through review: exactly these 15
-- columns are client-readable, never the whole table
select is(
  (select string_agg(a.attname, ',' order by a.attname)
     from pg_attribute a
    where a.attrelid = 'public.merchant_staff'::regclass and a.attacl is not null
      and exists (select 1 from aclexplode(a.attacl) x
                   where x.grantee = 'authenticated'::regrole
                     and x.privilege_type = 'SELECT')),
  'branch_id,created_at,created_by,disabled_at,disabled_by,full_name,id,is_active,merchant_id,must_change_password,phone,role,updated_at,user_id,username',
  'merchant_staff: authenticated column SELECT stays exactly the 444 set');

select tests.clear_authentication();
set request.jwt.claims to '{"role":"anon"}';

-- anon: staff tables deny even before RLS
select throws_like(
  $$ select * from public.staff_provisioning limit 1 $$,
  '%permission denied%',
  'anon: staff_provisioning direct SELECT denied');

select throws_like(
  $$ select public.get_my_products_count(gen_random_uuid()) $$,
  '%permission denied%',
  'anon: get_my_products_count(uuid) EXECUTE denied');

-- finish(true) raises on any failure or plan mismatch: without it a
-- "not ok" line still lets psql exit 0 and the CI gate would be hollow
-- (#287).
select * from finish(true);
rollback;
