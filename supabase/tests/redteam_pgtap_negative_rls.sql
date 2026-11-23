-- Delwaqty: negative-case RLS + privilege tests (red team, Nov 23 2026)
-- Run with: supabase test db
-- Requires: usebasejump/supabase-test-helpers (tests.create_supabase_user,
-- tests.authenticate_as, tests.clear_authentication, tests.rls_enabled).
--
-- Every case here was verified by hand against staging (adcgqoccrgauqdoplsgg)
-- and prod (bttnlkmwhorjamzemwda) on 2026-11-23. If one of these fails, a
-- migration has opened a hole. Never "fix" a failure by deleting the test.

begin;

select plan(30);

-- ------------------------------------------------------------------
-- 0. Fixtures: two customers
-- ------------------------------------------------------------------
select tests.create_supabase_user('rls_customer_a', 'rls-a@example.invalid');
select tests.create_supabase_user('rls_customer_b', 'rls-b@example.invalid');

-- ------------------------------------------------------------------
-- 1. RLS is enabled on every real table in public (event trigger
--    rls_auto_enable is a safety net, this test is the gate).
--    Exclusions: spatial_ref_sys (PostGIS reference data),
--    _cashier_keys (internal, no grants to anon/authenticated).
-- ------------------------------------------------------------------
select is(
  (select count(*)::int from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r'
     and not c.relrowsecurity
     and c.relname not in ('spatial_ref_sys', '_cashier_keys')),
  0,
  'RLS enabled on every public table (excluding spatial_ref_sys, _cashier_keys)'
);

-- _cashier_keys must never become readable by clients.
select ok(
  not has_table_privilege('authenticated', 'public._cashier_keys', 'SELECT')
  and not has_table_privilege('anon', 'public._cashier_keys', 'SELECT'),
  '_cashier_keys has no client SELECT grant'
);

-- ------------------------------------------------------------------
-- 2. Anon can read nothing personal.
-- ------------------------------------------------------------------
select tests.clear_authentication();
set request.jwt.claims to '{"role":"anon"}';  -- belt and braces

select is_empty(
  $$ select * from public.users limit 1 $$,
  'anon: users unreadable');
select is_empty(
  $$ select * from public.orders limit 1 $$,
  'anon: orders unreadable');
select is_empty(
  $$ select * from public.wallets limit 1 $$,
  'anon: wallets unreadable');
select is_empty(
  $$ select * from public.whatsapp_otp_verifications limit 1 $$,
  'anon: whatsapp_otp_verifications unreadable');
select is_empty(
  $$ select * from public.chat_messages limit 1 $$,
  'anon: chat_messages unreadable');
select is_empty(
  $$ select * from public.admin_management limit 1 $$,
  'anon: admin_management unreadable');

-- ------------------------------------------------------------------
-- 3. Customer A sees self only; customer B cannot reach across.
-- ------------------------------------------------------------------
select tests.authenticate_as('rls_customer_a');

select is(
  (select count(*)::int from public.users),
  1,
  'customer: users SELECT returns self only');

select is_empty(
  $$ select * from public.wallets where user_id <> tests.get_supabase_uid('rls_customer_a') $$,
  'customer: no foreign wallets');

select is_empty(
  $$ select * from public.orders where user_id <> tests.get_supabase_uid('rls_customer_a') $$,
  'customer: no foreign orders');

select is_empty(
  $$ select * from public.notifications where user_id <> tests.get_supabase_uid('rls_customer_a') $$,
  'customer: no foreign notifications');

select is_empty(
  $$ select * from public.chat_messages $$,
  'customer: no chat messages without room membership');

-- Wallet forgery: direct inserts stay impossible.
select throws_like(
  $$ insert into public.wallets (user_id, balance)
     values (tests.get_supabase_uid('rls_customer_a'), 100) $$,
  '%WALLET_LEDGER_GUARD: wallets rows must start at balance 0%',
  'customer: cannot self-create wallet with balance');

select throws_like(
  $$ insert into public.wallet_transactions (wallet_id, type, amount)
     values (gen_random_uuid(), 'credit', 50) $$,
  '%permission denied for table wallet_transactions%',
  'customer: cannot insert wallet_transactions directly');

-- Account-field guards: role and phone are not client-writable.
select throws_like(
  format($$ update public.users set role = 'admin'
            where id = %L $$, tests.get_supabase_uid('rls_customer_a')),
  '%Role is managed by the admin lifecycle RPCs%',
  'customer: self role escalation blocked by users_guard_account_fields');

select throws_like(
  format($$ update public.users set phone = '+201999999999'
            where id = %L $$, tests.get_supabase_uid('rls_customer_a')),
  '%Phone number is managed by the WhatsApp-verified claim_phone_change RPC%',
  'customer: self phone change blocked by users_guard_account_fields');

select tests.authenticate_as('rls_customer_b');
select is_empty(
  format($$ select * from public.orders
            where user_id = %L $$, tests.get_supabase_uid('rls_customer_a')),
  'customer B: cannot read A orders (IDOR)');

-- ------------------------------------------------------------------
-- 4. Dangerous RPCs are not executable by client roles at all.
--    (Verified 2026-11-23: all revoked. wallet_pay/wallet_topup legacy
--    overloads must stay revoked regardless of their internal checks.)
-- ------------------------------------------------------------------
select tests.clear_authentication();

select ok(
  not has_function_privilege('authenticated',
    'public.wallet_topup(numeric, text, text, text)', 'EXECUTE'),
  'wallet_topup(4-arg) not executable by authenticated');

select ok(
  not has_function_privilege('authenticated',
    'public.wallet_topup(uuid, numeric, text, text, uuid)', 'EXECUTE'),
  'wallet_topup(5-arg) not executable by authenticated');

select ok(
  not has_function_privilege('authenticated',
    'public._wallet_credit(uuid, numeric, text, text, uuid)', 'EXECUTE'),
  '_wallet_credit not executable by authenticated');

select ok(
  not has_function_privilege('authenticated',
    'public.wallet_refund(uuid, numeric, text, text, uuid)', 'EXECUTE'),
  'wallet_refund not executable by authenticated');

select ok(
  not has_function_privilege('authenticated',
    'public._platform_credit_grant(uuid, numeric, uuid)', 'EXECUTE'),
  '_platform_credit_grant not executable by authenticated');

select ok(
  not has_function_privilege('authenticated',
    'public._admin_exec_role(uuid, uuid, text, text)', 'EXECUTE'),
  '_admin_exec_role not executable by authenticated');

select ok(
  not has_function_privilege('authenticated',
    'public._admin_exec_create(uuid, uuid, uuid, uuid, text)', 'EXECUTE'),
  '_admin_exec_create not executable by authenticated');

select ok(
  not has_function_privilege('authenticated',
    'public._price_order_line(uuid, jsonb, boolean)', 'EXECUTE'),
  '_price_order_line not executable by authenticated (stock-sabotage path)');

select ok(
  not has_function_privilege('authenticated',
    'public.apply_coupon(text, numeric)', 'EXECUTE'),
  'apply_coupon not executable by authenticated (coupon-burn path)');

-- Owner-only gates hold for the granted money RPCs.
select tests.authenticate_as('rls_customer_a');
select is(
  (select (public.admin_direct_topup('customer',
     tests.get_supabase_uid('rls_customer_a'), 1000, null) ->> 'code')),
  'FORBIDDEN_OWNER_ONLY',
  'admin_direct_topup rejects non-owner');

select is(
  (select (public.approve_topup_request(gen_random_uuid()) ->> 'code')),
  'FORBIDDEN_OWNER_ONLY',
  'approve_topup_request rejects non-owner');

select * from finish();
rollback;
