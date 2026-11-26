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
--   450 (THIS FILE): revokes table-level SELECT on merchants, products
--     and service_providers from anon + authenticated and replaces it
--     with the minimum column keep-lists. Closes the Finding 2
--     exposures (merchants email/owner_user_id/phone/coords to
--     anon+signed-in; products sku/barcode/stock to signed-in).
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
--   * EXCLUDED: product_modifier_groups / product_modifier_options
--     (customer checkout AND owner management read them directly; no
--     public surface exists yet - a follow-up needs a view/RPC + app
--     switch before they can be revoked) and merchant_profiles (RLS is
--     self-row only; the delivery flow reads the caller's own row).
--   * pos/ (C#) reads only via /rest/v1/rpc/* - unaffected.
--   No policy expression anywhere references the three tables by name
--   (449 re-pointed them all; re-asserted as A0 below and re-verified
--   on prod 2026-11-26), so no caller needs any column privilege for
--   policy evaluation.
--
-- A0 PRECONDITIONS (chain == prod verified 2026-11-26):
--   * 449/451 read surfaces byte-identical to the review-pinned bodies
--     (md5 over pg_get_functiondef);
--   * zero policy expressions referencing the three tables;
--   * zero pre-existing column-level grants for anon/authenticated on
--     the three tables (449 verified; re-asserted so the post-state is
--     exactly the keep-lists).
--
-- Rollback: rollback/450_public_table_select_revokes_rollback.sql
-- replays the _450_revoked_grants snapshot exactly (grantor +
-- grant-option) and removes the keep-lists.

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
END $$;

-- ─── grant snapshot (exact rollback source) ──────────────────────────
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

-- ─── revokes + keep-lists ────────────────────────────────────────────
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
  -- column posture is EXACTLY the keep-lists (attacl scan)
  ASSERT NOT EXISTS (
    SELECT 1 FROM pg_attribute a
      JOIN pg_class c ON c.oid = a.attrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
      CROSS JOIN LATERAL aclexplode(a.attacl) x
     WHERE n.nspname = 'public'
       AND c.relname IN ('merchants','products','service_providers')
       AND (x.grantee IN (0, 'anon'::regrole)
            OR NOT (c.relname IN ('merchants','products')
                    AND a.attname = 'id'
                    AND x.grantee = 'authenticated'::regrole
                    AND x.privilege_type = 'SELECT'))),
    '450: column grant beyond the keep-lists';
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
  -- the snapshot captured this apply's revokes
  ASSERT (SELECT count(*) FROM public._450_revoked_grants) >= 1,
    '450: grant snapshot is empty';
END $$;

COMMIT;
