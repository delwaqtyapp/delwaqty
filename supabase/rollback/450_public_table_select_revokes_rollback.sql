-- Rollback for 450_public_table_select_revokes.sql (phase 2b, breaking).
-- Restores the pre-450 posture:
--   * replays ONLY the SELECT grants 450 snapshotted before revoking
--     (_450_revoked_grants; exact inverse incl. grantor/grant-option);
--   * removes the keep-list column grants (merchants.id, products.id
--     for authenticated);
--   * drops the snapshot table.
-- DOES NOT touch data, policies, functions or views. Apply manually
-- with psql; NOT part of the chain.
--
-- STRICT: any restore failure, any snapshot row missing afterwards, or
-- a keep-list column still present afterwards aborts the whole
-- transaction and KEEPS the snapshot table for diagnosis/retry.

BEGIN;

-- A0: this rollback only runs on the 450 post-state (keep-lists present,
-- no table-level SELECT on the three tables)
DO $$
BEGIN
  ASSERT (SELECT count(*) FROM pg_attribute a
           JOIN pg_class c ON c.oid = a.attrelid
           JOIN pg_namespace n ON n.oid = c.relnamespace
           CROSS JOIN LATERAL aclexplode(a.attacl) x
          WHERE n.nspname = 'public'
            AND c.relname IN ('merchants','products')
            AND a.attname = 'id'
            AND x.grantee = 'authenticated'::regrole
            AND x.privilege_type = 'SELECT') = 2,
    '450 rollback A0: keep-list grants not present (not the 450 post-state?)';
  ASSERT NOT EXISTS (
    SELECT 1 FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      CROSS JOIN LATERAL aclexplode(c.relacl) x
      JOIN pg_roles g ON g.oid = x.grantee
     WHERE n.nspname = 'public'
       AND c.relname IN ('merchants','products','service_providers')
       AND g.rolname IN ('anon','authenticated')
       AND x.privilege_type = 'SELECT'),
    '450 rollback A0: table-level SELECT already present (not the 450 post-state?)';
END $$;

-- remove the keep-lists first (the replay below restores the exact
-- pre-450 table-level grants)
REVOKE SELECT (id) ON public.merchants FROM authenticated;
REVOKE SELECT (id) ON public.products FROM authenticated;

-- exact restore: replay ONLY the rows 450 snapshotted before revoking
-- (table/grantee/privilege/grantor/grantable).
DO $$
DECLARE
  r record;
  v_me text := current_user;
  v_missing int;
BEGIN
  IF to_regclass('public._450_revoked_grants') IS NULL THEN
    RAISE WARNING '450 rollback: snapshot table _450_revoked_grants absent; nothing to restore';
    RETURN;
  END IF;
  FOR r IN SELECT * FROM public._450_revoked_grants LOOP
    -- already exactly present (never actually revoked, or restored
    -- earlier): grantor AND grant-option must both match
    -- pg_class.relacl + aclexplode, NOT information_schema (which hides
    -- rows not involving a currently enabled role)
    IF EXISTS (SELECT 1 FROM pg_class c
                JOIN pg_namespace n ON n.oid = c.relnamespace
                CROSS JOIN LATERAL aclexplode(c.relacl) x
                JOIN pg_roles ge ON ge.oid = x.grantee
                JOIN pg_roles go ON go.oid = x.grantor
                WHERE n.nspname='public' AND c.relname=r.tbl
                  AND ge.rolname=r.grantee AND x.privilege_type=r.privilege
                  AND go.rolname=r.grantor
                  AND x.is_grantable = r.grantable) THEN
      CONTINUE;
    END IF;
    BEGIN
      IF r.grantor <> v_me THEN
        EXECUTE format('SET ROLE %I', r.grantor);
      END IF;
      -- a plain GRANT restores the privilege; WITH GRANT OPTION also
      -- restores a lost grant option on an existing privilege
      IF r.grantable THEN
        EXECUTE format('GRANT %s ON public.%I TO %I WITH GRANT OPTION', r.privilege, r.tbl, r.grantee);
      ELSE
        EXECUTE format('GRANT %s ON public.%I TO %I', r.privilege, r.tbl, r.grantee);
      END IF;
      IF r.grantor <> v_me THEN
        RESET ROLE;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      RESET ROLE;
      RAISE EXCEPTION '450 rollback: failed to restore % on public.% to % (grantor %): % / % - transaction aborted, snapshot kept',
        r.privilege, r.tbl, r.grantee, r.grantor, SQLSTATE, SQLERRM;
    END;
  END LOOP;
  -- full exact postcondition: every snapshot row must now exist with its
  -- original grantor and grant-option
  SELECT count(*) INTO v_missing
    FROM public._450_revoked_grants g
   WHERE NOT EXISTS (SELECT 1 FROM pg_class c
                      JOIN pg_namespace n ON n.oid = c.relnamespace
                      CROSS JOIN LATERAL aclexplode(c.relacl) x
                      JOIN pg_roles ge ON ge.oid = x.grantee
                      JOIN pg_roles go ON go.oid = x.grantor
                      WHERE n.nspname='public' AND c.relname=g.tbl
                        AND ge.rolname=g.grantee AND x.privilege_type=g.privilege
                        AND go.rolname=g.grantor
                        AND x.is_grantable = g.grantable);
  IF v_missing > 0 THEN
    RAISE EXCEPTION '450 rollback: % snapshot rows not restored exactly - transaction aborted, snapshot kept', v_missing;
  END IF;
  -- keep-lists must be gone
  IF EXISTS (SELECT 1 FROM pg_attribute a
              JOIN pg_class c ON c.oid = a.attrelid
              JOIN pg_namespace n ON n.oid = c.relnamespace
              CROSS JOIN LATERAL aclexplode(a.attacl) x
             WHERE n.nspname='public'
               AND c.relname IN ('merchants','products','service_providers')) THEN
    RAISE EXCEPTION '450 rollback: a column grant survived - transaction aborted, snapshot kept';
  END IF;
END $$;
-- reached only when the postconditions passed
DROP TABLE IF EXISTS public._450_revoked_grants;

COMMIT;
