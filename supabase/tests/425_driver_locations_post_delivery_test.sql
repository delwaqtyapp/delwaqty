-- 425 v3 actual-role staging run (transaction-wrapped, everything rolled back).
-- Section A: guard behavior. The guard block below is a VERBATIM copy of the
--   guard in supabase/migrations/425_driver_locations_post_delivery_privacy.sql.
--   Proves: no-op on exact target; abort-without-mutation on a drifted
--   predicate (extra AND restriction; changed admin branch; RESTRICTIVE
--   variant of the same predicate); apply on exact pre-state.
-- Section B: RLS matrix with real roles.
--   Customer + merchant: readable while delivering, unreadable after
--   delivered and after cancelled. Driver self, owner and permissioned
--   admin: readable while delivering and after delivered. Stranger and
--   non-permissioned admin: never readable.
BEGIN;

DO $t$
DECLARE
  v_msg    text;
  v_before text;
  v_after  text;
  v_perm   boolean;
  c_pre    constant text := $q$((driver_id IN ( SELECT drivers.id
   FROM drivers
  WHERE (drivers.user_id = auth.uid()))) OR _is_owner_uid(auth.uid()) OR admin_has_permission('DELIVERY_LOCATION_VIEW'::text, NULL::uuid) OR (EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.driver_id = driver_locations.driver_id) AND (o.dispatch_status = ANY (ARRAY['ASSIGNED'::text, 'ACCEPTED'::text])) AND ((o.user_id = auth.uid()) OR (o.merchant_id IN ( SELECT merchants.id
           FROM merchants
          WHERE (merchants.owner_user_id = auth.uid()))))))))$q$;
  c_target constant text := $q$((driver_id IN ( SELECT drivers.id
   FROM drivers
  WHERE (drivers.user_id = auth.uid()))) OR _is_owner_uid(auth.uid()) OR admin_has_permission('DELIVERY_LOCATION_VIEW'::text, NULL::uuid) OR (EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.driver_id = driver_locations.driver_id) AND (o.dispatch_status = ANY (ARRAY['ASSIGNED'::text, 'ACCEPTED'::text])) AND (o.status <> ALL (ARRAY['delivered'::text, 'cancelled'::text])) AND ((o.user_id = auth.uid()) OR (o.merchant_id IN ( SELECT merchants.id
           FROM merchants
          WHERE (merchants.owner_user_id = auth.uid()))))))))$q$;
BEGIN
  -- A0: staging sits at the exact target state (425 v1 applied it)
  SELECT pg_get_expr(polqual, polrelid) INTO v_before
    FROM pg_policy p JOIN pg_class c ON c.oid = p.polrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname='public' AND c.relname='driver_locations' AND p.polname='driver_locations_select';
  ASSERT v_before = c_target, 'A0: staging policy not at expected target state';

  -- A1: no-op path - guard accepts the exact target state, no exception, no change
  v_msg := NULL;
  BEGIN
DECLARE
  v_qual       text;
  v_cmd        "char";
  v_roles      oid[];
  v_permissive boolean;
  c_pre    constant text := $q$((driver_id IN ( SELECT drivers.id
   FROM drivers
  WHERE (drivers.user_id = auth.uid()))) OR _is_owner_uid(auth.uid()) OR admin_has_permission('DELIVERY_LOCATION_VIEW'::text, NULL::uuid) OR (EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.driver_id = driver_locations.driver_id) AND (o.dispatch_status = ANY (ARRAY['ASSIGNED'::text, 'ACCEPTED'::text])) AND ((o.user_id = auth.uid()) OR (o.merchant_id IN ( SELECT merchants.id
           FROM merchants
          WHERE (merchants.owner_user_id = auth.uid()))))))))$q$;
  c_target constant text := $q$((driver_id IN ( SELECT drivers.id
   FROM drivers
  WHERE (drivers.user_id = auth.uid()))) OR _is_owner_uid(auth.uid()) OR admin_has_permission('DELIVERY_LOCATION_VIEW'::text, NULL::uuid) OR (EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.driver_id = driver_locations.driver_id) AND (o.dispatch_status = ANY (ARRAY['ASSIGNED'::text, 'ACCEPTED'::text])) AND (o.status <> ALL (ARRAY['delivered'::text, 'cancelled'::text])) AND ((o.user_id = auth.uid()) OR (o.merchant_id IN ( SELECT merchants.id
           FROM merchants
          WHERE (merchants.owner_user_id = auth.uid()))))))))$q$;
BEGIN
  SELECT pg_get_expr(p.polqual, p.polrelid), p.polcmd, p.polroles, p.polpermissive
    INTO v_qual, v_cmd, v_roles, v_permissive
    FROM pg_policy p
    JOIN pg_class c ON c.oid = p.polrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public'
     AND c.relname = 'driver_locations'
     AND p.polname = 'driver_locations_select';

  IF NOT FOUND THEN
    RAISE EXCEPTION '425: driver_locations_select policy missing - aborting';
  END IF;

  IF v_permissive AND v_cmd = 'r' AND v_roles = '{0}'::oid[] AND v_qual = c_target THEN
    RAISE NOTICE '425: driver_locations_select already at target state - no-op';
  ELSIF (NOT v_permissive) OR v_cmd <> 'r' OR v_roles <> '{0}'::oid[] OR v_qual IS DISTINCT FROM c_pre THEN
    RAISE EXCEPTION '425: driver_locations_select drifted from expected pre-state - aborting WITHOUT mutation (permissive=%, cmd=%, roles=%, qual=%)', v_permissive, v_cmd, v_roles, v_qual;
  ELSE
    EXECUTE $ddl$DROP POLICY driver_locations_select ON public.driver_locations$ddl$;
    EXECUTE $ddl$CREATE POLICY driver_locations_select ON public.driver_locations AS PERMISSIVE FOR SELECT TO public USING (((driver_id IN ( SELECT drivers.id
   FROM drivers
  WHERE (drivers.user_id = auth.uid()))) OR _is_owner_uid(auth.uid()) OR admin_has_permission('DELIVERY_LOCATION_VIEW'::text, NULL::uuid) OR (EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.driver_id = driver_locations.driver_id) AND (o.dispatch_status = ANY (ARRAY['ASSIGNED'::text, 'ACCEPTED'::text])) AND (o.status <> ALL (ARRAY['delivered'::text, 'cancelled'::text])) AND ((o.user_id = auth.uid()) OR (o.merchant_id IN ( SELECT merchants.id
           FROM merchants
          WHERE (merchants.owner_user_id = auth.uid())))))))))$ddl$;
  END IF;
END;
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_msg = MESSAGE_TEXT;
  END;
  ASSERT v_msg IS NULL, 'A1: guard raised on target state: ' || coalesce(v_msg, '');
  SELECT pg_get_expr(polqual, polrelid) INTO v_after
    FROM pg_policy p JOIN pg_class c ON c.oid = p.polrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname='public' AND c.relname='driver_locations' AND p.polname='driver_locations_select';
  ASSERT v_after = c_target, 'A1: no-op path changed the policy';

  -- A2: drift - extra AND restriction, still contains ASSIGNED/ACCEPTED. Must abort, policy untouched.
  EXECUTE 'DROP POLICY driver_locations_select ON public.driver_locations';
  EXECUTE $x$CREATE POLICY driver_locations_select ON public.driver_locations AS PERMISSIVE FOR SELECT TO public USING (((driver_id IN ( SELECT drivers.id
   FROM drivers
  WHERE (drivers.user_id = auth.uid()))) OR _is_owner_uid(auth.uid()) OR admin_has_permission('DELIVERY_LOCATION_VIEW'::text, NULL::uuid) OR (EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.driver_id = driver_locations.driver_id) AND (o.dispatch_status = ANY (ARRAY['ASSIGNED'::text, 'ACCEPTED'::text])) AND (o.status <> ALL (ARRAY['refunded'::text])) AND ((o.user_id = auth.uid()) OR (o.merchant_id IN ( SELECT merchants.id
           FROM merchants
          WHERE (merchants.owner_user_id = auth.uid())))))))))$x$;
  SELECT pg_get_expr(polqual, polrelid) INTO v_before
    FROM pg_policy p JOIN pg_class c ON c.oid = p.polrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname='public' AND c.relname='driver_locations' AND p.polname='driver_locations_select';
  v_msg := NULL;
  BEGIN
DECLARE
  v_qual       text;
  v_cmd        "char";
  v_roles      oid[];
  v_permissive boolean;
  c_pre    constant text := $q$((driver_id IN ( SELECT drivers.id
   FROM drivers
  WHERE (drivers.user_id = auth.uid()))) OR _is_owner_uid(auth.uid()) OR admin_has_permission('DELIVERY_LOCATION_VIEW'::text, NULL::uuid) OR (EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.driver_id = driver_locations.driver_id) AND (o.dispatch_status = ANY (ARRAY['ASSIGNED'::text, 'ACCEPTED'::text])) AND ((o.user_id = auth.uid()) OR (o.merchant_id IN ( SELECT merchants.id
           FROM merchants
          WHERE (merchants.owner_user_id = auth.uid()))))))))$q$;
  c_target constant text := $q$((driver_id IN ( SELECT drivers.id
   FROM drivers
  WHERE (drivers.user_id = auth.uid()))) OR _is_owner_uid(auth.uid()) OR admin_has_permission('DELIVERY_LOCATION_VIEW'::text, NULL::uuid) OR (EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.driver_id = driver_locations.driver_id) AND (o.dispatch_status = ANY (ARRAY['ASSIGNED'::text, 'ACCEPTED'::text])) AND (o.status <> ALL (ARRAY['delivered'::text, 'cancelled'::text])) AND ((o.user_id = auth.uid()) OR (o.merchant_id IN ( SELECT merchants.id
           FROM merchants
          WHERE (merchants.owner_user_id = auth.uid()))))))))$q$;
BEGIN
  SELECT pg_get_expr(p.polqual, p.polrelid), p.polcmd, p.polroles, p.polpermissive
    INTO v_qual, v_cmd, v_roles, v_permissive
    FROM pg_policy p
    JOIN pg_class c ON c.oid = p.polrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public'
     AND c.relname = 'driver_locations'
     AND p.polname = 'driver_locations_select';

  IF NOT FOUND THEN
    RAISE EXCEPTION '425: driver_locations_select policy missing - aborting';
  END IF;

  IF v_permissive AND v_cmd = 'r' AND v_roles = '{0}'::oid[] AND v_qual = c_target THEN
    RAISE NOTICE '425: driver_locations_select already at target state - no-op';
  ELSIF (NOT v_permissive) OR v_cmd <> 'r' OR v_roles <> '{0}'::oid[] OR v_qual IS DISTINCT FROM c_pre THEN
    RAISE EXCEPTION '425: driver_locations_select drifted from expected pre-state - aborting WITHOUT mutation (permissive=%, cmd=%, roles=%, qual=%)', v_permissive, v_cmd, v_roles, v_qual;
  ELSE
    EXECUTE $ddl$DROP POLICY driver_locations_select ON public.driver_locations$ddl$;
    EXECUTE $ddl$CREATE POLICY driver_locations_select ON public.driver_locations AS PERMISSIVE FOR SELECT TO public USING (((driver_id IN ( SELECT drivers.id
   FROM drivers
  WHERE (drivers.user_id = auth.uid()))) OR _is_owner_uid(auth.uid()) OR admin_has_permission('DELIVERY_LOCATION_VIEW'::text, NULL::uuid) OR (EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.driver_id = driver_locations.driver_id) AND (o.dispatch_status = ANY (ARRAY['ASSIGNED'::text, 'ACCEPTED'::text])) AND (o.status <> ALL (ARRAY['delivered'::text, 'cancelled'::text])) AND ((o.user_id = auth.uid()) OR (o.merchant_id IN ( SELECT merchants.id
           FROM merchants
          WHERE (merchants.owner_user_id = auth.uid())))))))))$ddl$;
  END IF;
END;
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_msg = MESSAGE_TEXT;
  END;
  ASSERT v_msg LIKE '425: driver_locations_select drifted from expected pre-state%',
    'A2: extra-restriction drift did not abort: ' || coalesce(v_msg, '<no exception>');
  SELECT pg_get_expr(polqual, polrelid) INTO v_after
    FROM pg_policy p JOIN pg_class c ON c.oid = p.polrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname='public' AND c.relname='driver_locations' AND p.polname='driver_locations_select';
  ASSERT v_after = v_before, 'A2: guard mutated a drifted policy';

  -- A3: drift - changed admin branch, still contains ASSIGNED/ACCEPTED. Must abort, policy untouched.
  EXECUTE 'DROP POLICY driver_locations_select ON public.driver_locations';
  EXECUTE $x$CREATE POLICY driver_locations_select ON public.driver_locations AS PERMISSIVE FOR SELECT TO public USING (((driver_id IN ( SELECT drivers.id
   FROM drivers
  WHERE (drivers.user_id = auth.uid()))) OR _is_owner_uid(auth.uid()) OR _is_active_admin_uid(auth.uid()) OR (EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.driver_id = driver_locations.driver_id) AND (o.dispatch_status = ANY (ARRAY['ASSIGNED'::text, 'ACCEPTED'::text])) AND ((o.user_id = auth.uid()) OR (o.merchant_id IN ( SELECT merchants.id
           FROM merchants
          WHERE (merchants.owner_user_id = auth.uid())))))))))$x$;
  SELECT pg_get_expr(polqual, polrelid) INTO v_before
    FROM pg_policy p JOIN pg_class c ON c.oid = p.polrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname='public' AND c.relname='driver_locations' AND p.polname='driver_locations_select';
  v_msg := NULL;
  BEGIN
DECLARE
  v_qual       text;
  v_cmd        "char";
  v_roles      oid[];
  v_permissive boolean;
  c_pre    constant text := $q$((driver_id IN ( SELECT drivers.id
   FROM drivers
  WHERE (drivers.user_id = auth.uid()))) OR _is_owner_uid(auth.uid()) OR admin_has_permission('DELIVERY_LOCATION_VIEW'::text, NULL::uuid) OR (EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.driver_id = driver_locations.driver_id) AND (o.dispatch_status = ANY (ARRAY['ASSIGNED'::text, 'ACCEPTED'::text])) AND ((o.user_id = auth.uid()) OR (o.merchant_id IN ( SELECT merchants.id
           FROM merchants
          WHERE (merchants.owner_user_id = auth.uid()))))))))$q$;
  c_target constant text := $q$((driver_id IN ( SELECT drivers.id
   FROM drivers
  WHERE (drivers.user_id = auth.uid()))) OR _is_owner_uid(auth.uid()) OR admin_has_permission('DELIVERY_LOCATION_VIEW'::text, NULL::uuid) OR (EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.driver_id = driver_locations.driver_id) AND (o.dispatch_status = ANY (ARRAY['ASSIGNED'::text, 'ACCEPTED'::text])) AND (o.status <> ALL (ARRAY['delivered'::text, 'cancelled'::text])) AND ((o.user_id = auth.uid()) OR (o.merchant_id IN ( SELECT merchants.id
           FROM merchants
          WHERE (merchants.owner_user_id = auth.uid()))))))))$q$;
BEGIN
  SELECT pg_get_expr(p.polqual, p.polrelid), p.polcmd, p.polroles, p.polpermissive
    INTO v_qual, v_cmd, v_roles, v_permissive
    FROM pg_policy p
    JOIN pg_class c ON c.oid = p.polrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public'
     AND c.relname = 'driver_locations'
     AND p.polname = 'driver_locations_select';

  IF NOT FOUND THEN
    RAISE EXCEPTION '425: driver_locations_select policy missing - aborting';
  END IF;

  IF v_permissive AND v_cmd = 'r' AND v_roles = '{0}'::oid[] AND v_qual = c_target THEN
    RAISE NOTICE '425: driver_locations_select already at target state - no-op';
  ELSIF (NOT v_permissive) OR v_cmd <> 'r' OR v_roles <> '{0}'::oid[] OR v_qual IS DISTINCT FROM c_pre THEN
    RAISE EXCEPTION '425: driver_locations_select drifted from expected pre-state - aborting WITHOUT mutation (permissive=%, cmd=%, roles=%, qual=%)', v_permissive, v_cmd, v_roles, v_qual;
  ELSE
    EXECUTE $ddl$DROP POLICY driver_locations_select ON public.driver_locations$ddl$;
    EXECUTE $ddl$CREATE POLICY driver_locations_select ON public.driver_locations AS PERMISSIVE FOR SELECT TO public USING (((driver_id IN ( SELECT drivers.id
   FROM drivers
  WHERE (drivers.user_id = auth.uid()))) OR _is_owner_uid(auth.uid()) OR admin_has_permission('DELIVERY_LOCATION_VIEW'::text, NULL::uuid) OR (EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.driver_id = driver_locations.driver_id) AND (o.dispatch_status = ANY (ARRAY['ASSIGNED'::text, 'ACCEPTED'::text])) AND (o.status <> ALL (ARRAY['delivered'::text, 'cancelled'::text])) AND ((o.user_id = auth.uid()) OR (o.merchant_id IN ( SELECT merchants.id
           FROM merchants
          WHERE (merchants.owner_user_id = auth.uid())))))))))$ddl$;
  END IF;
END;
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_msg = MESSAGE_TEXT;
  END;
  ASSERT v_msg LIKE '425: driver_locations_select drifted from expected pre-state%',
    'A3: changed-admin-branch drift did not abort: ' || coalesce(v_msg, '<no exception>');
  SELECT pg_get_expr(polqual, polrelid) INTO v_after
    FROM pg_policy p JOIN pg_class c ON c.oid = p.polrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname='public' AND c.relname='driver_locations' AND p.polname='driver_locations_select';
  ASSERT v_after = v_before, 'A3: guard mutated a drifted policy';

  -- A4: drift - RESTRICTIVE variant of the exact target predicate. Must abort, policy untouched.
  EXECUTE 'DROP POLICY driver_locations_select ON public.driver_locations';
  EXECUTE $x$CREATE POLICY driver_locations_select ON public.driver_locations AS RESTRICTIVE FOR SELECT TO public USING (((driver_id IN ( SELECT drivers.id
   FROM drivers
  WHERE (drivers.user_id = auth.uid()))) OR _is_owner_uid(auth.uid()) OR admin_has_permission('DELIVERY_LOCATION_VIEW'::text, NULL::uuid) OR (EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.driver_id = driver_locations.driver_id) AND (o.dispatch_status = ANY (ARRAY['ASSIGNED'::text, 'ACCEPTED'::text])) AND (o.status <> ALL (ARRAY['delivered'::text, 'cancelled'::text])) AND ((o.user_id = auth.uid()) OR (o.merchant_id IN ( SELECT merchants.id
           FROM merchants
          WHERE (merchants.owner_user_id = auth.uid())))))))))$x$;
  SELECT pg_get_expr(polqual, polrelid) INTO v_before
    FROM pg_policy p JOIN pg_class c ON c.oid = p.polrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname='public' AND c.relname='driver_locations' AND p.polname='driver_locations_select';
  SELECT polpermissive INTO v_perm
    FROM pg_policy p JOIN pg_class c ON c.oid = p.polrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname='public' AND c.relname='driver_locations' AND p.polname='driver_locations_select';
  ASSERT v_perm = false, 'A4: restrictive fixture was not restrictive';
  v_msg := NULL;
  BEGIN
DECLARE
  v_qual       text;
  v_cmd        "char";
  v_roles      oid[];
  v_permissive boolean;
  c_pre    constant text := $q$((driver_id IN ( SELECT drivers.id
   FROM drivers
  WHERE (drivers.user_id = auth.uid()))) OR _is_owner_uid(auth.uid()) OR admin_has_permission('DELIVERY_LOCATION_VIEW'::text, NULL::uuid) OR (EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.driver_id = driver_locations.driver_id) AND (o.dispatch_status = ANY (ARRAY['ASSIGNED'::text, 'ACCEPTED'::text])) AND ((o.user_id = auth.uid()) OR (o.merchant_id IN ( SELECT merchants.id
           FROM merchants
          WHERE (merchants.owner_user_id = auth.uid()))))))))$q$;
  c_target constant text := $q$((driver_id IN ( SELECT drivers.id
   FROM drivers
  WHERE (drivers.user_id = auth.uid()))) OR _is_owner_uid(auth.uid()) OR admin_has_permission('DELIVERY_LOCATION_VIEW'::text, NULL::uuid) OR (EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.driver_id = driver_locations.driver_id) AND (o.dispatch_status = ANY (ARRAY['ASSIGNED'::text, 'ACCEPTED'::text])) AND (o.status <> ALL (ARRAY['delivered'::text, 'cancelled'::text])) AND ((o.user_id = auth.uid()) OR (o.merchant_id IN ( SELECT merchants.id
           FROM merchants
          WHERE (merchants.owner_user_id = auth.uid()))))))))$q$;
BEGIN
  SELECT pg_get_expr(p.polqual, p.polrelid), p.polcmd, p.polroles, p.polpermissive
    INTO v_qual, v_cmd, v_roles, v_permissive
    FROM pg_policy p
    JOIN pg_class c ON c.oid = p.polrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public'
     AND c.relname = 'driver_locations'
     AND p.polname = 'driver_locations_select';

  IF NOT FOUND THEN
    RAISE EXCEPTION '425: driver_locations_select policy missing - aborting';
  END IF;

  IF v_permissive AND v_cmd = 'r' AND v_roles = '{0}'::oid[] AND v_qual = c_target THEN
    RAISE NOTICE '425: driver_locations_select already at target state - no-op';
  ELSIF (NOT v_permissive) OR v_cmd <> 'r' OR v_roles <> '{0}'::oid[] OR v_qual IS DISTINCT FROM c_pre THEN
    RAISE EXCEPTION '425: driver_locations_select drifted from expected pre-state - aborting WITHOUT mutation (permissive=%, cmd=%, roles=%, qual=%)', v_permissive, v_cmd, v_roles, v_qual;
  ELSE
    EXECUTE $ddl$DROP POLICY driver_locations_select ON public.driver_locations$ddl$;
    EXECUTE $ddl$CREATE POLICY driver_locations_select ON public.driver_locations AS PERMISSIVE FOR SELECT TO public USING (((driver_id IN ( SELECT drivers.id
   FROM drivers
  WHERE (drivers.user_id = auth.uid()))) OR _is_owner_uid(auth.uid()) OR admin_has_permission('DELIVERY_LOCATION_VIEW'::text, NULL::uuid) OR (EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.driver_id = driver_locations.driver_id) AND (o.dispatch_status = ANY (ARRAY['ASSIGNED'::text, 'ACCEPTED'::text])) AND (o.status <> ALL (ARRAY['delivered'::text, 'cancelled'::text])) AND ((o.user_id = auth.uid()) OR (o.merchant_id IN ( SELECT merchants.id
           FROM merchants
          WHERE (merchants.owner_user_id = auth.uid())))))))))$ddl$;
  END IF;
END;
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_msg = MESSAGE_TEXT;
  END;
  ASSERT v_msg LIKE '425: driver_locations_select drifted from expected pre-state%',
    'A4: restrictive-policy drift did not abort: ' || coalesce(v_msg, '<no exception>');
  SELECT pg_get_expr(polqual, polrelid) INTO v_after
    FROM pg_policy p JOIN pg_class c ON c.oid = p.polrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname='public' AND c.relname='driver_locations' AND p.polname='driver_locations_select';
  SELECT polpermissive INTO v_perm
    FROM pg_policy p JOIN pg_class c ON c.oid = p.polrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname='public' AND c.relname='driver_locations' AND p.polname='driver_locations_select';
  ASSERT v_after = v_before AND v_perm = false, 'A4: guard mutated a restrictive drifted policy';

  -- A5: apply path - exact canonical pre-state applies cleanly to the target
  EXECUTE 'DROP POLICY driver_locations_select ON public.driver_locations';
  EXECUTE $x$CREATE POLICY driver_locations_select ON public.driver_locations AS PERMISSIVE FOR SELECT TO public USING (((driver_id IN ( SELECT drivers.id
   FROM drivers
  WHERE (drivers.user_id = auth.uid()))) OR _is_owner_uid(auth.uid()) OR admin_has_permission('DELIVERY_LOCATION_VIEW'::text, NULL::uuid) OR (EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.driver_id = driver_locations.driver_id) AND (o.dispatch_status = ANY (ARRAY['ASSIGNED'::text, 'ACCEPTED'::text])) AND ((o.user_id = auth.uid()) OR (o.merchant_id IN ( SELECT merchants.id
           FROM merchants
          WHERE (merchants.owner_user_id = auth.uid())))))))))$x$;
  v_msg := NULL;
  BEGIN
DECLARE
  v_qual       text;
  v_cmd        "char";
  v_roles      oid[];
  v_permissive boolean;
  c_pre    constant text := $q$((driver_id IN ( SELECT drivers.id
   FROM drivers
  WHERE (drivers.user_id = auth.uid()))) OR _is_owner_uid(auth.uid()) OR admin_has_permission('DELIVERY_LOCATION_VIEW'::text, NULL::uuid) OR (EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.driver_id = driver_locations.driver_id) AND (o.dispatch_status = ANY (ARRAY['ASSIGNED'::text, 'ACCEPTED'::text])) AND ((o.user_id = auth.uid()) OR (o.merchant_id IN ( SELECT merchants.id
           FROM merchants
          WHERE (merchants.owner_user_id = auth.uid()))))))))$q$;
  c_target constant text := $q$((driver_id IN ( SELECT drivers.id
   FROM drivers
  WHERE (drivers.user_id = auth.uid()))) OR _is_owner_uid(auth.uid()) OR admin_has_permission('DELIVERY_LOCATION_VIEW'::text, NULL::uuid) OR (EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.driver_id = driver_locations.driver_id) AND (o.dispatch_status = ANY (ARRAY['ASSIGNED'::text, 'ACCEPTED'::text])) AND (o.status <> ALL (ARRAY['delivered'::text, 'cancelled'::text])) AND ((o.user_id = auth.uid()) OR (o.merchant_id IN ( SELECT merchants.id
           FROM merchants
          WHERE (merchants.owner_user_id = auth.uid()))))))))$q$;
BEGIN
  SELECT pg_get_expr(p.polqual, p.polrelid), p.polcmd, p.polroles, p.polpermissive
    INTO v_qual, v_cmd, v_roles, v_permissive
    FROM pg_policy p
    JOIN pg_class c ON c.oid = p.polrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public'
     AND c.relname = 'driver_locations'
     AND p.polname = 'driver_locations_select';

  IF NOT FOUND THEN
    RAISE EXCEPTION '425: driver_locations_select policy missing - aborting';
  END IF;

  IF v_permissive AND v_cmd = 'r' AND v_roles = '{0}'::oid[] AND v_qual = c_target THEN
    RAISE NOTICE '425: driver_locations_select already at target state - no-op';
  ELSIF (NOT v_permissive) OR v_cmd <> 'r' OR v_roles <> '{0}'::oid[] OR v_qual IS DISTINCT FROM c_pre THEN
    RAISE EXCEPTION '425: driver_locations_select drifted from expected pre-state - aborting WITHOUT mutation (permissive=%, cmd=%, roles=%, qual=%)', v_permissive, v_cmd, v_roles, v_qual;
  ELSE
    EXECUTE $ddl$DROP POLICY driver_locations_select ON public.driver_locations$ddl$;
    EXECUTE $ddl$CREATE POLICY driver_locations_select ON public.driver_locations AS PERMISSIVE FOR SELECT TO public USING (((driver_id IN ( SELECT drivers.id
   FROM drivers
  WHERE (drivers.user_id = auth.uid()))) OR _is_owner_uid(auth.uid()) OR admin_has_permission('DELIVERY_LOCATION_VIEW'::text, NULL::uuid) OR (EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.driver_id = driver_locations.driver_id) AND (o.dispatch_status = ANY (ARRAY['ASSIGNED'::text, 'ACCEPTED'::text])) AND (o.status <> ALL (ARRAY['delivered'::text, 'cancelled'::text])) AND ((o.user_id = auth.uid()) OR (o.merchant_id IN ( SELECT merchants.id
           FROM merchants
          WHERE (merchants.owner_user_id = auth.uid())))))))))$ddl$;
  END IF;
END;
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_msg = MESSAGE_TEXT;
  END;
  ASSERT v_msg IS NULL, 'A5: guard raised on exact pre-state: ' || coalesce(v_msg, '');
  SELECT pg_get_expr(polqual, polrelid) INTO v_after
    FROM pg_policy p JOIN pg_class c ON c.oid = p.polrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname='public' AND c.relname='driver_locations' AND p.polname='driver_locations_select';
  ASSERT v_after = c_target, 'A5: apply path did not reach the target predicate';
END $t$;

DO $$
DECLARE
  c uuid := gen_random_uuid(); u1 uuid := gen_random_uuid(); mu uuid := gen_random_uuid();
  ow uuid := gen_random_uuid(); ad uuid := gen_random_uuid();
  st uuid := gen_random_uuid(); np uuid := gen_random_uuid();
  d1 uuid := gen_random_uuid(); m uuid := gen_random_uuid(); o1 uuid := gen_random_uuid();
  v_n int;
BEGIN
  INSERT INTO auth.users(id,email) SELECT g, g::text||'@x.i' FROM unnest(ARRAY[c,u1,mu,ow,ad,st,np]) g;
  INSERT INTO public.users(id,email,role) VALUES
    (c,c::text||'@x.i','customer'),(mu,mu::text||'@x.i','merchant'),
    (ow,ow::text||'@x.i','owner'),(ad,ad::text||'@x.i','admin'),
    (st,st::text||'@x.i','customer'),(np,np::text||'@x.i','admin')
    ON CONFLICT(id) DO UPDATE SET role=EXCLUDED.role;
  INSERT INTO public.users(id,email,role) VALUES (u1,u1::text||'@x.i','driver')
    ON CONFLICT(id) DO UPDATE SET role=EXCLUDED.role;
  INSERT INTO public.admin_management(admin_id,supervisor_id,is_active) VALUES (ad,ow,true),(np,ow,true);
  INSERT INTO public.regions(id,code,country_code,name_ar,type,is_active) VALUES (gen_random_uuid(),'425R','EG','425','city',true);
  INSERT INTO public.admin_region_assignments(admin_id,region_id) SELECT ad, id FROM public.regions WHERE code='425R';
  INSERT INTO public.admin_permission_grants(admin_id,permission) VALUES (ad,'DELIVERY_LOCATION_VIEW');
  -- np: active admin with NO DELIVERY_LOCATION_VIEW grant (non-permissioned negative)
  INSERT INTO public.drivers(id,user_id,full_name,status,is_verified,is_active,accepts_deliveries,service_types,max_delivery_distance_km,max_weight_kg)
    VALUES (d1,u1,'425 D1','approved',true,true,true,ARRAY['parcel']::text[],15,20);
  INSERT INTO public.merchants(id,name,owner_user_id,type,status,is_open)
    VALUES (m,'425 M',mu,'restaurant','active',true);
  INSERT INTO public.orders(id,user_id,merchant_id,driver_id,status,dispatch_status,payment_status,payment_method,subtotal,total_amount,delivery_fee,delivery_latitude,delivery_longitude)
    VALUES (o1,c,m,d1,'delivering','ACCEPTED','unpaid','cash',100,120,20,30.001,31.001);
  INSERT INTO public.driver_locations(driver_id,latitude,longitude) VALUES (d1,30.05,31.25);

  PERFORM set_config('role','authenticated',true);

  -- while delivering: customer, merchant, driver, owner, permissioned admin all read
  PERFORM set_config('request.jwt.claim.sub', c::text, true);
  SELECT count(*) INTO v_n FROM public.driver_locations WHERE driver_id=d1;
  ASSERT v_n = 1, '425: customer cannot read while delivering';
  PERFORM set_config('request.jwt.claim.sub', mu::text, true);
  SELECT count(*) INTO v_n FROM public.driver_locations WHERE driver_id=d1;
  ASSERT v_n = 1, '425: merchant cannot read while delivering';
  PERFORM set_config('request.jwt.claim.sub', u1::text, true);
  SELECT count(*) INTO v_n FROM public.driver_locations WHERE driver_id=d1;
  ASSERT v_n = 1, '425: driver cannot read own row';
  PERFORM set_config('request.jwt.claim.sub', ow::text, true);
  SELECT count(*) INTO v_n FROM public.driver_locations WHERE driver_id=d1;
  ASSERT v_n = 1, '425: owner cannot read while delivering';
  PERFORM set_config('request.jwt.claim.sub', ad::text, true);
  SELECT count(*) INTO v_n FROM public.driver_locations WHERE driver_id=d1;
  ASSERT v_n = 1, '425: permissioned admin cannot read while delivering';
  -- negatives while delivering: stranger and non-permissioned admin
  PERFORM set_config('request.jwt.claim.sub', st::text, true);
  SELECT count(*) INTO v_n FROM public.driver_locations WHERE driver_id=d1;
  ASSERT v_n = 0, '425: stranger can read driver location';
  PERFORM set_config('request.jwt.claim.sub', np::text, true);
  SELECT count(*) INTO v_n FROM public.driver_locations WHERE driver_id=d1;
  ASSERT v_n = 0, '425: non-permissioned admin can read driver location';

  -- delivery completes
  PERFORM set_config('role','none',true);
  UPDATE public.orders SET status='delivered' WHERE id=o1;
  PERFORM set_config('role','authenticated',true);

  -- customer + merchant lose the row; owner, permissioned admin, driver keep it; negatives stay hidden
  PERFORM set_config('request.jwt.claim.sub', c::text, true);
  SELECT count(*) INTO v_n FROM public.driver_locations WHERE driver_id=d1;
  ASSERT v_n = 0, '425: customer still reads after delivered';
  PERFORM set_config('request.jwt.claim.sub', mu::text, true);
  SELECT count(*) INTO v_n FROM public.driver_locations WHERE driver_id=d1;
  ASSERT v_n = 0, '425: merchant still reads after delivered';
  PERFORM set_config('request.jwt.claim.sub', ow::text, true);
  SELECT count(*) INTO v_n FROM public.driver_locations WHERE driver_id=d1;
  ASSERT v_n = 1, '425: owner lost access after delivered';
  PERFORM set_config('request.jwt.claim.sub', ad::text, true);
  SELECT count(*) INTO v_n FROM public.driver_locations WHERE driver_id=d1;
  ASSERT v_n = 1, '425: permissioned admin lost access after delivered';
  PERFORM set_config('request.jwt.claim.sub', u1::text, true);
  SELECT count(*) INTO v_n FROM public.driver_locations WHERE driver_id=d1;
  ASSERT v_n = 1, '425: driver lost own row after delivered';
  PERFORM set_config('request.jwt.claim.sub', np::text, true);
  SELECT count(*) INTO v_n FROM public.driver_locations WHERE driver_id=d1;
  ASSERT v_n = 0, '425: non-permissioned admin gained access after delivered';

  -- cancelled orders also close the window
  PERFORM set_config('role','none',true);
  UPDATE public.orders SET status='delivering' WHERE id=o1;
  PERFORM set_config('role','authenticated',true);
  PERFORM set_config('request.jwt.claim.sub', c::text, true);
  SELECT count(*) INTO v_n FROM public.driver_locations WHERE driver_id=d1;
  ASSERT v_n = 1, '425: customer lost access while delivering (restore)';
  PERFORM set_config('role','none',true);
  UPDATE public.orders SET status='cancelled' WHERE id=o1;
  PERFORM set_config('role','authenticated',true);
  PERFORM set_config('request.jwt.claim.sub', c::text, true);
  SELECT count(*) INTO v_n FROM public.driver_locations WHERE driver_id=d1;
  ASSERT v_n = 0, '425: customer still reads after cancelled';
  PERFORM set_config('request.jwt.claim.sub', mu::text, true);
  SELECT count(*) INTO v_n FROM public.driver_locations WHERE driver_id=d1;
  ASSERT v_n = 0, '425: merchant still reads after cancelled';

  PERFORM set_config('role','none',true);
END $$;

ROLLBACK;
