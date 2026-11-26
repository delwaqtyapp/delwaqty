-- 450: DB hardening phase 2b — public table SELECT revokes, BREAKING
-- half of the staged 448/449/450 plan.
--
--   448 (applied): staff_settings move, anon DML sweep, provider view.
--   449 (applied): public views + owner/staff/admin RPCs + definer
--     helpers, every cross-table policy subquery re-pointed, guards and
--     trims. Base-table SELECT left as-is.
--   451 (applied): owner-surface follow-ups for the #80 app switch
--     (profile overload, exact counts, bounded by-ids fetch, scoped
--     admin merchant count).
--   450 (THIS FILE):
--     1. Rebuilds the security_invoker `deliveries` view so its merchant
--        name/address come from a postgres-owned security_barrier
--        subview restricted to the caller's visible delivery rows
--        (mirrors the rides SELECT policies) instead of joining the
--        merchants base table as the caller. Without this, the revokes
--        below would make EVERY deliveries read fail with 42501
--        (driver/customer/owner/admin) - the driver app reads the view
--        (supabase_driver_data_source.dart).
--     2. Revokes table-level SELECT on merchants, products and
--        service_providers from anon + authenticated, replaced by the
--        minimum column keep-lists.
--     Exposure closed: merchants email/owner_user_id and products
--     sku/barcode/stock to anon+signed-in. merchants name/address/
--     phone/coords REMAIN PUBLIC via merchants_public - that is the
--     unchanged product decision (customer browsing needs them); this
--     file does NOT make them private.
--
-- OPERATIONAL GATE (HELD): applies to prod ONLY after a build carrying
-- the #80 app switch (view/RPC reads) has shipped. Every direct read
-- left in the app at master was enumerated on 2026-11-26
-- (lib/, supabase/functions, pos/):
--   * merchants: admin_repository.updateMerchantStatus UPDATE ... WHERE
--     id; merchant-staff-admin edge function list_staff visibility check
--     caller.from("merchants").select("id").eq("id", ...) -> keep
--     SELECT (id) for authenticated.
--   * products: owner createProduct INSERT (no read), updateProduct /
--     deleteProduct / stock-sync UPDATE/DELETE ... WHERE id -> keep
--     SELECT (id) for authenticated. (Postgres requires SELECT on the
--     WHERE columns of UPDATE/DELETE.)
--   * service_providers: no direct app reads remain (browsing uses the
--     448 view service_providers_with_effective_pricing; capability
--     uses get_my_provider_profile). No keep-list.
--   * pos/ (C#) reads only via /rest/v1/rpc/* (cashier_* and
--     drug_catalog_search, all SECURITY DEFINER) - unaffected.
--   OPEN follow-ups (NOT closed by this file, tracked separately):
--   * product_modifier_groups / product_modifier_options: customer
--     checkout AND owner management read them directly; no public
--     surface exists yet - needs a view/RPC + app switch before revoke.
--   * merchant_profiles: RLS is self-row only; the delivery flow reads
--     the caller's own row.
--   Caller-run sweep (prod 2026-11-26, pg_depend over all views +
--   prosecdef/prosrc over functions): the ONLY security_invoker or
--   caller-run object touching the three tables is the deliveries view
--   (fixed in section 1). merchant_storefront, merchants_public,
--   products_public, service_providers_with_effective_pricing are
--   postgres-owned and run as the owner. driver_directory (the other
--   security_invoker view) does not reference the three tables. No
--   policy expression references them by name (449 re-pointed them
--   all), so no caller needs any column privilege for policy
--   evaluation.
--
-- A0 PRECONDITIONS (chain == prod verified 2026-11-26):
--   * 449/451 read surfaces byte-identical to the review-pinned bodies
--     (md5 over pg_get_functiondef);
--   * deliveries view pre-image md5 = 228af4e1fa465baf165751e3f84fb7a3
--     (pg_get_viewdef);
--   * zero policy expressions referencing the three tables;
--   * zero pre-existing column-level grants for anon/authenticated on
--     the three tables;
--   * no PUBLIC (grantee 0) SELECT on the three tables, and no SELECT
--     granted to any role anon/authenticated inherit from.
--
-- Rollback: rollback/450_public_table_select_revokes_rollback.sql
-- restores the deliveries pre-image, replays the _450_revoked_grants
-- snapshot exactly (grantor + grant-option) and removes the keep-lists.

BEGIN;

-- ─── A0 preconditions ────────────────────────────────────────────────
DO $$
BEGIN
  ASSERT md5(pg_get_functiondef('public.get_my_merchant_profile()'::regprocedure))
         = '93a34d4eba42dddd85c5af26b1c5c8bb', 'A0: 449 zero-arg profile drifted';
  ASSERT md5(pg_get_functiondef('public.get_my_merchant_profile(uuid)'::regprocedure))
         = '315c03a0332a92a943ed9ced9c197307', 'A0: 451 profile overload drifted';
  ASSERT md5(pg_get_functiondef('public.get_my_products_count(uuid)'::regprocedure))
         = 'b1f12c83bf2c990b2c3f16d396effe68', 'A0: 451 products count drifted';
  ASSERT md5(pg_get_functiondef('public.get_my_products_by_ids(uuid,uuid[])'::regprocedure))
         = '1e65a0bbe0ce44e2d4448fc1625aa948', 'A0: 451 products by_ids drifted';
  ASSERT md5(pg_get_functiondef('public.admin_get_merchants_count()'::regprocedure))
         = '82547e1b21fe1212f9af36d03a7a630a', 'A0: 451 admin count drifted';
  ASSERT md5(pg_get_viewdef('public.deliveries'::regclass))
         = '228af4e1fa465baf165751e3f84fb7a3', 'A0: deliveries view pre-image drifted';
  ASSERT to_regclass('public._delivery_merchant_labels') IS NULL,
    'A0: _delivery_merchant_labels already exists';
  ASSERT NOT EXISTS (
    SELECT 1 FROM pg_policy p
      JOIN pg_class c ON c.oid = p.polrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public'
       AND (pg_get_expr(p.polqual, p.polrelid)
              ~* '(^|[^_a-z])(merchants|products|service_providers)([^_a-z]|$)'
            OR coalesce(pg_get_expr(p.polwithcheck, p.polrelid), '')
              ~* '(^|[^_a-z])(merchants|products|service_providers)([^_a-z]|$)')),
    'A0: a policy expression still references a base table by name';
  -- column-level grants live in pg_attribute.attacl (not relacl)
  ASSERT NOT EXISTS (
    SELECT 1 FROM pg_attribute a
      JOIN pg_class c ON c.oid = a.attrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
      CROSS JOIN LATERAL aclexplode(a.attacl) x
     WHERE n.nspname = 'public'
       AND c.relname IN ('merchants','products','service_providers')
       AND x.grantee IN (0, 'anon'::regrole, 'authenticated'::regrole)),
    'A0: unexpected pre-existing column grant on a 450 table';
  -- no PUBLIC SELECT on the three tables
  ASSERT NOT EXISTS (
    SELECT 1 FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      CROSS JOIN LATERAL aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) x
     WHERE n.nspname = 'public'
       AND c.relname IN ('merchants','products','service_providers')
       AND x.grantee = 0 AND x.privilege_type = 'SELECT'),
    'A0: PUBLIC holds SELECT on a 450 table';
  -- no SELECT via any role anon/authenticated inherit from (recursive)
  ASSERT NOT EXISTS (
    WITH RECURSIVE ancestors AS (
      SELECT m.roleid FROM pg_auth_members m
       WHERE m.member IN ('anon'::regrole, 'authenticated'::regrole)
      UNION
      SELECT m.roleid FROM pg_auth_members m
       JOIN ancestors a ON m.member = a.roleid
    )
    SELECT 1 FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      CROSS JOIN LATERAL aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) x
     WHERE n.nspname = 'public'
       AND c.relname IN ('merchants','products','service_providers')
       AND x.privilege_type = 'SELECT'
       AND x.grantee IN (SELECT roleid FROM ancestors)),
    'A0: an ancestor role of anon/authenticated holds SELECT on a 450 table';
END $$;

-- ─── 1. deliveries view: merchant label off the caller path ──────────
-- Caller-row-restricted, postgres-owned, security_barrier. The IN
-- predicate MIRRORS the rides SELECT policies (rider, assigned driver,
-- requested driver, country admin) - keep it in sync with them; the 450
-- battery pins identical per-persona deliveries output pre/post.
-- Owners and regional admins hold no rides read policy, so they see no
-- deliveries rows at all, exactly as before.
CREATE VIEW public._delivery_merchant_labels
WITH (security_barrier = true) AS
SELECT m.id, m.name, m.address
FROM public.merchants m
WHERE m.id IN (
  SELECT r.merchant_id
    FROM public.rides r
   WHERE r.merchant_id IS NOT NULL
     AND (r.ride_type = 'delivery' OR r.order_id IS NOT NULL)
     AND (r.rider_id = auth.uid()
          OR r.driver_id IN (SELECT d.id FROM public.drivers d
                              WHERE d.user_id = auth.uid())
          OR r.id IN (SELECT rr.ride_id FROM public.ride_requests rr
                       WHERE rr.driver_id IN (SELECT d2.id FROM public.drivers d2
                                               WHERE d2.user_id = auth.uid()))
          OR public._is_country_admin_uid(auth.uid()))
);
COMMENT ON VIEW public._delivery_merchant_labels IS
  '450: merchant name/address for the deliveries view, restricted to '
  'merchants of delivery rides the CALLER may see (mirrors the rides '
  'SELECT policies). Runs as the owner so the deliveries view needs no '
  'merchants column grant.';
REVOKE ALL ON public._delivery_merchant_labels FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public._delivery_merchant_labels TO authenticated;

DROP VIEW public.deliveries;
CREATE VIEW public.deliveries
WITH (security_invoker = true) AS
 SELECT r.id,
    r.order_id,
    r.driver_id,
    COALESCE(ml.name, ''::text) AS merchant_name,
    COALESCE(NULLIF(r.pickup_address, ''::text), COALESCE(ml.address, ''::text)) AS merchant_address,
    COALESCE(r.recipient_name, u.full_name, ''::text) AS customer_name,
    COALESCE(r.dropoff_address, ''::text) AS delivery_address,
    r.dropoff_latitude AS customer_latitude,
    r.dropoff_longitude AS customer_longitude,
        CASE r.status
            WHEN 'searching'::text THEN 'pending'::text
            WHEN 'matched'::text THEN 'accepted'::text
            WHEN 'arrived'::text THEN 'arrived'::text
            WHEN 'inTrip'::text THEN 'picked_up'::text
            WHEN 'completed'::text THEN 'delivered'::text
            WHEN 'cancelled'::text THEN 'cancelled'::text
            ELSE r.status
        END AS status,
    r.fare AS delivery_fee,
    COALESCE(r.delivery_notes, r.dropoff_notes) AS notes,
    r.created_at,
    r.accepted_at,
    r.picked_up_at,
    r.delivered_at,
    COALESCE(r.recipient_phone, u.phone, ''::text) AS customer_phone
   FROM ((rides r
     LEFT JOIN _delivery_merchant_labels ml ON ((ml.id = r.merchant_id)))
     LEFT JOIN users u ON ((u.id = r.rider_id)))
  WHERE (r.ride_type = 'delivery'::text) OR (r.order_id IS NOT NULL);

-- a recreated view picks up default-privilege residue (REFERENCES/
-- TRIGGER for authenticated): strip everything, then re-grant exactly
REVOKE ALL ON public.deliveries FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.deliveries TO authenticated;
GRANT UPDATE ON public.deliveries TO authenticated;

CREATE TRIGGER deliveries_view_update INSTEAD OF UPDATE ON public.deliveries
  FOR EACH ROW EXECUTE FUNCTION deliveries_view_update();

-- ─── 2. grant snapshot (exact rollback source) ───────────────────────
-- Same contract as 449: capture first, replay only these rows.
CREATE TABLE public._450_revoked_grants(
  tbl text NOT NULL,
  grantee text NOT NULL,
  privilege text NOT NULL,
  grantor text NOT NULL,
  grantable boolean NOT NULL
);
REVOKE ALL ON public._450_revoked_grants FROM PUBLIC, anon, authenticated, service_role;
ALTER TABLE public._450_revoked_grants ENABLE ROW LEVEL SECURITY;
COMMENT ON TABLE public._450_revoked_grants IS
  '450: pre-apply capture of every SELECT grant this migration revokes. '
  'Read only by the 450 rollback (replays these rows, then drops the table).';
-- pg_class.relacl + aclexplode, NOT information_schema (which hides rows
-- from a non-superuser applier)
INSERT INTO public._450_revoked_grants
SELECT c.relname, g.rolname, x.privilege_type, go.rolname, x.is_grantable
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  CROSS JOIN LATERAL aclexplode(c.relacl) x
  JOIN pg_roles g ON g.oid = x.grantee
  JOIN pg_roles go ON go.oid = x.grantor
 WHERE n.nspname = 'public'
   AND c.relname IN ('merchants','products','service_providers')
   AND g.rolname IN ('anon','authenticated')
   AND x.privilege_type = 'SELECT';

-- ─── 3. revokes + keep-lists ─────────────────────────────────────────
REVOKE SELECT ON public.merchants FROM anon, authenticated;
REVOKE SELECT ON public.products FROM anon, authenticated;
REVOKE SELECT ON public.service_providers FROM anon, authenticated;
-- keep-list: the only direct base-table reads left (see header). Anon
-- gets NOTHING: guests browse via the public views only.
GRANT SELECT (id) ON public.merchants TO authenticated;
GRANT SELECT (id) ON public.products TO authenticated;

-- ─── postchecks ──────────────────────────────────────────────────────
DO $$
BEGIN
  -- table-level SELECT gone (relacl scan; has_table_privilege would stay
  -- true because of the keep-list column grants)
  ASSERT NOT EXISTS (
    SELECT 1 FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      CROSS JOIN LATERAL aclexplode(c.relacl) x
      JOIN pg_roles g ON g.oid = x.grantee
     WHERE n.nspname = 'public'
       AND c.relname IN ('merchants','products','service_providers')
       AND g.rolname IN ('anon','authenticated')
       AND x.privilege_type = 'SELECT'),
    '450: table-level SELECT left';
  -- EFFECTIVE access, PUBLIC and inherited roles included: every
  -- non-keep column is unreadable by anon and by authenticated
  ASSERT NOT EXISTS (
    SELECT 1 FROM pg_attribute a
      JOIN pg_class c ON c.oid = a.attrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public'
       AND c.relname IN ('merchants','products','service_providers')
       AND a.attnum > 0 AND NOT a.attisdropped
       AND (has_column_privilege('anon', c.oid, a.attnum, 'SELECT')
            OR (has_column_privilege('authenticated', c.oid, a.attnum, 'SELECT')
                AND NOT (c.relname IN ('merchants','products')
                         AND a.attname = 'id')))),
    '450: a non-keep column is still readable (direct, PUBLIC or inherited)';
  -- exact keep access: merchants.id + products.id for authenticated only
  ASSERT (SELECT count(*) FROM pg_attribute a
           JOIN pg_class c ON c.oid = a.attrelid
           JOIN pg_namespace n ON n.oid = c.relnamespace
           CROSS JOIN LATERAL aclexplode(a.attacl) x
          WHERE n.nspname = 'public'
            AND c.relname IN ('merchants','products')
            AND a.attname = 'id'
            AND x.grantee = 'authenticated'::regrole
            AND x.privilege_type = 'SELECT') = 2,
    '450: a keep-list grant is missing';
  ASSERT NOT has_column_privilege('anon', 'public.merchants', 'id', 'SELECT')
         AND NOT has_column_privilege('anon', 'public.products', 'id', 'SELECT'),
    '450: anon holds a keep-list column';
  -- the deliveries view no longer references the merchants base table
  ASSERT NOT EXISTS (
    SELECT 1 FROM pg_depend d
      JOIN pg_rewrite rw ON rw.oid = d.objid
      JOIN pg_class v ON v.oid = rw.ev_class
      JOIN pg_namespace vn ON vn.oid = v.relnamespace
     WHERE vn.nspname = 'public' AND v.relname = 'deliveries'
       AND d.refclassid = 'pg_class'::regclass
       AND d.refobjid = 'public.merchants'::regclass),
    '450: deliveries still reads the merchants base table';
  -- the deliveries view kept its exact grant posture (no residue)
  ASSERT NOT EXISTS (
    SELECT 1 FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      CROSS JOIN LATERAL aclexplode(c.relacl) x
      JOIN pg_roles g ON g.oid = x.grantee
     WHERE n.nspname = 'public' AND c.relname = 'deliveries'
       AND g.rolname IN ('anon','authenticated')
       AND x.privilege_type NOT IN ('SELECT','UPDATE')),
    '450: deliveries view grant residue';
  ASSERT NOT EXISTS (
    SELECT 1 FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      CROSS JOIN LATERAL aclexplode(c.relacl) x
     WHERE n.nspname = 'public' AND c.relname = 'deliveries'
       AND x.grantee = 0),
    '450: deliveries view PUBLIC grant';
  -- the snapshot captured this apply's revokes
  ASSERT (SELECT count(*) FROM public._450_revoked_grants) >= 1,
    '450: grant snapshot is empty';
END $$;

COMMIT;
