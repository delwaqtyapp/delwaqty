-- Suite for migration 444 (staff-admin executors + is_cashier_type, dark).
-- Applied by the harness AFTER 439-444 on a throwaway clone of
-- h435_template. Synthetic fixtures only: @example.invalid emails,
-- zz444-* usernames. DISPOSABLE-DATABASE-ONLY. Every expected-refusal
-- block uses the sentinel idiom AND asserts the intended error text.

BEGIN;

create temporary table zz444(
  owner uuid, outsider uuid, staffuser uuid, staffuser2 uuid, pwuser uuid,
  merchant uuid, svc_merchant uuid, branch1 uuid, other_branch uuid
);
insert into zz444 select
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
  gen_random_uuid();
grant select on table zz444 to authenticated;

insert into auth.users(id, email)
select u, e from (values
  ((select owner from zz444), 'zz444.owner@example.invalid'),
  ((select outsider from zz444), 'zz444.outsider@example.invalid'),
  ((select staffuser from zz444), 'staff_zz444a@delwaqty.app'),
  ((select staffuser2 from zz444), 'staff_zz444b@delwaqty.app'),
  ((select pwuser from zz444), 'staff_zz444c@delwaqty.app')
) as x(u, e);

insert into public.users(id, email, role, user_type, verification_status, username, account_status)
select u, e, 'customer', 'customer', 'approved', NULL, 'active'
from (values
  ((select owner from zz444), 'zz444.owner@example.invalid'),
  ((select outsider from zz444), 'zz444.outsider@example.invalid'),
  ((select staffuser from zz444), 'staff_zz444a@delwaqty.app'),
  ((select staffuser2 from zz444), 'staff_zz444b@delwaqty.app'),
  ((select pwuser from zz444), 'staff_zz444c@delwaqty.app')
) as x(u, e)
on conflict (id) do update set email = excluded.email, user_type = 'customer', username = NULL;

-- restaurant = cashier-type; service = simple-service (both in the live CHECK).
insert into public.merchants(id, name, owner_user_id, type, status) values
  ((select merchant from zz444), 'zz444-shop', (select owner from zz444), 'restaurant', 'active'),
  ((select svc_merchant from zz444), 'zz444-svc', (select owner from zz444), 'service', 'active');

-- Legacy-style uppercase username (pre-439 data can hold one): the
-- collision check must be case-insensitive even though new logins are
-- forced lowercase.
update public.users set username = 'ZZ444TAKEN__B2C3D4' where id = (select outsider from zz444);

insert into public.branches(id, merchant_id, name, is_primary) values
  ((select branch1 from zz444), (select merchant from zz444), 'zz444-b1', true),
  ((select other_branch from zz444), (select svc_merchant from zz444), 'zz444-ob', true);

-- ============ 0) is_cashier_type: exhaustive pinned partition (B2) ============
DO $$
DECLARE
  v_cashier text[] := ARRAY[
    'restaurant','cafe','juice_shop','bakery','sweets','grocery','supermarket',
    'fruits','vegetables','butcher','meat','seafood','dairy','spices','general',
    'electronics','mobile','fashion','clothing','shoes','accessories','perfumes',
    'flowers','petShop','furniture','home'];
  v_simple text[] := ARRAY[
    'food','service','home_services','plumbing','electrical','cleaning','handyman',
    'carpentry','ac_maintenance','painting','pest_control','appliance_repair',
    'doctor','clinic','fitness','carwash','gas','other'];
  v_def text;
  v_val text;
  v_vals text[];
BEGIN
  -- invoker + immutable (B1)
  ASSERT (SELECT NOT p.prosecdef AND p.provolatile = 'i'
            FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
           WHERE n.nspname = 'public' AND p.proname = 'is_cashier_type'),
    'is_cashier_type must be IMMUTABLE SECURITY INVOKER';
  -- every merchants_type_check value resolves to exactly one bucket
  SELECT pg_get_constraintdef(oid) INTO v_def FROM pg_constraint
   WHERE conname = 'merchants_type_check' AND conrelid = 'public.merchants'::regclass;
  SELECT array_agg(m[1]) INTO v_vals
    FROM regexp_matches(v_def, '''([a-zA-Z_]+)''::text', 'g') AS m;
  ASSERT v_vals IS NOT NULL AND cardinality(v_vals) >= 40, 'could not parse merchants_type_check';
  FOREACH v_val IN ARRAY v_vals LOOP
    ASSERT public.is_cashier_type(v_val) = (v_val = ANY (v_cashier)),
      'is_cashier_type mismatch for type: ' || v_val;
  END LOOP;
  -- fail closed on NULL/unknown
  ASSERT public.is_cashier_type(NULL) IS FALSE, 'NULL must fail closed';
  ASSERT public.is_cashier_type('nonsense') IS FALSE, 'unknown type must fail closed';
  ASSERT public.is_cashier_type('FOOD') IS FALSE, 'matching is case-sensitive by design';
END $$;

-- ============ 1) create_staff: happy path on a cashier-type ============
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
DO $$
DECLARE
  v_staff uuid;
BEGIN
  v_staff := public.staff_admin_create_staff(
    (SELECT merchant FROM zz444), (SELECT staffuser FROM zz444),
    'zz444cashier', 'Cashier One', 'cashier', (SELECT branch1 FROM zz444),
    '+201055501001', 'zz444cashier__a1b2c3');
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff s
    WHERE s.id = v_staff AND s.role = 'cashier' AND s.is_active
      AND s.must_change_password AND s.created_by = (SELECT owner FROM zz444)),
    'staff row missing or wrong';
  ASSERT EXISTS (SELECT 1 FROM public.users u
    WHERE u.id = (SELECT staffuser FROM zz444) AND u.username = 'zz444cashier__a1b2c3'
      AND u.user_type = 'merchant_staff' AND u.phone IS NULL),
    'users row not claimed correctly (phone must stay NULL)';
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff_events e
    WHERE e.staff_id = v_staff AND e.kind = 'created' AND e.actor_id = (SELECT owner FROM zz444)),
    'created audit row missing';
END $$;

-- ============ 2) refusals (each audited, each error text asserted) ============
CREATE FUNCTION pg_temp.zz444_refuse(p_sql text, p_err text) RETURNS void
 LANGUAGE plpgsql AS $r$
BEGIN
  EXECUTE p_sql;
  RAISE EXCEPTION 'zz444 sentinel: % should have refused', p_err;
EXCEPTION WHEN raise_exception THEN
  IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
  ASSERT SQLERRM = 'staff creation refused: ' || p_err, 'wrong error: ' || SQLERRM;
END;
$r$;

DO $$
BEGIN

  -- outsider (not the owner)
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT outsider FROM zz444))::text, true);
  PERFORM pg_temp.zz444_refuse(format('SELECT public.staff_admin_create_staff(%L::uuid, %L::uuid, %L, %L, %L, NULL, NULL, %L)',
    (SELECT merchant FROM zz444), (SELECT staffuser2 FROM zz444), 'zz444x', 'X', 'cashier', 'zz444x__a1b2c3'),
    'not the merchant owner');

  -- owner, simple-service merchant
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  PERFORM pg_temp.zz444_refuse(format('SELECT public.staff_admin_create_staff(%L::uuid, %L::uuid, %L, %L, %L, %L::uuid, NULL, %L)',
    (SELECT svc_merchant FROM zz444), (SELECT staffuser2 FROM zz444), 'zz444x', 'X', 'cashier', (SELECT other_branch FROM zz444), 'zz444x__a1b2c3'),
    'merchant type is not cashier-eligible');

  -- invalid role (owner/above-caller can never be requested)
  PERFORM pg_temp.zz444_refuse(format('SELECT public.staff_admin_create_staff(%L::uuid, %L::uuid, %L, %L, %L, %L::uuid, NULL, %L)',
    (SELECT merchant FROM zz444), (SELECT staffuser2 FROM zz444), 'zz444x', 'X', 'owner', (SELECT branch1 FROM zz444), 'zz444x__a1b2c3'),
    'invalid staff role');

  -- cashier without a branch
  PERFORM pg_temp.zz444_refuse(format('SELECT public.staff_admin_create_staff(%L::uuid, %L::uuid, %L, %L, %L, NULL, NULL, %L)',
    (SELECT merchant FROM zz444), (SELECT staffuser2 FROM zz444), 'zz444x', 'X', 'cashier', 'zz444x__a1b2c3'),
    'cashier/kitchen need a branch');

  -- branch of another merchant
  PERFORM pg_temp.zz444_refuse(format('SELECT public.staff_admin_create_staff(%L::uuid, %L::uuid, %L, %L, %L, %L::uuid, NULL, %L)',
    (SELECT merchant FROM zz444), (SELECT staffuser2 FROM zz444), 'zz444x', 'X', 'cashier', (SELECT other_branch FROM zz444), 'zz444x__a1b2c3'),
    'branch does not belong to the merchant');

  -- bad phone
  PERFORM pg_temp.zz444_refuse(format('SELECT public.staff_admin_create_staff(%L::uuid, %L::uuid, %L, %L, %L, %L::uuid, %L, %L)',
    (SELECT merchant FROM zz444), (SELECT staffuser2 FROM zz444), 'zz444x', 'X', 'cashier', (SELECT branch1 FROM zz444), 'not-a-phone', 'zz444x__a1b2c3'),
    'invalid phone');

  -- pre-existing non-staff account (the owner row itself)
  PERFORM pg_temp.zz444_refuse(format('SELECT public.staff_admin_create_staff(%L::uuid, %L::uuid, %L, %L, %L, %L::uuid, NULL, %L)',
    (SELECT merchant FROM zz444), (SELECT owner FROM zz444), 'zz444x', 'X', 'branch_manager', (SELECT branch1 FROM zz444), 'zz444y__a1b2c3'),
    'target is not a fresh staff auth user');

  -- duplicate login username vs a legacy uppercase row (case-insensitive)
  PERFORM pg_temp.zz444_refuse(format('SELECT public.staff_admin_create_staff(%L::uuid, %L::uuid, %L, %L, %L, %L::uuid, NULL, %L)',
    (SELECT merchant FROM zz444), (SELECT staffuser2 FROM zz444), 'zz444x', 'X', 'branch_manager', (SELECT branch1 FROM zz444), 'zz444taken__b2c3d4'),
    'login username taken');

  -- uppercase login input is rejected by the format rule outright
  PERFORM pg_temp.zz444_refuse(format('SELECT public.staff_admin_create_staff(%L::uuid, %L::uuid, %L, %L, %L, %L::uuid, NULL, %L)',
    (SELECT merchant FROM zz444), (SELECT staffuser2 FROM zz444), 'zz444x', 'X', 'branch_manager', (SELECT branch1 FROM zz444), 'ZZ444CASHIER__A1B2C3'),
    'invalid login username');

  -- A10: refusals themselves cannot audit (their error rolls back), so the
  -- edge function logs them through staff_admin_audit_refusal afterwards.
  PERFORM public.staff_admin_audit_refusal((SELECT merchant FROM zz444), 'create_staff');
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff_events e
    WHERE e.merchant_id = (SELECT merchant FROM zz444) AND e.staff_id IS NULL
      AND e.kind = 'created' AND e.detail->>'refused' = 'create_staff'
      AND e.actor_id = (SELECT owner FROM zz444)),
    'refusal audit row missing or wrong actor';
END $$;

-- ============ 3) set_active + password_reset audit ============
DO $$
DECLARE
  v_staff uuid;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  SELECT id INTO v_staff FROM public.merchant_staff WHERE user_id = (SELECT staffuser FROM zz444);

  -- outsider cannot flip state, and the error is generic
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT outsider FROM zz444))::text, true);
  BEGIN
    PERFORM public.staff_admin_set_active(v_staff, false);
    RAISE EXCEPTION 'zz444 sentinel: outsider set_active';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'staff not found', 'wrong error: ' || SQLERRM;
  END;

  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  PERFORM public.staff_admin_set_active(v_staff, false);
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff s
    WHERE s.id = v_staff AND NOT s.is_active AND s.disabled_at IS NOT NULL
      AND s.disabled_by = (SELECT owner FROM zz444)), 'disable did not stick';
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff_events e
    WHERE e.staff_id = v_staff AND e.kind = 'disabled'), 'disabled audit missing';
  PERFORM public.staff_admin_set_active(v_staff, true);
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff s
    WHERE s.id = v_staff AND s.is_active AND s.disabled_at IS NULL), 'enable did not stick';

  -- password reset: must_change_password set, audit written, no secrets stored
  UPDATE public.merchant_staff SET must_change_password = false WHERE id = v_staff;
  PERFORM public.staff_admin_record_password_reset(v_staff);
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff s
    WHERE s.id = v_staff AND s.must_change_password), 'must_change_password not re-armed';
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff_events e
    WHERE e.staff_id = v_staff AND e.kind = 'password_reset'
      AND e.detail = '{}'::jsonb), 'password_reset audit must carry no detail';
END $$;

-- ============ 4) grants: nothing new for anon/PUBLIC ============
DO $$
BEGIN
  ASSERT NOT has_function_privilege('anon', 'public.staff_admin_create_staff(uuid,uuid,text,text,text,uuid,text,text)', 'EXECUTE'), 'anon can create staff';
  ASSERT NOT has_function_privilege('anon', 'public.staff_admin_set_active(uuid,boolean)', 'EXECUTE'), 'anon can set_active';
  ASSERT NOT has_function_privilege('anon', 'public.staff_admin_record_password_reset(uuid)', 'EXECUTE'), 'anon can record resets';
  ASSERT NOT has_function_privilege('anon', 'public.is_cashier_type(text)', 'EXECUTE'), 'anon can call is_cashier_type';
  -- PUBLIC via aclexplode grantee=0 (has_function_privilege('PUBLIC',...)
  -- raises 42704 on PG17); default acldefault applies when proacl is NULL.
  ASSERT NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace,
         LATERAL aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
     WHERE n.nspname = 'public'
       AND p.proname IN ('is_cashier_type', 'staff_admin_create_staff',
                         'staff_admin_set_active', 'staff_admin_record_password_reset')
       AND a.grantee = 0 AND a.privilege_type = 'EXECUTE'),
    'PUBLIC has EXECUTE on a 444 function';
END $$;

SELECT set_config('request.jwt.claims', '{}', true);
ROLLBACK;
