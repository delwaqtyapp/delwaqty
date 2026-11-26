-- Suite for migration 444 round 2 (staff provisioning state machine,
-- code #259-#265 + security S1-S7). Applied by the harness AFTER
-- 439-444 on a throwaway clone of h435_template. Synthetic fixtures
-- only. Caller-context sections run as the REAL authenticated role
-- (SET LOCAL ROLE + claims GUC), never as the DB owner (#265).
-- DISPOSABLE-DATABASE-ONLY.

BEGIN;

create temporary table zz444(
  owner uuid, outsider uuid, staffuser uuid, staffuser2 uuid, staleuser uuid,
  merchant uuid, svc_merchant uuid, branch1 uuid, other_branch uuid, provision uuid,
  staff uuid, gen uuid
);
insert into zz444 select
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
  gen_random_uuid(), gen_random_uuid();
grant select on table zz444 to authenticated;

insert into auth.users(id, email)
select u, e from (values
  ((select owner from zz444), 'zz444.owner@example.invalid'),
  ((select outsider from zz444), 'zz444.outsider@example.invalid')
) as x(u, e);

insert into public.users(id, email, role, user_type, verification_status, account_status)
select u, e, 'customer', 'customer', 'approved', 'active'
from (values
  ((select owner from zz444), 'zz444.owner@example.invalid'),
  ((select outsider from zz444), 'zz444.outsider@example.invalid')
) as x(u, e)
on conflict (id) do update set email = excluded.email;

insert into public.merchants(id, name, owner_user_id, type, status) values
  ((select merchant from zz444), 'zz444-shop', (select owner from zz444), 'restaurant', 'active'),
  ((select svc_merchant from zz444), 'zz444-svc', (select owner from zz444), 'service', 'active');

insert into public.branches(id, merchant_id, name, is_primary) values
  ((select branch1 from zz444), (select merchant from zz444), 'zz444-b1', true),
  ((select other_branch from zz444), (select svc_merchant from zz444), 'zz444-ob', true);

-- ============ 0) is_cashier_type: exactly-one, disjoint, exhaustive (#264) ====
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
    'doctor','clinic','fitness','carwash','gas','other','pharmacy'];
  v_def text;
  v_vals text[];
  v_val text;
BEGIN
  -- 445 flips food to cashier-eligible (owner decision) and its CHECK
  -- drops pharmacy/has juice_shop; under the 445 chain (detected via
  -- is_simple_service_type) the expected partition follows 445.
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
             WHERE n.nspname = 'public' AND p.proname = 'is_simple_service_type') THEN
    v_cashier := v_cashier || ARRAY['food'];
    v_simple := ARRAY[
      'service','home_services','plumbing','electrical','cleaning','handyman',
      'carpentry','ac_maintenance','painting','pest_control','appliance_repair',
      'doctor','clinic','fitness','carwash','gas','other'];
  END IF;
  ASSERT (SELECT NOT p.prosecdef AND p.provolatile = 'i'
            FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
           WHERE n.nspname = 'public' AND p.proname = 'is_cashier_type'),
    'is_cashier_type must be IMMUTABLE SECURITY INVOKER';
  ASSERT NOT (v_cashier && v_simple), 'cashier/simple lists overlap';
  SELECT pg_get_constraintdef(oid) INTO v_def FROM pg_constraint
   WHERE conname = 'merchants_type_check' AND conrelid = 'public.merchants'::regclass;
  SELECT array_agg(m[1]) INTO v_vals
    FROM regexp_matches(v_def, '''([a-zA-Z_]+)''::text', 'g') AS m;
  ASSERT v_vals IS NOT NULL AND cardinality(v_vals) >= 40, 'could not parse merchants_type_check';
  FOREACH v_val IN ARRAY v_vals LOOP
    ASSERT (v_val = ANY (v_cashier)) <> (v_val = ANY (v_simple)),
      'type in neither or both partitions: ' || v_val;
    ASSERT public.is_cashier_type(v_val) = (v_val = ANY (v_cashier)),
      'is_cashier_type mismatch for type: ' || v_val;
  END LOOP;
  FOREACH v_val IN ARRAY (v_cashier || v_simple) LOOP
    ASSERT v_val = 'juice_shop' OR v_val = ANY (v_vals),
      'partition entry not in merchants_type_check: ' || v_val;
  END LOOP;
  ASSERT public.is_cashier_type('juice_shop') IS TRUE,
    'juice_shop is cashier-eligible (not in merchants_type_check)';
  ASSERT public.is_cashier_type(NULL) IS FALSE, 'NULL must fail closed';
  ASSERT public.is_cashier_type('nonsense') IS FALSE, 'unknown type must fail closed';
  ASSERT public.is_cashier_type('RESTAURANT') IS FALSE, 'case-sensitive by design';
END $$;

-- ============ 1) master flag off: begin refused as REAL authenticated =======
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
DO $$
BEGIN
  BEGIN PERFORM public.staff_admin_provision_begin(
      (SELECT merchant FROM zz444), 'zz444cashier', 'Cashier One', 'cashier',
      (SELECT branch1 FROM zz444), NULL);
    RAISE EXCEPTION 'zz444 sentinel: begin with flag off';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'feature disabled', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;

-- flag on for the rest (442's suite toggles flags the same way, as DB owner);
-- clear the JWT claims GUC first: it survives RESET ROLE within the transaction
-- and the platform_settings guard reads it.
SELECT set_config('request.jwt.claims', '{}', true);
update public.platform_settings
   set feature_flags = feature_flags || '{"staff_accounts":true}'::jsonb
 where id = 'default';

-- ============ 2) provision_begin: refusal matrix (generic errors) ===========
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT outsider FROM zz444))::text, true);
  BEGIN PERFORM public.staff_admin_provision_begin(
      (SELECT merchant FROM zz444), 'zz444x', 'X', 'cashier', (SELECT branch1 FROM zz444), NULL);
    RAISE EXCEPTION 'zz444 sentinel: outsider begin';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'staff creation refused', 'wrong error: ' || SQLERRM; END;

  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  BEGIN PERFORM public.staff_admin_provision_begin(
      (SELECT svc_merchant FROM zz444), 'zz444x', 'X', 'branch_manager', NULL, NULL);
    RAISE EXCEPTION 'zz444 sentinel: service-type begin';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'staff creation refused', 'wrong error: ' || SQLERRM; END;

  BEGIN PERFORM public.staff_admin_provision_begin(
      (SELECT merchant FROM zz444), 'zz444x', 'X', 'owner', NULL, NULL);
    RAISE EXCEPTION 'zz444 sentinel: owner-role begin';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'staff creation refused', 'wrong error: ' || SQLERRM; END;

  BEGIN PERFORM public.staff_admin_provision_begin(
      (SELECT merchant FROM zz444), 'admin', 'X', 'branch_manager', NULL, NULL);
    RAISE EXCEPTION 'zz444 sentinel: reserved username';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'staff creation refused', 'wrong error: ' || SQLERRM; END;

  BEGIN PERFORM public.staff_admin_provision_begin(
      (SELECT merchant FROM zz444), 'zz444x', 'X', 'cashier', (SELECT other_branch FROM zz444), NULL);
    RAISE EXCEPTION 'zz444 sentinel: cross-merchant branch';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'staff creation refused', 'wrong error: ' || SQLERRM; END;

  BEGIN PERFORM public.staff_admin_provision_begin(
      (SELECT merchant FROM zz444), 'zz444x', 'X', 'cashier', (SELECT branch1 FROM zz444), 'not-a-phone');
    RAISE EXCEPTION 'zz444 sentinel: bad phone';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'staff creation refused', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;

-- ============ 3) happy path: begin -> edge-simulated auth user -> complete ===
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
DO $$
DECLARE
  v_res jsonb;
BEGIN
  v_res := public.staff_admin_provision_begin(
    (SELECT merchant FROM zz444), 'ZZ444Cashier', 'Cashier One', 'cashier',
    (SELECT branch1 FROM zz444), '+201055501001');
  -- canonical derived form: lowercase + __<6 hex of merchant id> (S5)
  ASSERT v_res->>'login_username' =
    'zz444cashier__' || substr(replace((SELECT merchant FROM zz444)::text, '-', ''), 1, 6),
    'derived login username wrong: ' || (v_res->>'login_username');
END $$;
RESET ROLE;

-- the auth user the edge would create (service key writes app_metadata, S3)
update zz444 set provision = (select id from public.staff_provisioning
  where merchant_id = (select merchant from zz444) and state = 'pending');
insert into auth.users(id, email, created_at, raw_app_meta_data)
select (select staffuser from zz444), 'staff_zz444a@delwaqty.app', now(),
       jsonb_build_object('staff_provisioning', (select provision from zz444));

-- complete as the owner (REAL authenticated role)
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
DO $$
DECLARE
  v_staff uuid;
BEGIN
  v_staff := public.staff_admin_provision_complete(
    (SELECT provision FROM zz444), (SELECT staffuser FROM zz444));
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff s
    WHERE s.id = v_staff AND s.role = 'cashier' AND s.is_active
      AND s.must_change_password AND s.created_by = (SELECT owner FROM zz444)),
    'staff row missing or wrong';
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff_events e
    WHERE e.staff_id = v_staff AND e.kind = 'created'), 'created audit missing';
END $$;
RESET ROLE;
DO $$
BEGIN
  ASSERT EXISTS (SELECT 1 FROM public.users u
    WHERE u.id = (SELECT staffuser FROM zz444)
      AND u.username = 'zz444cashier__' || substr(replace((SELECT merchant FROM zz444)::text, '-', ''), 1, 6)
      AND u.user_type = 'merchant_staff' AND u.phone IS NULL),
    'users row not claimed correctly (phone must stay NULL)';
  ASSERT (SELECT state FROM public.staff_provisioning WHERE id = (SELECT provision FROM zz444))
    = 'consumed', 'provisioning row not consumed';
END $$;
update zz444 set staff = (select id from public.merchant_staff where user_id = (select staffuser from zz444));

-- #266: creation IS the verified rotation (provision binding), so complete
-- captured the baseline digest itself - no caller-asserted mark involved
DO $$
BEGIN
  ASSERT (SELECT s.password_digest FROM public.merchant_staff s WHERE s.id = (SELECT staff FROM zz444))
         = (SELECT md5(u.encrypted_password) FROM auth.users u WHERE u.id = (SELECT staffuser FROM zz444)),
    'baseline digest not stored by complete';
END $$;

-- ============ 4) provision_complete negatives ===============================
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  -- second consume of the same provisioning row: refused (one-use)
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  BEGIN PERFORM public.staff_admin_provision_complete(
      (SELECT provision FROM zz444), (SELECT staffuser FROM zz444));
    RAISE EXCEPTION 'zz444 sentinel: double consume';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'staff creation refused', 'wrong error: ' || SQLERRM; END;

  -- an auth user WITHOUT the app_metadata binding can never be attached (S3)
  PERFORM set_config('request.jwt.claims', '{}'::text, true);
END $$;
RESET ROLE;
-- fresh provision + plain auth user (self-signup style, no app_metadata)
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
DO $$
DECLARE v_res jsonb;
BEGIN
  v_res := public.staff_admin_provision_begin(
    (SELECT merchant FROM zz444), 'zz444second', 'Second', 'branch_manager', NULL, NULL);
END $$;
RESET ROLE;
insert into auth.users(id, email, created_at)
values ((select staffuser2 from zz444), 'staff_zz444b@delwaqty.app', now());
update zz444 set provision = (select id from public.staff_provisioning
  where merchant_id = (select merchant from zz444) and state = 'pending'
  order by created_at desc limit 1);
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  BEGIN PERFORM public.staff_admin_provision_complete(
      (SELECT provision FROM zz444),
      (SELECT staffuser2 FROM zz444));
    RAISE EXCEPTION 'zz444 sentinel: unbound auth user attached';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'staff creation refused', 'wrong error: ' || SQLERRM; END;
END $$;
-- the refused complete rolled back, so the edge aborts via a separate call
-- (an abort written inside the raising call could never commit)
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  PERFORM public.staff_admin_provision_abort((SELECT provision FROM zz444), 'unbound_auth_user');
END $$;
RESET ROLE;
DO $$
BEGIN
  -- the edge's abort call ABORTED the provisioning row (fail closed)
  ASSERT (SELECT state FROM public.staff_provisioning WHERE id = (SELECT provision FROM zz444))
         = 'aborted', 'failed complete must be aborted by the edge follow-up';
  -- and no staff row / username was claimed for the unbound user
  ASSERT NOT EXISTS (SELECT 1 FROM public.merchant_staff s WHERE s.user_id = (SELECT staffuser2 FROM zz444)),
    'unbound user gained a staff row';
END $$;

-- expired provisioning row cannot complete
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
DO $$
DECLARE v_res jsonb;
BEGIN
  v_res := public.staff_admin_provision_begin(
    (SELECT merchant FROM zz444), 'zz444third', 'Third', 'branch_manager', NULL, NULL);
END $$;
RESET ROLE;
update public.staff_provisioning set expires_at = now() - interval '1 minute'
 where merchant_id = (select merchant from zz444) and state = 'pending';
update zz444 set provision = (select id from public.staff_provisioning
  where merchant_id = (select merchant from zz444) and state = 'pending'
  order by created_at desc limit 1);
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  BEGIN PERFORM public.staff_admin_provision_complete(
      (SELECT provision FROM zz444),
      (SELECT staffuser2 FROM zz444));
    RAISE EXCEPTION 'zz444 sentinel: expired provision completed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'staff creation refused', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;

-- #260: one auth user = at most one staff row, platform-wide
DO $$
BEGIN
  BEGIN
    INSERT INTO public.merchant_staff (merchant_id, user_id, username, full_name, role)
    VALUES ((SELECT svc_merchant FROM zz444), (SELECT staffuser FROM zz444), 'zz444dupe', 'Dupe', 'branch_manager');
    RAISE EXCEPTION 'zz444 sentinel: duplicate user_id accepted';
  EXCEPTION
    WHEN raise_exception THEN IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
      ASSERT false, 'expected unique violation, got: ' || SQLERRM;
    WHEN unique_violation THEN
      ASSERT SQLERRM LIKE '%merchant_staff_user_id_key%', 'wrong unique violation: ' || SQLERRM;
  END;
END $$;

-- ============ 4b) consume re-validates CURRENT ownership and type (#260) ====
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
DO $$
DECLARE v_res jsonb;
BEGIN
  v_res := public.staff_admin_provision_begin(
    (SELECT merchant FROM zz444), 'zz444flip', 'Flip', 'branch_manager', NULL, NULL);
END $$;
RESET ROLE;
update zz444 set provision = (select id from public.staff_provisioning
  where merchant_id = (select merchant from zz444) and state = 'pending'
  order by created_at desc limit 1);
insert into auth.users(id, email, created_at, raw_app_meta_data)
select (select staleuser from zz444), 'staff_zz444c@delwaqty.app', now(),
       jsonb_build_object('staff_provisioning', (select provision from zz444));
-- ownership flips AFTER begin: complete must refuse
update public.merchants set owner_user_id = (select outsider from zz444)
 where id = (select merchant from zz444);
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  BEGIN PERFORM public.staff_admin_provision_complete(
      (SELECT provision FROM zz444), (SELECT staleuser FROM zz444));
    RAISE EXCEPTION 'zz444 sentinel: complete after ownership flip';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'staff creation refused', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;
-- flip back, then the TYPE flips to a non-cashier type: still refused
update public.merchants set owner_user_id = (select owner from zz444), type = 'plumbing'
 where id = (select merchant from zz444);
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  BEGIN PERFORM public.staff_admin_provision_complete(
      (SELECT provision FROM zz444), (SELECT staleuser FROM zz444));
    RAISE EXCEPTION 'zz444 sentinel: complete after type flip';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'staff creation refused', 'wrong error: ' || SQLERRM; END;
  -- edge follow-up: abort the stale provision
  PERFORM public.staff_admin_provision_abort((SELECT provision FROM zz444), 'revalidation_failed');
END $$;
RESET ROLE;
update public.merchants set type = 'restaurant' where id = (select merchant from zz444);
DO $$
BEGIN
  ASSERT NOT EXISTS (SELECT 1 FROM public.merchant_staff sm WHERE sm.user_id = (SELECT staleuser FROM zz444)),
    'flipped complete created a staff row';
  ASSERT (SELECT state FROM public.staff_provisioning WHERE id = (SELECT provision FROM zz444))
    = 'aborted', 'stale provision not aborted';
END $$;

SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  -- outsider: generic refusal on every action
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT outsider FROM zz444))::text, true);
  BEGIN PERFORM public.staff_admin_set_active(v_staff, false);
    RAISE EXCEPTION 'zz444 sentinel: outsider set_active';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'staff not found', 'wrong error: ' || SQLERRM; END;
  BEGIN PERFORM public.staff_admin_record_password_reset(v_staff);
    RAISE EXCEPTION 'zz444 sentinel: outsider reset';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'staff not found', 'wrong error: ' || SQLERRM; END;
  BEGIN PERFORM public.staff_admin_sync_complete(v_staff, gen_random_uuid());
    RAISE EXCEPTION 'zz444 sentinel: outsider sync_complete';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'staff not found', 'wrong error: ' || SQLERRM; END;
  BEGIN PERFORM public.staff_admin_mark_password_rotated(v_staff, gen_random_uuid());
    RAISE EXCEPTION 'zz444 sentinel: outsider mark';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'staff not found', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;

-- #261/#262: a DIRECT-RPC enable can never activate; completion needs the
-- service attestation for the CURRENT generation
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
  v_gen uuid;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  -- disable: immediate (fail closed), returns its generation
  v_gen := public.staff_admin_set_active(v_staff, false);
  ASSERT v_gen IS NOT NULL, 'disable returned no generation';
  -- one op slot: a second op while pending is refused
  BEGIN PERFORM public.staff_admin_set_active(v_staff, true);
    RAISE EXCEPTION 'zz444 sentinel: op while pending';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'operation already pending', 'wrong error: ' || SQLERRM; END;
  -- forged completion WITHOUT any attestation: refused (#265)
  BEGIN PERFORM public.staff_admin_sync_complete(v_staff, v_gen);
    RAISE EXCEPTION 'zz444 sentinel: forged sync_complete';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'sync completion not verified', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;
update zz444 set gen = (select sync_generation from public.merchant_staff where id = (select staff from zz444));
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff sm
    WHERE sm.id = v_staff AND NOT sm.is_active AND sm.sync_state = 'pending'
      AND sm.sync_op = 'disable' AND sm.sync_generation IS NOT NULL),
    'disable must cut access immediately and stay pending';
  ASSERT (SELECT gen FROM zz444) IS NOT NULL, 'generation not captured';
END $$;
-- the edge finishes the disable: attestation (service key) then completion
update auth.users
   set raw_app_meta_data = coalesce(raw_app_meta_data,'{}'::jsonb)
     || jsonb_build_object('staff_sync', jsonb_build_object(
         'generation', (SELECT sync_generation FROM public.merchant_staff WHERE id = (SELECT staff FROM zz444)),
         'op', 'disable', 'at', now()))
 where id = (select staffuser from zz444);
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  PERFORM public.staff_admin_sync_complete(v_staff,
    (SELECT gen FROM zz444));
  -- arm the enable; the row STAYS inactive until verified (#261)
  PERFORM public.staff_admin_set_active(v_staff, true);
END $$;
RESET ROLE;
update zz444 set gen = (select sync_generation from public.merchant_staff where id = (select staff from zz444));
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff sm
    WHERE sm.id = v_staff AND NOT sm.is_active AND sm.sync_state = 'pending' AND sm.sync_op = 'enable'),
    'direct-RPC enable must stay inactive + pending';
END $$;
-- #262: a STALE attestation (older generation) cannot finalize the new op
update auth.users
   set raw_app_meta_data = coalesce(raw_app_meta_data,'{}'::jsonb)
     || jsonb_build_object('staff_sync', jsonb_build_object(
         'generation', gen_random_uuid(), 'op', 'enable', 'at', now()))
 where id = (select staffuser from zz444);
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  BEGIN PERFORM public.staff_admin_sync_complete(v_staff,
      (SELECT gen FROM zz444));
    RAISE EXCEPTION 'zz444 sentinel: stale attestation accepted';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'sync completion not verified', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;
-- GoTrue side fails on the retry: the op lands in the blocked state (#262)
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  PERFORM public.staff_admin_sync_failed(v_staff,
    (SELECT gen FROM zz444));
END $$;
RESET ROLE;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff sm
    WHERE sm.id = v_staff AND NOT sm.is_active AND sm.sync_state = 'failed' AND sm.sync_op = 'enable'),
    'failed sync must leave the row inactive in the blocked state';
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff_events e
    WHERE e.staff_id = v_staff AND e.kind = 'refused' AND e.detail->>'action' = 'sync'),
    'failed sync not audited';
END $$;
-- retry: re-arm first (new generation), THEN attest the CURRENT
-- generation, then complete -> active
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  PERFORM public.staff_admin_set_active(v_staff, true);   -- re-arm after failure
END $$;
RESET ROLE;
update zz444 set gen = (select sync_generation from public.merchant_staff where id = (select staff from zz444));
update auth.users
   set raw_app_meta_data = coalesce(raw_app_meta_data,'{}'::jsonb)
     || jsonb_build_object('staff_sync', jsonb_build_object(
         'generation', (SELECT sync_generation FROM public.merchant_staff WHERE id = (SELECT staff FROM zz444)),
         'op', 'enable', 'at', now()))
 where id = (select staffuser from zz444);
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  PERFORM public.staff_admin_sync_complete(v_staff,
    (SELECT gen FROM zz444));
END $$;
RESET ROLE;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff sm
    WHERE sm.id = v_staff AND sm.is_active AND sm.disabled_at IS NULL
      AND sm.sync_state = 'ok' AND sm.sync_op IS NULL AND sm.sync_generation IS NULL),
    'verified enable did not activate';
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff_events e
    WHERE e.staff_id = v_staff AND e.kind = 'enabled'), 'enabled audit missing';
END $$;

-- #266: reset invalidates the old proof INSTANTLY; only an attestation-
-- verified post-rotation mark re-establishes it
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  PERFORM public.staff_admin_record_password_reset(v_staff);
END $$;
RESET ROLE;
update zz444 set gen = (select sync_generation from public.merchant_staff where id = (select staff from zz444));
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff sm
    WHERE sm.id = v_staff AND NOT sm.is_active AND sm.must_change_password
      AND sm.password_digest IS NULL AND sm.sync_state = 'pending' AND sm.sync_op = 'reset'),
    'reset must cut access and NULL the digest in the same statement';
END $$;
-- the old token cannot clear while the reset is pending (#266 old-token race)
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT staffuser FROM zz444))::text, true);
  BEGIN PERFORM public.staff_password_changed();
    RAISE EXCEPTION 'zz444 sentinel: old-token clear during pending reset';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'staff not found', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;
-- a mark WITHOUT the attestation is no evidence of rotation (#266)
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  BEGIN PERFORM public.staff_admin_mark_password_rotated(v_staff,
      (SELECT gen FROM zz444));
    RAISE EXCEPTION 'zz444 sentinel: unattested mark';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'sync completion not verified', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;
-- the edge rotates, revokes, attests; mark stores the NEW digest; complete
update auth.users set encrypted_password = 'zz444-rotated-hash'
 where id = (select staffuser from zz444);
update auth.users
   set raw_app_meta_data = coalesce(raw_app_meta_data,'{}'::jsonb)
     || jsonb_build_object('staff_sync', jsonb_build_object(
         'generation', (SELECT sync_generation FROM public.merchant_staff WHERE id = (SELECT staff FROM zz444)),
         'op', 'reset', 'at', now()))
 where id = (select staffuser from zz444);
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  PERFORM public.staff_admin_mark_password_rotated(v_staff,
    (SELECT gen FROM zz444));
  PERFORM public.staff_admin_sync_complete(v_staff,
    (SELECT gen FROM zz444));
END $$;
RESET ROLE;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff sm
    WHERE sm.id = v_staff AND sm.is_active AND sm.must_change_password
      AND sm.password_digest = md5('zz444-rotated-hash') AND sm.sync_state = 'ok'),
    'post-reset state wrong';
  ASSERT (SELECT count(*) FROM public.merchant_staff_events e
    WHERE e.staff_id = v_staff AND e.kind IN ('disabled','enabled','password_reset')) = 3,
    'missing state-change audits';
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff_events e
    WHERE e.staff_id = v_staff AND e.kind = 'password_reset'
      AND e.detail ? 'generation' AND NOT (e.detail ? 'password')),
    'password_reset audit must carry the generation and never a password';
END $$;

-- the barrier clears ONLY on a server-observed change after the mark
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT staffuser FROM zz444))::text, true);
  -- the owner knows the new one-time password: logging in as staff and
  -- clearing WITHOUT a change must be refused (security blocking 1)
  BEGIN PERFORM public.staff_password_changed();
    RAISE EXCEPTION 'zz444 sentinel: clear without change';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'password change not verified', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;
-- the staff member actually changes the password in GoTrue: clear succeeds
update auth.users set encrypted_password = 'zz444-final-hash'
 where id = (select staffuser from zz444);
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT staffuser FROM zz444))::text, true);
  PERFORM public.staff_password_changed();
END $$;
RESET ROLE;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff sm
    WHERE sm.id = v_staff AND NOT sm.must_change_password), 'barrier not cleared';
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff_events e
    WHERE e.staff_id = v_staff AND e.kind = 'password_changed'), 'password_changed audit missing';
END $$;

-- ============ 5b) recovery routes + malformed attestations (#262) =========
-- a STALE pending op (edge died) counts as failed after 10 minutes and the
-- row can be re-armed (security's timeout)
DO $$
BEGIN
  UPDATE public.merchant_staff
     SET sync_state = 'pending', sync_op = 'enable', sync_generation = gen_random_uuid(),
         is_active = false, updated_at = now() - interval '11 minutes'
   WHERE id = (SELECT staff FROM zz444);
END $$;
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  PERFORM public.staff_admin_set_active(v_staff, true);  -- re-arms over the stale pending
END $$;
RESET ROLE;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff sm
    WHERE sm.id = v_staff AND sm.sync_state = 'pending' AND sm.sync_op = 'enable'
      AND sm.updated_at > now() - interval '5 minutes'),
    'stale pending was not re-armed';
END $$;
-- tidy: fail the op so the next tests start from the blocked state
update zz444 set gen = (select sync_generation from public.merchant_staff where id = (select staff from zz444));
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  PERFORM public.staff_admin_sync_failed(v_staff, (SELECT gen FROM zz444));
END $$;
RESET ROLE;

-- a FAILED reset can be retried directly even though the row is inactive
DO $$
BEGIN
  UPDATE public.merchant_staff
     SET sync_state = 'failed', sync_op = 'reset', sync_generation = gen_random_uuid(),
         is_active = false, must_change_password = true, password_digest = NULL
   WHERE id = (SELECT staff FROM zz444);
END $$;
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
  v_gen uuid;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  v_gen := public.staff_admin_record_password_reset(v_staff);
  ASSERT v_gen IS NOT NULL, 'failed-reset retry refused';
END $$;
RESET ROLE;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff sm
    WHERE sm.id = v_staff AND sm.sync_state = 'pending' AND sm.sync_op = 'reset'),
    'failed-reset retry did not re-arm';
END $$;
update zz444 set gen = (select sync_generation from public.merchant_staff where id = (select staff from zz444));
-- recover fully: attest + mark + complete so later sections see an active row
update auth.users set encrypted_password = 'zz444-recovered-hash'
 where id = (select staffuser from zz444);
update auth.users
   set raw_app_meta_data = coalesce(raw_app_meta_data,'{}'::jsonb)
     || jsonb_build_object('staff_sync', jsonb_build_object(
         'generation', (SELECT gen FROM zz444), 'op', 'reset', 'at', now()))
 where id = (select staffuser from zz444);
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  PERFORM public.staff_admin_mark_password_rotated(v_staff, (SELECT gen FROM zz444));
  PERFORM public.staff_admin_sync_complete(v_staff, (SELECT gen FROM zz444));
END $$;
RESET ROLE;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff sm
    WHERE sm.id = v_staff AND sm.is_active AND sm.sync_state = 'ok'
      AND sm.password_digest = md5('zz444-recovered-hash')),
    'failed-reset recovery did not restore the row';
END $$;

-- a STALE PENDING reset (edge died mid-reset, row left inactive) re-arms
-- after the 10-minute timeout; the eligibility check must not fire first
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  PERFORM public.staff_admin_record_password_reset(v_staff);  -- arm a real reset
END $$;
RESET ROLE;
DO $$
BEGIN
  UPDATE public.merchant_staff SET updated_at = now() - interval '11 minutes'
   WHERE id = (SELECT staff FROM zz444);
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff sm
    WHERE sm.id = (SELECT staff FROM zz444) AND NOT sm.is_active
      AND sm.sync_state = 'pending' AND sm.sync_op = 'reset'),
    'fixture wrong: armed reset should be inactive + pending + reset';
END $$;
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
  v_gen uuid;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  v_gen := public.staff_admin_record_password_reset(v_staff);  -- retry after timeout
  ASSERT v_gen IS NOT NULL, 'stale pending reset was not re-armed';
END $$;
RESET ROLE;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff sm
    WHERE sm.id = v_staff AND sm.sync_state = 'pending' AND sm.sync_op = 'reset'
      AND sm.updated_at > now() - interval '5 minutes'),
    'stale pending reset retry did not re-arm';
END $$;
update zz444 set gen = (select sync_generation from public.merchant_staff where id = (select staff from zz444));
-- tidy: fail the op and restore the active row for later sections
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  PERFORM public.staff_admin_sync_failed(v_staff, (SELECT gen FROM zz444));
END $$;
RESET ROLE;
update public.merchant_staff
   set is_active = true, sync_state = 'ok', sync_op = NULL, sync_generation = NULL,
       password_digest = md5('zz444-recovered-hash')
 where id = (select staff from zz444);

-- a genuinely DISABLED row (completed disable, sync_state='ok') still refuses
-- a reset even when the row is old
DO $$
BEGIN
  UPDATE public.merchant_staff
     SET is_active = false, disabled_at = now(), disabled_by = (SELECT owner FROM zz444),
         sync_state = 'ok', sync_op = NULL, sync_generation = NULL,
         updated_at = now() - interval '1 hour'
   WHERE id = (SELECT staff FROM zz444);
END $$;
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  BEGIN PERFORM public.staff_admin_record_password_reset(v_staff);
    RAISE EXCEPTION 'zz444 sentinel: reset on a disabled row accepted';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'staff not found', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;
update public.merchant_staff
   set is_active = true, disabled_at = NULL, disabled_by = NULL,
       password_digest = md5('zz444-recovered-hash')
 where id = (select staff from zz444);

-- malformed attestations ALL fail closed (#262)
DO $$
BEGIN
  UPDATE public.merchant_staff
     SET sync_state = 'pending', sync_op = 'enable', sync_generation = gen_random_uuid(),
         is_active = false
   WHERE id = (SELECT staff FROM zz444);
  UPDATE zz444 SET gen = (SELECT sync_generation FROM public.merchant_staff
    WHERE id = (SELECT staff FROM zz444));
END $$;
-- case: missing 'at'
DO $$
BEGIN
  UPDATE auth.users SET raw_app_meta_data = jsonb_build_object('staff_sync', jsonb_build_object('generation', (SELECT gen FROM zz444), 'op', 'enable'))
   WHERE id = (SELECT staffuser FROM zz444);
END $$;
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  BEGIN PERFORM public.staff_admin_sync_complete(v_staff, (SELECT gen FROM zz444));
    RAISE EXCEPTION 'zz444 sentinel: malformed attestation accepted (missing at)';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'sync completion not verified', 'wrong error (missing at): ' || SQLERRM; END;
END $$;
RESET ROLE;
-- case: garbage 'at'
DO $$
BEGIN
  UPDATE auth.users SET raw_app_meta_data = jsonb_build_object('staff_sync', jsonb_build_object('generation', (SELECT gen FROM zz444), 'op', 'enable', 'at', 'zzz'))
   WHERE id = (SELECT staffuser FROM zz444);
END $$;
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  BEGIN PERFORM public.staff_admin_sync_complete(v_staff, (SELECT gen FROM zz444));
    RAISE EXCEPTION 'zz444 sentinel: malformed attestation accepted (garbage at)';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'sync completion not verified', 'wrong error (garbage at): ' || SQLERRM; END;
END $$;
RESET ROLE;
-- case: stale 'at'
DO $$
BEGIN
  UPDATE auth.users SET raw_app_meta_data = jsonb_build_object('staff_sync', jsonb_build_object('generation', (SELECT gen FROM zz444), 'op', 'enable', 'at', (now() - interval '1 hour')::text))
   WHERE id = (SELECT staffuser FROM zz444);
END $$;
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  BEGIN PERFORM public.staff_admin_sync_complete(v_staff, (SELECT gen FROM zz444));
    RAISE EXCEPTION 'zz444 sentinel: malformed attestation accepted (stale at)';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'sync completion not verified', 'wrong error (stale at): ' || SQLERRM; END;
END $$;
RESET ROLE;
-- case: future 'at'
DO $$
BEGIN
  UPDATE auth.users SET raw_app_meta_data = jsonb_build_object('staff_sync', jsonb_build_object('generation', (SELECT gen FROM zz444), 'op', 'enable', 'at', (now() + interval '1 hour')::text))
   WHERE id = (SELECT staffuser FROM zz444);
END $$;
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  BEGIN PERFORM public.staff_admin_sync_complete(v_staff, (SELECT gen FROM zz444));
    RAISE EXCEPTION 'zz444 sentinel: malformed attestation accepted (future at)';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'sync completion not verified', 'wrong error (future at): ' || SQLERRM; END;
END $$;
RESET ROLE;
-- case: missing generation key
DO $$
BEGIN
  UPDATE auth.users SET raw_app_meta_data = jsonb_build_object('staff_sync', jsonb_build_object('op', 'enable', 'at', now()))
   WHERE id = (SELECT staffuser FROM zz444);
END $$;
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  BEGIN PERFORM public.staff_admin_sync_complete(v_staff, (SELECT gen FROM zz444));
    RAISE EXCEPTION 'zz444 sentinel: malformed attestation accepted (missing generation key)';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'sync completion not verified', 'wrong error (missing generation key): ' || SQLERRM; END;
END $$;
RESET ROLE;
-- case: wrong op
DO $$
BEGIN
  UPDATE auth.users SET raw_app_meta_data = jsonb_build_object('staff_sync', jsonb_build_object('generation', (SELECT gen FROM zz444), 'op', 'reset', 'at', now()))
   WHERE id = (SELECT staffuser FROM zz444);
END $$;
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  BEGIN PERFORM public.staff_admin_sync_complete(v_staff, (SELECT gen FROM zz444));
    RAISE EXCEPTION 'zz444 sentinel: malformed attestation accepted (wrong op)';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'sync completion not verified', 'wrong error (wrong op): ' || SQLERRM; END;
END $$;
RESET ROLE;
-- case: non-object staff_sync
DO $$
BEGIN
  UPDATE auth.users SET raw_app_meta_data = jsonb_build_object('staff_sync', to_jsonb('junk'::text))
   WHERE id = (SELECT staffuser FROM zz444);
END $$;
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  BEGIN PERFORM public.staff_admin_sync_complete(v_staff, (SELECT gen FROM zz444));
    RAISE EXCEPTION 'zz444 sentinel: malformed attestation accepted (non-object staff_sync)';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'sync completion not verified', 'wrong error (non-object staff_sync): ' || SQLERRM; END;
END $$;
RESET ROLE;
-- and mark refuses a malformed attestation the same way
update auth.users set raw_app_meta_data = jsonb_build_object('staff_sync',
  jsonb_build_object('generation', (SELECT gen FROM zz444), 'op', 'enable', 'at', now()))
 where id = (select staffuser from zz444);
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  BEGIN PERFORM public.staff_admin_mark_password_rotated(v_staff, (SELECT gen FROM zz444));
    RAISE EXCEPTION 'zz444 sentinel: mark accepted a non-reset attestation';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz444 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'no pending sync operation', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;
-- tidy: clear the pending op for later sections
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_staff uuid := (SELECT staff FROM zz444);
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  PERFORM public.staff_admin_sync_failed(v_staff, (SELECT gen FROM zz444));
END $$;
RESET ROLE;
update public.merchant_staff
   set is_active = true, sync_state = 'ok', sync_op = NULL, sync_generation = NULL,
       password_digest = md5('zz444-recovered-hash')
 where id = (select staff from zz444);

-- ============ 6) audit_refusal routing (S1) =================================
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  -- owner: lands in the MERCHANT log as kind 'refused'
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  PERFORM public.staff_admin_audit_refusal((SELECT merchant FROM zz444), 'create_staff');
  -- outsider: NEVER in the merchant log; caller-keyed table instead
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT outsider FROM zz444))::text, true);
  PERFORM public.staff_admin_audit_refusal((SELECT merchant FROM zz444), 'create_staff');
  -- unlisted reasons are coerced to the bounded vocabulary (#263)
  PERFORM public.staff_admin_audit_refusal((SELECT merchant FROM zz444), 'gibberish-reason');
END $$;
RESET ROLE;
DO $$
BEGIN
  ASSERT (SELECT count(*) FROM public.merchant_staff_events e
    WHERE e.merchant_id = (SELECT merchant FROM zz444) AND e.kind = 'refused'
      AND e.actor_id = (SELECT owner FROM zz444)
      AND e.detail->>'action' = 'create_staff') = 1,
    'owner refusal missing from merchant log';
  ASSERT NOT EXISTS (SELECT 1 FROM public.merchant_staff_events e
    WHERE e.merchant_id = (SELECT merchant FROM zz444) AND e.kind = 'refused'
      AND e.actor_id = (SELECT outsider FROM zz444)),
    'non-owner refusal leaked into the merchant log';
  ASSERT (SELECT count(*) FROM public.staff_admin_refusals r
    WHERE r.caller_id = (SELECT outsider FROM zz444)
      AND r.merchant_id = (SELECT merchant FROM zz444)) = 2,
    'caller-keyed refusal rows missing';
END $$;

-- #263: BOTH branches are capped at 100/caller/day
DO $$
BEGIN
  -- the events table is append-only, so track the pre-existing owner
  -- 'refused' rows instead of deleting them
  CREATE TEMPORARY TABLE zz444_caps ON COMMIT DROP AS
  SELECT (SELECT count(*) FROM public.merchant_staff_events e
           WHERE e.merchant_id = (SELECT merchant FROM zz444) AND e.kind = 'refused'
             AND e.actor_id = (SELECT owner FROM zz444)) AS owner_base,
         (SELECT count(*) FROM public.staff_admin_refusals r
           WHERE r.caller_id = (SELECT outsider FROM zz444)) AS outsider_base;
  INSERT INTO public.merchant_staff_events (staff_id, merchant_id, kind, detail, actor_id)
  SELECT NULL, (SELECT merchant FROM zz444), 'refused',
         jsonb_build_object('action', 'create_staff'), (SELECT owner FROM zz444)
    FROM generate_series(1, 100);
  INSERT INTO public.staff_admin_refusals (caller_id, merchant_id, action)
  SELECT (SELECT outsider FROM zz444), (SELECT merchant FROM zz444), 'create_staff'
    FROM generate_series(1, 100);
END $$;
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz444))::text, true);
  PERFORM public.staff_admin_audit_refusal((SELECT merchant FROM zz444), 'create_staff');
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT outsider FROM zz444))::text, true);
  PERFORM public.staff_admin_audit_refusal((SELECT merchant FROM zz444), 'create_staff');
END $$;
RESET ROLE;
DO $$
BEGIN
  ASSERT (SELECT count(*) FROM public.merchant_staff_events e
    WHERE e.merchant_id = (SELECT merchant FROM zz444) AND e.kind = 'refused'
      AND e.actor_id = (SELECT owner FROM zz444))
      = 100 + (SELECT owner_base FROM zz444_caps),
    'owner-branch cap not enforced';
  ASSERT (SELECT count(*) FROM public.staff_admin_refusals r
    WHERE r.caller_id = (SELECT outsider FROM zz444))
      = 100 + (SELECT outsider_base FROM zz444_caps),
    'caller-keyed cap not enforced';
END $$;

-- ============ 7) self-signup can never become staff (S3) ====================
insert into auth.users(id, email, raw_user_meta_data)
values (gen_random_uuid(), 'zz444.selfsignup@example.invalid',
        '{"user_type":"merchant_staff","full_name":"Self Signup"}'::jsonb);
DO $$
BEGIN
  ASSERT EXISTS (SELECT 1 FROM public.users u
    WHERE u.email = 'zz444.selfsignup@example.invalid' AND u.user_type = 'customer'),
    'handle_new_user accepted merchant_staff from client metadata';
END $$;

-- ============ 8) first-login usability: 440 resolves the derived username ====
DO $$
DECLARE
  v_email text;
BEGIN
  v_email := public.auth_login_resolve_email(
    'zz444cashier__' || substr(replace((SELECT merchant FROM zz444)::text, '-', ''), 1, 6));
  ASSERT v_email = 'staff_zz444a@delwaqty.app',
    'derived username does not resolve at login: ' || coalesce(v_email, '<null>');
END $$;

-- ============ 9) grants: nothing for anon/PUBLIC ============================
DO $$
BEGIN
  ASSERT NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace,
         LATERAL aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
     WHERE n.nspname = 'public'
       AND p.proname IN ('is_cashier_type', 'staff_admin_provision_begin',
                         'staff_admin_provision_complete', 'staff_admin_provision_abort',
                         'staff_admin_set_active', 'staff_admin_record_password_reset',
                         'staff_admin_audit_refusal', 'staff_password_changed')
       AND a.grantee IN (0, (SELECT oid FROM pg_roles WHERE rolname = 'anon'))
       AND a.privilege_type = 'EXECUTE'),
    'anon/PUBLIC has EXECUTE on a 444 function';
  ASSERT NOT has_table_privilege('authenticated', 'public.staff_provisioning', 'SELECT'),
    'authenticated can read staff_provisioning';
  ASSERT NOT has_table_privilege('authenticated', 'public.staff_admin_refusals', 'SELECT'),
    'authenticated can read staff_admin_refusals';
END $$;

SELECT set_config('request.jwt.claims', '{}', true);
SELECT '444 suite OK' AS result;
ROLLBACK;
