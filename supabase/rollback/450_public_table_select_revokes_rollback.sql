-- Rollback for 450_public_table_select_revokes.sql (phase 2b, breaking).
-- Restores the pre-450 posture:
--   * restores the deliveries view to its pre-450 definition (md5
--     228af4e1fa465baf165751e3f84fb7a3, verified after restore) and
--     drops _delivery_merchant_labels;
--   * replays ONLY the SELECT grants 450 snapshotted before revoking
--     (_450_revoked_grants; exact inverse incl. grantor/grant-option);
--   * removes the keep-list column grants (merchants.id, products.id
--     for authenticated);
--   * drops the snapshot table.
-- DOES NOT touch data or policies. Apply manually with psql; NOT part
-- of the chain.
--
-- STRICT: the A0 block runs BEFORE any mutation and ABORTS unless the
-- snapshot table exists, is non-empty and has exactly the expected
-- shape (SELECT grants on merchants/products/service_providers for
-- anon/authenticated only). A missing or malformed snapshot is a hard
-- failure, never a partial rollback. Any restore failure, any snapshot
-- row missing afterwards, or a surviving keep-list/view-drift aborts
-- the whole transaction and KEEPS the snapshot for diagnosis/retry.

BEGIN;

-- A0 FIRST, before any mutation: this rollback only runs on the exact
-- 450 post-state with an intact snapshot
DO $$
DECLARE
  v_bad int;
BEGIN
  IF to_regclass('public._450_revoked_grants') IS NULL THEN
    RAISE EXCEPTION '450 rollback A0: snapshot table _450_revoked_grants absent - refusing to run (would be a destructive partial rollback)';
  END IF;
  IF (SELECT count(*) FROM public._450_revoked_grants) = 0 THEN
    RAISE EXCEPTION '450 rollback A0: snapshot table is empty - refusing to run';
  END IF;
  SELECT count(*) INTO v_bad
    FROM public._450_revoked_grants
   WHERE privilege <> 'SELECT'
      OR tbl NOT IN ('merchants','products','service_providers')
      OR grantee NOT IN ('anon','authenticated');
  IF v_bad > 0 THEN
    RAISE EXCEPTION '450 rollback A0: % snapshot rows outside the expected shape - refusing to run', v_bad;
  END IF;
  IF EXISTS (SELECT 1 FROM public._450_revoked_grants
             WHERE tbl = 'merchants' AND grantee = 'anon')
     AND NOT EXISTS (SELECT 1 FROM public._450_revoked_grants
                     WHERE tbl = 'merchants' AND grantee = 'authenticated') THEN
    RAISE EXCEPTION '450 rollback A0: snapshot has anon but not authenticated merchants SELECT - implausible shape, refusing';
  END IF;
  -- the 450 post-state: keep-lists present, no table-level SELECT, the
  -- rebuilt deliveries view + labels subview in place
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
  ASSERT to_regclass('public._delivery_merchant_labels') IS NOT NULL,
    '450 rollback A0: _delivery_merchant_labels missing (not the 450 post-state?)';
END $$;

-- 1. deliveries view back to its exact pre-450 definition (216),
--    joining the merchants base table as the caller again
DROP VIEW public.deliveries;
CREATE VIEW public.deliveries
WITH (security_invoker = true) AS
 SELECT r.id,
    r.order_id,
    r.driver_id,
    COALESCE(m.name, ''::text) AS merchant_name,
    COALESCE(NULLIF(r.pickup_address, ''::text), COALESCE(m.address, ''::text)) AS merchant_address,
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
     LEFT JOIN merchants m ON ((m.id = r.merchant_id)))
     LEFT JOIN users u ON ((u.id = r.rider_id)))
  WHERE (r.ride_type = 'delivery'::text) OR (r.order_id IS NOT NULL);

REVOKE ALL ON public.deliveries FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.deliveries TO authenticated;
GRANT UPDATE ON public.deliveries TO authenticated;

CREATE TRIGGER deliveries_view_update INSTEAD OF UPDATE ON public.deliveries
  FOR EACH ROW EXECUTE FUNCTION deliveries_view_update();

DROP VIEW public._delivery_merchant_labels;

DO $$
BEGIN
  ASSERT md5(pg_get_viewdef('public.deliveries'::regclass))
         = '228af4e1fa465baf165751e3f84fb7a3',
    '450 rollback: deliveries view did not restore to the exact pre-image';
END $$;

-- 2. remove the keep-lists (the replay below restores the exact pre-450
--    table-level grants)
REVOKE SELECT (id) ON public.merchants FROM authenticated;
REVOKE SELECT (id) ON public.products FROM authenticated;

-- 3. exact restore: replay ONLY the rows 450 snapshotted before
--    revoking (table/grantee/privilege/grantor/grantable).
DO $$
DECLARE
  r record;
  v_me text := current_user;
  v_missing int;
BEGIN
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
  -- full exact postcondition: every snapshot row must now exist with
  -- its original grantor and grant-option
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
