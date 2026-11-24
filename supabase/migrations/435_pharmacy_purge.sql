-- 435: pharmacy PURGE - destructive, guarded, separately committed.
--
-- Owner decision 2026-11-24: pharmacy removed from Supabase completely.
-- This is the SECOND of two pharmacy migrations. Combined apply order:
--   431 - pharmacy RETIREMENT (non-destructive; already committed by the
--         time this runs; the platform is dark to clients either way).
--   433 - cashier drug_catalog drop (cashier worker).
--   434 - whatsapp_otp (other workstream).
--   435 (this) - destructive pharmacy purge.
-- Apply order: 431 -> 435 -> 433 -> 434. NEVER run 435 before 431; 433 needs 435's network-table drop for its drug_catalog drop.
--
-- Machine-gated dependency contract (code review #173): NO manual
-- destructive steps outside this file's guards.
--   Gate A (after writer freeze + table locks, at the frozen boundary):
--   asserts migration 431 is fully applied
--     (retirement post-state markers present) - aborts otherwise.
--   Gate B (after Gate A, same frozen boundary): verifies the 433
--   contract. The REAL order is
--     431 -> 435 -> 433: 341 and 340 created TWO NO-ACTION FKs into
--     drug_catalog -
--       pharmacy_transfer_requests.drug_catalog_id  (dropped here, Phase C)
--       pos_stock_moves.drug_catalog_id             (dropped by cashier 433)
--     433 cannot drop drug_catalog until this file has removed the first
--     FK, so 435 lands BEFORE 433. A fully-applied 433 is also accepted
--     (convergent re-run). No manual Phase C, ever.
--   Backup readiness: the pg_dump in PRE-FLIGHT step 2 must exist BEFORE
--     this file is applied; the guards below cannot verify the file, so
--     the builder confirms it in the PR checklist (staging output pasted).
--
-- ═══════════════════════ PRE-FLIGHT (builder, manual) ═══════════════════
-- Run on STAGING first, then PROD. Do not apply before every inventory
-- query returns the expected counts and a backup dump exists.
--
-- 1) Inventory (both envs, save output):
--    SELECT type, count(*) FROM merchants GROUP BY type;
--    SELECT count(*) FROM merchants WHERE type='pharmacy';
--    SELECT count(*) FROM products p JOIN merchants m ON m.id=p.merchant_id WHERE m.type='pharmacy';
--    SELECT count(*) FROM orders o JOIN merchants m ON m.id=o.merchant_id WHERE m.type='pharmacy';
--    SELECT count(*) FROM rides r JOIN merchants m ON m.id=r.merchant_id WHERE m.type='pharmacy';
--    SELECT count(*) FROM rides WHERE service_type='pharmacy_delivery';
--    SELECT count(*) FROM ride_requests rq JOIN rides r ON r.id=rq.ride_id WHERE r.service_type='pharmacy_delivery';
--    SELECT count(*) FROM driver_earnings e JOIN rides r ON r.id=e.ride_id WHERE r.service_type='pharmacy_delivery';
--    SELECT count(*) FROM platform_commissions pc JOIN rides r ON pc.reference_type='ride' AND pc.reference_id=r.id WHERE r.service_type='pharmacy_delivery';
--    SELECT id, service_types, accepts_deliveries FROM drivers WHERE service_types @> ARRAY['pharmacy']::text[];
--    SELECT count(*) FROM commission_rules WHERE entity_key IN ('pharmacy','pharmacy_delivery');
--    SELECT count(*) FROM pharmacy_links; SELECT count(*) FROM pharmacy_transfer_requests;
--    SELECT count(*) FROM pharmacy_transfer_ledger; SELECT count(*) FROM pharmacy_messages;
--    SELECT count(*) FROM delivery_pricing WHERE service_type='pharmacy_delivery';
--    SELECT count(*) FROM categories WHERE lower(coalesce(name,'')) LIKE '%pharm%' OR coalesce(name_ar,'') LIKE '%صيدل%';
--    SELECT count(*) FROM catalog_categories WHERE merchant_type='pharmacy';
--    SELECT count(*) FROM offers o JOIN merchants m ON m.id=o.merchant_id WHERE m.type='pharmacy';
--    SELECT count(*) FROM provider_business_profiles WHERE category_type='pharmacy';
--    SELECT count(*) FROM users WHERE active_provider_category='pharmacy';
--    SELECT count(*) FROM notifications WHERE title ILIKE '%pharm%' OR body ILIKE '%pharm%' OR title LIKE '%صيدل%' OR body LIKE '%صيدل%';
--
-- 2) Backup (both envs) BEFORE any destructive step:
--      pg_dump "$DB_URL" --data-only \
--        -t merchants -t products -t orders -t rides -t ride_requests \
--        -t drivers -t driver_earnings -t platform_commissions \
--        -t commission_rules -t pharmacy_links -t pharmacy_transfer_requests \
--        -t pharmacy_transfer_ledger -t pharmacy_messages \
--        -t categories -t catalog_categories -t offers -t notifications \
--        -t delivery_pricing -t provider_business_profiles -t users \
--        -t merchant_ledger -t reviews \
--        > pharmacy_purge_backup_$(date +%Y%m%d).sql
--    Store the dump outside the repo; note its location in the PR.
--
-- 3) Dependents: orders/rides/merchant_ledger/reviews/pos_sales/coupons/
--    driver_obligations/driver_earnings/platform_commissions reference
--    merchants or rides WITHOUT cascade. If inventory shows a pharmacy
--    merchant or pharmacy_delivery ride with such dependents, or ANY
--    non-empty pharmacy network table, the guards below ABORT before any
--    mutation (431's retirement stays committed). Demo/test dependents
--    (prod is test data only per the owner) may then be deleted in FK
--    order after the backup; real financial history goes back to the
--    owner for an explicit keep-or-delete decision before re-running.
-- ═══════════════════════════════════════════════════════════════════════

BEGIN;

-- No partial applies: fail fast on lock contention or a slow statement.
-- A timeout aborts the whole transaction and leaves prod untouched.
SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '180s';

-- ─── Writer freeze: revoke network-table writers, then lock ───────────
-- No lock ordering gap: revoke every client writer first (431 already
-- revoked the RPC wrappers), then take the locks the guards rely on.
DO $g$
DECLARE
  v_tbl text;
BEGIN
  FOREACH v_tbl IN ARRAY ARRAY['pharmacy_links','pharmacy_transfer_requests','pharmacy_transfer_ledger','pharmacy_messages'] LOOP
    IF to_regclass('public.' || v_tbl) IS NOT NULL THEN
      EXECUTE format('REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE public.%I FROM PUBLIC, anon, authenticated', v_tbl);
    END IF;
  END LOOP;
END $g$;

-- Mutation targets
LOCK TABLE public.merchants IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.rides IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.offers IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.categories IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.catalog_categories IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.provider_business_profiles IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.users IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.notifications IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.delivery_pricing IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.commission_rules IN SHARE ROW EXCLUSIVE MODE;
-- Dependent financial/operational tables the guards read: a plain
-- SHARE ROW EXCLUSIVE on merchants/rides does NOT freeze child writers
-- (a driver_earnings insert takes only a KEY SHARE on the parent), so
-- every table the guard consults is locked against writes here, and the
-- guard-then-delete below runs inside this same locked window.
LOCK TABLE public.orders IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.ride_requests IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.merchant_ledger IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.reviews IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.pos_sales IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.pos_stock_moves IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.pos_price_history IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.coupons IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.driver_obligations IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.merchant_payout_requests IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.delivery_incidents IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.driver_earnings IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.complaints IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.driver_delay_events IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.promo_redemptions IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.platform_commissions IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.wallet_transactions IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.audit_log IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.drivers IN SHARE ROW EXCLUSIVE MODE;
DO $g$
DECLARE
  v_tbl text;
BEGIN
  FOREACH v_tbl IN ARRAY ARRAY['pharmacy_links','pharmacy_transfer_requests','pharmacy_transfer_ledger','pharmacy_messages'] LOOP
    IF to_regclass('public.' || v_tbl) IS NOT NULL THEN
      EXECUTE format('LOCK TABLE public.%I IN ACCESS EXCLUSIVE MODE', v_tbl);
    END IF;
  END LOOP;
END $g$;

-- ─── Gate A: 431 retirement markers (machine check) ─────────────────
-- Verifies the recorded 431 post-state markers, not one marker. This is
-- a checklist of the known 431 effects, not a claim of complete
-- exact-431 verification: all 7 replaced
-- function bodies at their post-image md5, the 3-value column default,
-- no pharmacy driver capability, every pharmacy merchant suspended and
-- closed, pharmacy workspaces gone, no active pharmacy selection, no
-- active pharmacy offer/category/pricing, and no client-facing EXECUTE
-- on the 9 network RPCs. NULL-safe: a missing function or NULL body
-- fails the check instead of passing a NOT LIKE.
DO $g$
DECLARE
  r record;
  v_md5 text;
  v_secdef boolean;
  v_cfg text;
  v_owner text;
  v_overloads int;
BEGIN
  FOR r IN
    -- Per-signature expected shape (security review, verified on prod):
    -- the 5 profile RPCs and request/switch are SECURITY DEFINER with a
    -- pinned search_path; driver_capability_bounds_guard is SECURITY
    -- INVOKER with a pinned search_path; search_intent_category is
    -- SECURITY INVOKER, IMMUTABLE, proconfig NULL (no pinned path).
    SELECT * FROM (VALUES
      ('get_my_provider_profiles()', '0f5a1c5eb6f13677ed7c9f77cf6c95eb', true,  'search_path=public, pg_temp'),
      ('complete_driver_onboarding(uuid)', '7c8dd90a0aa2ed8396e8100d8b499888', true,  'search_path=public, pg_temp'),
      ('update_driver_capabilities(uuid,text[],boolean,numeric,numeric)', '0227ce83f9b08dc744d2e75f50de8566', true,  'search_path=public, pg_temp'),
      ('driver_capability_bounds_guard()', 'b0592984b89143247f787ba91c4051c0', false, 'search_path=public, pg_temp'),
      ('search_intent_category(text)', '05e8d790f1466cb6b8ae9a7f6c3e47f6', false, NULL::text),
      ('request_additional_provider_profile(text,text)', '9a872ff9f1a33289602890135479614e', true,  'search_path=public, pg_temp'),
      ('switch_active_provider_profile(text)', 'db574dfddd424c2ec132099e82f67e4c', true,  'search_path=public, pg_temp')
    ) AS t(sig, md5_post, secdef_expected, cfg_expected)
  LOOP
    SELECT count(*) INTO v_overloads
      FROM pg_proc pr JOIN pg_namespace n ON n.oid = pr.pronamespace
     WHERE n.nspname = 'public'
       AND pr.proname = split_part(r.sig, '(', 1);
    IF v_overloads <> 1 THEN
      RAISE EXCEPTION '435 Gate A: % has % overloads (expected exactly 1) - schema drift, aborting', r.sig, v_overloads;
    END IF;
    SELECT md5(pr.prosrc), pr.prosecdef,
           array_to_string(pr.proconfig, ';'),
           pg_get_userbyid(pr.proowner)
      INTO v_md5, v_secdef, v_cfg, v_owner
      FROM pg_proc pr WHERE pr.oid = ('public.' || r.sig)::regprocedure;
    IF v_md5 IS DISTINCT FROM r.md5_post THEN
      RAISE EXCEPTION '435 Gate A: % is not at the 431 post-image (md5 %) - apply 431 first', r.sig, coalesce(v_md5, 'MISSING');
    END IF;
    -- Shape check against the per-signature expectation carried in the
    -- VALUES list above: exact SECURITY DEFINER/INVOKER mode, and the
    -- exact search_path config (NULL-safe; search_intent_category is
    -- expected to have NONE).
    IF v_secdef IS DISTINCT FROM r.secdef_expected THEN
      RAISE EXCEPTION '435 Gate A: % security mode drift (secdef=%, expected %) - schema drift since 431, aborting', r.sig, v_secdef, r.secdef_expected;
    END IF;
    -- Exact config comparison (no substring matching): the stored
    -- proconfig must equal the expectation verbatim.
    IF v_cfg IS DISTINCT FROM r.cfg_expected THEN
      RAISE EXCEPTION '435 Gate A: % search_path config is %, expected % - schema drift since 431, aborting', r.sig, coalesce(v_cfg, 'NONE'), coalesce(r.cfg_expected, 'NONE');
    END IF;
    -- Owner: all 7 are migration-owned (postgres on this platform).
    IF v_owner IS DISTINCT FROM 'postgres' THEN
      RAISE EXCEPTION '435 Gate A: % owner is %, expected postgres - schema drift, aborting', r.sig, v_owner;
    END IF;
  END LOOP;

  -- trigger shape: driver_capability_bounds must still fire the guard on
  -- service_types changes, exactly as 416 installed it.
  -- Trigger shape, exact OIDs: the BEFORE INSERT/UPDATE trigger on
  -- public.drivers must point at the guard function's exact OID.
  IF NOT EXISTS (SELECT 1 FROM pg_trigger t
                  WHERE t.tgrelid = 'public.drivers'::regclass
                    AND t.tgname = 'driver_capability_bounds'
                    AND t.tgfoid = 'public.driver_capability_bounds_guard()'::regprocedure
                    AND t.tgenabled = 'O'
                    AND t.tgtype = 23  -- ROW|BEFORE|INSERT|UPDATE
                    AND t.tgqual IS NULL  -- no WHEN clause in the 416 definition
                    AND string_to_array(t.tgattr::text, ' ')::smallint[] = (
                          SELECT array_agg(a.attnum ORDER BY u.ord)::smallint[]
                            FROM (VALUES (1,'service_types'), (2,'accepts_deliveries'),
                                         (3,'max_delivery_distance_km'), (4,'max_weight_kg')) u(ord, col)
                            JOIN pg_attribute a ON a.attrelid = 'public.drivers'::regclass
                                              AND a.attname = u.col)) THEN
    RAISE EXCEPTION '435 Gate A: driver_capability_bounds trigger missing/disabled/rewired (name, function, timing or UPDATE OF column list) - schema drift since 431, aborting';
  END IF;

  IF (SELECT pg_get_expr(a.adbin, a.adrelid)
        FROM pg_attrdef a
       WHERE a.adrelid = 'public.drivers'::regclass
         AND a.adnum = (SELECT attnum FROM pg_attribute
                         WHERE attrelid = 'public.drivers'::regclass AND attname = 'service_types'))
     IS DISTINCT FROM 'ARRAY[''food''::text, ''grocery''::text, ''parcel''::text]' THEN
    RAISE EXCEPTION '435 Gate A: drivers.service_types default not at the 431 post-state - apply 431 first';
  END IF;

  IF EXISTS (SELECT 1 FROM public.drivers WHERE service_types @> ARRAY['pharmacy']::text[])
     OR EXISTS (SELECT 1 FROM public.merchants WHERE type = 'pharmacy' AND (status <> 'suspended' OR is_open))
     OR EXISTS (SELECT 1 FROM public.provider_business_profiles WHERE category_type = 'pharmacy')
     OR EXISTS (SELECT 1 FROM public.users WHERE active_provider_category = 'pharmacy')
     OR EXISTS (SELECT 1 FROM public.offers o JOIN public.merchants m ON m.id = o.merchant_id WHERE m.type = 'pharmacy' AND o.is_active)
     OR EXISTS (SELECT 1 FROM public.catalog_categories WHERE is_active AND merchant_type = 'pharmacy')
     OR EXISTS (SELECT 1 FROM public.delivery_pricing WHERE service_type = 'pharmacy_delivery' AND is_active)
     OR EXISTS (SELECT 1 FROM public.rides WHERE service_type = 'pharmacy_delivery' AND status = 'searching')
     OR EXISTS (SELECT 1 FROM public.ride_requests rr JOIN public.rides rd ON rd.id = rr.ride_id
                 WHERE rd.service_type = 'pharmacy_delivery' AND rr.status = 'offered')
     OR EXISTS (SELECT 1 FROM public.offers o JOIN public.catalog_categories c ON c.id = o.category_id
                 WHERE o.merchant_id IS NULL AND c.merchant_type = 'pharmacy' AND o.is_active)
     OR EXISTS (SELECT 1
                  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace,
                       aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a
                 WHERE n.nspname = 'public'
                   AND p.proname IN ('pharmacy_import_drug','pharmacy_directory','pharmacy_link_create',
                                     'pharmacy_transfer_request','pharmacy_transfer_respond','pharmacy_transfer_handover',
                                     'pharmacy_transfer_settle','pharmacy_transfer_settle_confirm','pharmacy_message_send')
                   AND a.privilege_type = 'EXECUTE'
                   AND (a.grantee = 0 OR a.grantee IN ('authenticated'::regrole, 'anon'::regrole)))
  THEN
    RAISE EXCEPTION '435 Gate A: 431 retirement incomplete (data or ACL markers missing) - apply 431 first, then re-run 435';
  END IF;
END $g$;

-- ─── Gate B: 433 drug_catalog contract (three NULL-safe states) ─────
-- Apply plan (real orchestration order): 431 -> 435 -> 433 -> 434.
-- 435 Phase C drops pharmacy_transfer_requests (one of the TWO
-- NO-ACTION FKs into drug_catalog); 433 then drops the other
-- (pos_stock_moves) and the table. All lookups go through to_regclass
-- (NULL-safe); a bare '...'::regclass would raise when the catalog is
-- absent. Exactly three states are accepted, anything else is drift:
--   pre-435/pre-433 : drug_catalog, transfer_requests and the
--                     pos_stock_moves FK all present (fresh run).
--   post-435/pre-433: drug_catalog present, transfer_requests absent,
--                     pos_stock_moves FK still present (valid re-run of
--                     this file after a prior partial/completed 435).
--   post-433        : drug_catalog, transfer_requests and the
--                     pos_stock_moves FK all absent (433 fully applied;
--                     435 re-run converges).
-- Each state requires its EXACT FK/object shape; mixed shapes abort.
DO $g$
DECLARE
  v_dc      boolean := to_regclass('public.drug_catalog') IS NOT NULL;
  v_tr      boolean := to_regclass('public.pharmacy_transfer_requests') IS NOT NULL;
  v_pos_oid oid     := to_regclass('public.pos_stock_moves');
  v_dc_oid  oid     := to_regclass('public.drug_catalog');
  v_pos_fk  boolean := false;
  v_tr_fk   boolean := false;
BEGIN
  -- Exact FK shape, not just existence: each side must be a FOREIGN
  -- KEY from the expected column (drug_catalog_id) to drug_catalog(id)
  -- with NO ACTION on update and delete (the definitions in 340/341).
  IF v_pos_oid IS NOT NULL AND v_dc_oid IS NOT NULL THEN
    SELECT EXISTS (SELECT 1 FROM pg_constraint c
                    WHERE c.conrelid = v_pos_oid AND c.confrelid = v_dc_oid
                      AND c.contype = 'f'
                      AND c.conkey = ARRAY[(SELECT attnum::int2 FROM pg_attribute
                                             WHERE attrelid = v_pos_oid AND attname = 'drug_catalog_id')]
                      AND c.confkey = ARRAY[(SELECT attnum::int2 FROM pg_attribute
                                              WHERE attrelid = v_dc_oid AND attname = 'id')]
                      AND c.confupdtype = 'a' AND c.confdeltype = 'a') INTO v_pos_fk;
  END IF;
  IF to_regclass('public.pharmacy_transfer_requests') IS NOT NULL AND v_dc_oid IS NOT NULL THEN
    SELECT EXISTS (SELECT 1 FROM pg_constraint c
                    WHERE c.conrelid = 'public.pharmacy_transfer_requests'::regclass
                      AND c.confrelid = v_dc_oid
                      AND c.contype = 'f'
                      AND c.conkey = ARRAY[(SELECT attnum::int2 FROM pg_attribute
                                             WHERE attrelid = 'public.pharmacy_transfer_requests'::regclass
                                               AND attname = 'drug_catalog_id')]
                      AND c.confkey = ARRAY[(SELECT attnum::int2 FROM pg_attribute
                                              WHERE attrelid = v_dc_oid AND attname = 'id')]
                      AND c.confupdtype = 'a' AND c.confdeltype = 'a') INTO v_tr_fk;
  END IF;

  IF v_dc AND v_tr AND v_pos_fk AND v_tr_fk THEN
    RAISE NOTICE '435 Gate B: pre-435/pre-433 state - proceeding; Phase C drops the pharmacy_transfer_requests FK side';
  ELSIF v_dc AND NOT v_tr AND v_pos_fk THEN
    RAISE NOTICE '435 Gate B: post-435/pre-433 re-run state - transfer_requests gone, catalog + pos FK still present; proceeding';
  ELSIF NOT v_dc AND NOT v_tr AND NOT v_pos_fk AND NOT v_tr_fk THEN
    RAISE NOTICE '435 Gate B: post-433 state - drug_catalog and both FK sides already gone';
  ELSE
    RAISE EXCEPTION '435 Gate B: inconsistent 433 state (drug_catalog=%, transfer_requests=%, pos_fk=%, tr_fk=%) - drift, aborting',
      v_dc, v_tr, v_pos_fk, v_tr_fk;
  END IF;
END $g$;



-- ─── Guard 0: exact pre-state classification (code review #164) ───────
-- The two CHECK defs must match the known LIVE pre-state exactly (the
-- baseline 44-value merchants list with 'pharmacy' and the 9-value rides
-- list with 'pharmacy_delivery'), or the known post-state (already
-- applied -> idempotent skip). Anything else is schema drift: abort
-- BEFORE any mutation.
DO $g$
DECLARE
  v_merchants text;
  v_rides text;
  v_merchants_pre constant text := 'CHECK ((type = ANY (ARRAY[''food''::text, ''restaurant''::text, ''grocery''::text, ''supermarket''::text, ''pharmacy''::text, ''electronics''::text, ''fashion''::text, ''flowers''::text, ''bakery''::text, ''general''::text, ''fruits''::text, ''meat''::text, ''seafood''::text, ''sweets''::text, ''clothing''::text, ''shoes''::text, ''mobile''::text, ''furniture''::text, ''home''::text, ''cafe''::text, ''petShop''::text, ''fitness''::text, ''gas''::text, ''carwash''::text, ''perfumes''::text, ''spices''::text, ''dairy''::text, ''accessories''::text, ''butcher''::text, ''vegetables''::text, ''service''::text, ''home_services''::text, ''plumbing''::text, ''electrical''::text, ''cleaning''::text, ''handyman''::text, ''carpentry''::text, ''ac_maintenance''::text, ''painting''::text, ''pest_control''::text, ''appliance_repair''::text, ''doctor''::text, ''clinic''::text, ''other''::text])))';
  v_rides_pre constant text := 'CHECK ((service_type = ANY (ARRAY[''ride''::text, ''food_delivery''::text, ''grocery_delivery''::text, ''pharmacy_delivery''::text, ''marketplace_delivery''::text, ''courier''::text, ''package_delivery''::text, ''document_delivery''::text, ''flower_delivery''::text, ''retail_delivery''::text])))';
  v_merchants_post constant text := 'CHECK ((type = ANY (ARRAY[''food''::text, ''restaurant''::text, ''grocery''::text, ''supermarket''::text, ''electronics''::text, ''fashion''::text, ''flowers''::text, ''bakery''::text, ''general''::text, ''fruits''::text, ''meat''::text, ''seafood''::text, ''sweets''::text, ''clothing''::text, ''shoes''::text, ''mobile''::text, ''furniture''::text, ''home''::text, ''cafe''::text, ''petShop''::text, ''fitness''::text, ''gas''::text, ''carwash''::text, ''perfumes''::text, ''spices''::text, ''dairy''::text, ''accessories''::text, ''butcher''::text, ''vegetables''::text, ''service''::text, ''home_services''::text, ''plumbing''::text, ''electrical''::text, ''cleaning''::text, ''handyman''::text, ''carpentry''::text, ''ac_maintenance''::text, ''painting''::text, ''pest_control''::text, ''appliance_repair''::text, ''doctor''::text, ''clinic''::text, ''other''::text])))';
  v_rides_post constant text := 'CHECK ((service_type = ANY (ARRAY[''ride''::text, ''food_delivery''::text, ''grocery_delivery''::text, ''marketplace_delivery''::text, ''courier''::text, ''package_delivery''::text, ''document_delivery''::text, ''flower_delivery''::text, ''retail_delivery''::text])))';
  v_m_state text;
  v_r_state text;
BEGIN
  SELECT pg_get_constraintdef(oid) INTO v_merchants FROM pg_constraint
   WHERE conname = 'merchants_type_check' AND conrelid = 'public.merchants'::regclass;
  SELECT pg_get_constraintdef(oid) INTO v_rides FROM pg_constraint
   WHERE conname = 'rides_service_type_check' AND conrelid = 'public.rides'::regclass;

  IF v_merchants IS NULL OR v_rides IS NULL THEN
    RAISE EXCEPTION '435: expected CHECK constraint missing (merchants=%, rides=%) - schema drift, aborting before any mutation',
      v_merchants IS NOT NULL, v_rides IS NOT NULL;
  END IF;

  v_m_state := CASE regexp_replace(v_merchants, '\s+', ' ', 'g')
                 WHEN v_merchants_pre THEN 'pre'
                 WHEN v_merchants_post THEN 'post'
                 ELSE 'drift' END;
  v_r_state := CASE regexp_replace(v_rides, '\s+', ' ', 'g')
                 WHEN v_rides_pre THEN 'pre'
                 WHEN v_rides_post THEN 'post'
                 ELSE 'drift' END;

  -- all-pre or all-post; mixed state is a partial application - abort
  IF v_m_state = 'drift' OR v_r_state = 'drift' OR v_m_state <> v_r_state THEN
    RAISE EXCEPTION '435: constraint state drift or mixed pre/post (merchants=%, rides=%) - aborting before any mutation; inspect and re-target the migration',
      v_m_state, v_r_state;
  END IF;

  IF v_m_state = 'post' THEN
    RAISE NOTICE '435: constraints already at post-state - prior run detected; remaining phases are idempotent';
  END IF;
END $g$;

-- ─── Guard 1: financial/operational dependents block the purge ────────
-- Runs BEFORE any mutation. Covers every non-cascading reference found in
-- the schema audit, including driver_earnings (SET NULL), complaints,
-- driver_delay_events, promo_redemptions, platform_commissions,
-- wallet_transactions and audit_log (code review #162), and any paid or
-- completed pharmacy_delivery ride.

DO $g$
DECLARE
  v_blocked_merchants text;
  v_blocked_rides text;
  v_blocked_network text;
  v_tbl text;
  v_nonempty boolean;
BEGIN
  SELECT string_agg(DISTINCT m.id::text, ',') INTO v_blocked_merchants
    FROM public.merchants m
   WHERE m.type = 'pharmacy'
     AND (EXISTS (SELECT 1 FROM public.orders o WHERE o.merchant_id = m.id)
       OR EXISTS (SELECT 1 FROM public.rides r WHERE r.merchant_id = m.id)
       OR EXISTS (SELECT 1 FROM public.merchant_ledger l WHERE l.merchant_id = m.id)
       OR EXISTS (SELECT 1 FROM public.reviews rv WHERE rv.merchant_id = m.id)
       OR EXISTS (SELECT 1 FROM public.pos_sales ps WHERE ps.merchant_id = m.id)
       OR EXISTS (SELECT 1 FROM public.coupons cp WHERE cp.merchant_id = m.id)
       OR EXISTS (SELECT 1 FROM public.driver_obligations dob WHERE dob.merchant_id = m.id)
       OR EXISTS (SELECT 1 FROM public.merchant_payout_requests pr WHERE pr.merchant_id = m.id)
       OR EXISTS (SELECT 1 FROM public.audit_log a WHERE a.resource = 'merchant' AND a.resource_id = m.id::text)
       OR EXISTS (SELECT 1 FROM public.pos_stock_moves sm WHERE sm.merchant_id = m.id)
       OR EXISTS (SELECT 1 FROM public.pos_price_history ph WHERE ph.merchant_id = m.id));
  IF v_blocked_merchants IS NOT NULL THEN
    RAISE EXCEPTION '435: pharmacy merchants with dependent rows: % - back up, resolve per PRE-FLIGHT step 3, re-run', v_blocked_merchants;
  END IF;

  SELECT string_agg(DISTINCT r.id::text, ',') INTO v_blocked_rides
    FROM public.rides r
   WHERE r.service_type = 'pharmacy_delivery'
     AND (r.status IN ('matched', 'arrived', 'inTrip', 'completed')
       OR r.payment_status = 'paid'
       OR EXISTS (SELECT 1 FROM public.delivery_incidents i WHERE i.ride_id = r.id)
       OR EXISTS (SELECT 1 FROM public.driver_obligations dob WHERE dob.ride_id = r.id)
       OR EXISTS (SELECT 1 FROM public.drivers dr WHERE dr.current_delivery_id = r.id)
       OR EXISTS (SELECT 1 FROM public.driver_earnings e WHERE e.ride_id = r.id)
       OR EXISTS (SELECT 1 FROM public.complaints cm WHERE cm.ride_id = r.id)
       OR EXISTS (SELECT 1 FROM public.driver_delay_events de WHERE de.ride_id = r.id)
       OR EXISTS (SELECT 1 FROM public.promo_redemptions pr WHERE pr.ride_id = r.id)
       OR EXISTS (SELECT 1 FROM public.platform_commissions pc WHERE pc.reference_type = 'ride' AND pc.reference_id = r.id)
       OR EXISTS (SELECT 1 FROM public.wallet_transactions wt WHERE wt.reference_type = 'ride' AND wt.reference_id = r.id)
       OR EXISTS (SELECT 1 FROM public.audit_log a WHERE a.resource = 'ride' AND a.resource_id = r.id::text));
  IF v_blocked_rides IS NOT NULL THEN
    RAISE EXCEPTION '435: pharmacy_delivery rides with financial/operational dependents or paid/completed state: % - back up, resolve per PRE-FLIGHT step 3, re-run', v_blocked_rides;
  END IF;

  -- Pharmacy network tables: any row at all is transfer/settlement
  -- history (code review #162). Deleting merchants would CASCADE through
  -- pharmacy_links into requests and ledger, so block on non-empty.
  -- existence-aware: on a second run these tables are already dropped
  FOR v_tbl IN SELECT t FROM (VALUES ('pharmacy_links'), ('pharmacy_transfer_requests'),
                                     ('pharmacy_transfer_ledger'), ('pharmacy_messages')) AS u(t)
  LOOP
    IF to_regclass('public.' || v_tbl) IS NOT NULL THEN
      EXECUTE format('SELECT EXISTS (SELECT 1 FROM public.%I)', v_tbl) INTO v_nonempty;
      IF v_nonempty THEN
        v_blocked_network := coalesce(v_blocked_network || ',', '') || v_tbl;
      END IF;
    END IF;
  END LOOP;
  IF v_blocked_network IS NOT NULL THEN
    RAISE EXCEPTION '435: non-empty pharmacy network tables: % - back up (PRE-FLIGHT step 2), verify test-only with the owner, delete in FK order, re-run', v_blocked_network;
  END IF;
END $g$;

-- ─── Phase B: pharmacy data (guards passed above) ─────────────────────

-- Notifications: reviewed fixed list only (code review #175). The
-- security reviewer found exactly ONE pharmacy-mentioning notification
-- on prod; its id must be pasted into v_reviewed_ids below after the
-- staging dry-run confirms the same row. The block aborts if the list is
-- empty (not reviewed) or if ANY pharmacy-mentioning row exists beyond
-- the reviewed ids. No text-pattern delete ever runs.
DO $n$
DECLARE
  -- REVIEWED LIST (code review #175). Security review 2026-11-24 found
  -- exactly ONE pharmacy-mentioning notification on prod (188 total):
  --   id c81cd7d1-3564-4444-b659-a2deb4516459, title 'Service Line
  --   Approved', user afa2f019-... , created 2026-11-22 22:58 UTC.
  -- Per-ID content binding is exact (id, title, full user UUID, body).
  -- The builder MUST re-run the 4-pattern predicate on staging and prod
  -- right before apply and record any extra row here the same way.
  -- Safe absent/deleted post-state: a listed id that is already gone is
  -- ACCEPTED (clean harness DB, or a second run after a successful
  -- first apply) - as long as no unlisted candidate remains.
  v_candidates int;
  v_unlisted int;
  v_row record;  -- id, title, body, user_id
  v_deleted int;
  v_present int;
  -- (id, title, full user UUID, body md5) bindings. body_md5 NULL means
  -- "the recorded body text has not been pasted yet" - the row must then
  -- still match the pharmacy predicate in its body (see below). The
  -- reviewer confirmed the full user UUID AND md5(body) from live prod
  -- (both pasted below). The md5 binding is the PROD value: it is
  -- enforced on any environment where the row exists (prod, or a
  -- staging that mirrors it); on a clean DB the row is absent, which is
  -- the accepted post-state. If a non-mirroring environment holds the
  -- row with a different body, bind that environment's md5 on a
  -- separate row instead of weakening this one.
  v_rec record;
BEGIN
  SELECT count(*) INTO v_candidates
    FROM public.notifications
   WHERE title ILIKE '%pharm%' OR body ILIKE '%pharm%'
      OR title LIKE '%صيدل%' OR body LIKE '%صيدل%';

  -- Anti-join: no candidate may exist beyond the reviewed ids.
  SELECT count(*) INTO v_unlisted
    FROM public.notifications n
   WHERE (n.title ILIKE '%pharm%' OR n.body ILIKE '%pharm%'
       OR n.title LIKE '%صيدل%' OR n.body LIKE '%صيدل%')
     AND n.id <> ALL (ARRAY['c81cd7d1-3564-4444-b659-a2deb4516459']::uuid[]);
  IF v_unlisted > 0 THEN
    RAISE EXCEPTION '435: % unlisted pharmacy-mentioning notification(s) match the predicate - review them, add exact bindings, re-run', v_unlisted;
  END IF;

  -- Per-ID exact content binding. Absent = already deleted (safe
  -- post-state); present = content must match the recorded expectation
  -- exactly or we abort.
  FOR v_rec IN
    SELECT * FROM (VALUES
      ('c81cd7d1-3564-4444-b659-a2deb4516459'::uuid,
       'Service Line Approved'::text,
       'afa2f019-a51a-450f-a750-14e629c840eb'::uuid,  -- full UUID from the security reviewer 2026-11-24
       '1ac6b3f951126bb13e0655fb97b78e28'::text)    -- md5(body), live PROD value verified by the security reviewer 2026-11-24; enforced wherever the row exists (it only exists on prod / a prod mirror)
    ) AS t(id, title_expected, user_expected, body_md5_expected)
  LOOP
    SELECT id, title, body, user_id INTO v_row FROM public.notifications WHERE id = v_rec.id;
    IF FOUND THEN
      IF v_row.title IS DISTINCT FROM v_rec.title_expected
         OR v_row.user_id IS DISTINCT FROM v_rec.user_expected THEN
        RAISE EXCEPTION '435: reviewed notification % content differs from the binding (title=%, user=%) - re-review before apply', v_rec.id, v_row.title, v_row.user_id;
      END IF;
      -- Body binding: exact md5 when recorded, otherwise the body must
      -- still match the pharmacy predicate (the row is being deleted
      -- BECAUSE it is a pharmacy notice; a body that no longer says so
      -- means the row changed since review).
      IF v_rec.body_md5_expected IS NOT NULL THEN
        IF md5(coalesce(v_row.body, '')) IS DISTINCT FROM v_rec.body_md5_expected THEN
          RAISE EXCEPTION '435: reviewed notification % body md5 differs from the binding - re-review before apply', v_rec.id;
        END IF;
      ELSIF NOT (v_row.body ILIKE '%pharm%' OR v_row.body LIKE '%صيدل%') THEN
        RAISE EXCEPTION '435: reviewed notification % body no longer matches the pharmacy predicate and no body md5 is bound - re-review before apply', v_rec.id;
      END IF;
    END IF;
  END LOOP;

  SELECT count(*) INTO v_present
    FROM public.notifications
   WHERE id = ANY (ARRAY['c81cd7d1-3564-4444-b659-a2deb4516459']::uuid[]);

  IF v_present = 0 THEN
    RAISE NOTICE '435: reviewed notification(s) already absent (clean DB or post-apply state); % candidate(s) checked, 0 unlisted', v_candidates;
    RETURN;
  END IF;

  DELETE FROM public.notifications
   WHERE id = ANY (ARRAY['c81cd7d1-3564-4444-b659-a2deb4516459']::uuid[]);
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RAISE NOTICE '435: deleted % reviewed pharmacy notification(s)', v_deleted;
END $n$;

-- Phase B deletes run in one block so every count is reported via
-- GET DIAGNOSTICS (security review: the final NOTICE must report rows
-- actually deleted, not the list length).
DO $b$
DECLARE
  v_n int;
  v_total int := 0;
BEGIN
  -- Offers of pharmacy merchants or pharmacy catalog categories.
  DELETE FROM public.offers
   WHERE merchant_id IN (SELECT id FROM public.merchants WHERE type = 'pharmacy')
      OR category_id IN (SELECT id FROM public.catalog_categories WHERE merchant_type = 'pharmacy');
  GET DIAGNOSTICS v_n = ROW_COUNT; v_total := v_total + v_n;
  RAISE NOTICE '435 Phase B: deleted % offer(s)', v_n;

  -- Products of pharmacy merchants (merchant FK cascades; explicit for
  -- the audit trail of the delete count).
  DELETE FROM public.products
   WHERE merchant_id IN (SELECT id FROM public.merchants WHERE type = 'pharmacy');
  GET DIAGNOSTICS v_n = ROW_COUNT; v_total := v_total + v_n;
  RAISE NOTICE '435 Phase B: deleted % product(s)', v_n;

  -- Pharmacy category rows (products.category is free text, not an FK).
  DELETE FROM public.catalog_categories WHERE merchant_type = 'pharmacy';
  GET DIAGNOSTICS v_n = ROW_COUNT; v_total := v_total + v_n;
  RAISE NOTICE '435 Phase B: deleted % catalog_categories row(s)', v_n;
  DELETE FROM public.categories
   WHERE lower(coalesce(name,'')) LIKE '%pharm%'
      OR lower(coalesce(name_en,'')) LIKE '%pharm%'
      OR coalesce(name_ar,'') LIKE '%صيدل%';
  GET DIAGNOSTICS v_n = ROW_COUNT; v_total := v_total + v_n;
  RAISE NOTICE '435 Phase B: deleted % categories row(s)', v_n;

  -- Pharmacy delivery pricing row.
  DELETE FROM public.delivery_pricing WHERE service_type = 'pharmacy_delivery';
  GET DIAGNOSTICS v_n = ROW_COUNT; v_total := v_total + v_n;
  RAISE NOTICE '435 Phase B: deleted % delivery_pricing row(s)', v_n;

  -- Pharmacy workspaces (431 already removed them; idempotent).
  DELETE FROM public.provider_business_profiles WHERE category_type = 'pharmacy';
  GET DIAGNOSTICS v_n = ROW_COUNT; v_total := v_total + v_n;

  -- Historical pharmacy_delivery rides (guards passed; ride_requests
  -- cascade with the ride).
  DELETE FROM public.rides WHERE service_type = 'pharmacy_delivery';
  GET DIAGNOSTICS v_n = ROW_COUNT; v_total := v_total + v_n;
  RAISE NOTICE '435 Phase B: deleted % pharmacy_delivery ride(s)', v_n;

  -- Pharmacy merchants (favorites, merchant_profiles,
  -- provider_business_profiles, pos_* rows cascade or SET NULL by FK).
  DELETE FROM public.merchants WHERE type = 'pharmacy';
  GET DIAGNOSTICS v_n = ROW_COUNT; v_total := v_total + v_n;
  RAISE NOTICE '435 Phase B: deleted % pharmacy merchant(s)', v_n;

  -- Pharmacy commission rules (entity_type/entity_key columns per the
  -- live schema; 2 live rows at review time).
  DELETE FROM public.commission_rules
   WHERE entity_key IN ('pharmacy', 'pharmacy_delivery');
  GET DIAGNOSTICS v_n = ROW_COUNT; v_total := v_total + v_n;
  RAISE NOTICE '435 Phase B: deleted % commission rule(s); PHASE B TOTAL = % row(s)', v_n, v_total;
END $b$;

-- ─── Phase C: pharmacy-only schema objects ──────────────────────────────
-- Inter-pharmacy shortage network (341 + 348). transfer_requests has an
-- FK into drug_catalog; per the real apply order 431 -> 435 -> 433 ->
-- 434, THIS file runs before 433, so dropping pharmacy_transfer_requests
-- here removes the first of the two NO-ACTION FK sides into
-- drug_catalog; 433 then drops the pos_stock_moves side and the table.
-- On a post-433 re-run everything below is already gone. All drops are
-- IF EXISTS and converge either way.

-- Existence-aware (code review #164): safe on a second run.
DO $r$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
              WHERE n.nspname = 'public' AND p.proname = 'pharmacy_import_drug') THEN
    REVOKE ALL ON FUNCTION public.pharmacy_import_drug(uuid,uuid,numeric,integer) FROM PUBLIC, anon, authenticated, postgres, service_role;
  END IF;
END $r$;
DROP FUNCTION IF EXISTS public.pharmacy_import_drug(uuid,uuid,numeric,integer);

DROP FUNCTION IF EXISTS public.pharmacy_directory(uuid);
DROP FUNCTION IF EXISTS public.pharmacy_link_create(uuid,uuid);
DROP FUNCTION IF EXISTS public.pharmacy_transfer_request(uuid,text,numeric,uuid,text);
DROP FUNCTION IF EXISTS public.pharmacy_transfer_respond(uuid,boolean,numeric);
DROP FUNCTION IF EXISTS public.pharmacy_transfer_handover(uuid,numeric);
DROP FUNCTION IF EXISTS public.pharmacy_transfer_settle(uuid,text,numeric,text);
DROP FUNCTION IF EXISTS public.pharmacy_transfer_settle_confirm(uuid,boolean);
DROP FUNCTION IF EXISTS public.pharmacy_message_send(uuid,text,uuid);

DROP TABLE IF EXISTS public.pharmacy_messages;
DROP TABLE IF EXISTS public.pharmacy_transfer_ledger;
DROP TABLE IF EXISTS public.pharmacy_transfer_requests;
DROP TABLE IF EXISTS public.pharmacy_links;

-- ─── Phase D: CHECK constraints without pharmacy ────────────────────────
-- merchants.type: 44-value list minus 'pharmacy'.
-- rides.service_type: list minus 'pharmacy_delivery'.
-- New definitions are validated against the (already purged) live rows.

ALTER TABLE public.merchants DROP CONSTRAINT merchants_type_check;
ALTER TABLE public.merchants ADD CONSTRAINT merchants_type_check
  CHECK ((type = ANY (ARRAY['food'::text, 'restaurant'::text, 'grocery'::text, 'supermarket'::text, 'electronics'::text, 'fashion'::text, 'flowers'::text, 'bakery'::text, 'general'::text, 'fruits'::text, 'meat'::text, 'seafood'::text, 'sweets'::text, 'clothing'::text, 'shoes'::text, 'mobile'::text, 'furniture'::text, 'home'::text, 'cafe'::text, 'petShop'::text, 'fitness'::text, 'gas'::text, 'carwash'::text, 'perfumes'::text, 'spices'::text, 'dairy'::text, 'accessories'::text, 'butcher'::text, 'vegetables'::text, 'service'::text, 'home_services'::text, 'plumbing'::text, 'electrical'::text, 'cleaning'::text, 'handyman'::text, 'carpentry'::text, 'ac_maintenance'::text, 'painting'::text, 'pest_control'::text, 'appliance_repair'::text, 'doctor'::text, 'clinic'::text, 'other'::text])));

ALTER TABLE public.rides DROP CONSTRAINT rides_service_type_check;
ALTER TABLE public.rides ADD CONSTRAINT rides_service_type_check
  CHECK ((service_type = ANY (ARRAY['ride'::text, 'food_delivery'::text, 'grocery_delivery'::text, 'marketplace_delivery'::text, 'courier'::text, 'package_delivery'::text, 'document_delivery'::text, 'flower_delivery'::text, 'retail_delivery'::text])));

-- ─── Post-check: nothing pharmacy-shaped may remain reachable ─────────
-- Extended per code review #166: data, categories, offers, profiles,
-- functions, tables and ACLs.
DO $g$
BEGIN
  IF EXISTS (SELECT 1 FROM public.merchants WHERE type = 'pharmacy')
     OR EXISTS (SELECT 1 FROM public.rides WHERE service_type = 'pharmacy_delivery')
     OR EXISTS (SELECT 1 FROM public.drivers WHERE service_types @> ARRAY['pharmacy']::text[])
     OR EXISTS (SELECT 1 FROM public.commission_rules WHERE entity_key IN ('pharmacy', 'pharmacy_delivery'))
     OR EXISTS (SELECT 1 FROM public.categories WHERE lower(coalesce(name,'')) LIKE '%pharm%' OR lower(coalesce(name_en,'')) LIKE '%pharm%' OR coalesce(name_ar,'') LIKE '%صيدل%')
     OR EXISTS (SELECT 1 FROM public.catalog_categories WHERE merchant_type = 'pharmacy')
     OR EXISTS (SELECT 1 FROM public.delivery_pricing WHERE service_type = 'pharmacy_delivery')
     OR EXISTS (SELECT 1 FROM public.provider_business_profiles WHERE category_type = 'pharmacy')
     OR EXISTS (SELECT 1 FROM public.users WHERE active_provider_category = 'pharmacy')
     OR EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND p.proname LIKE 'pharmacy\_%' ESCAPE '\')
     OR EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename LIKE 'pharmacy\_%' ESCAPE '\')
  THEN
    RAISE EXCEPTION '435: pharmacy residue after purge - aborting';
  END IF;
END $g$;

COMMIT;
