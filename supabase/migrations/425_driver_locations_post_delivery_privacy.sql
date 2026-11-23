-- 425 v2: driver_locations post-delivery privacy (owner-directed follow-up
-- to the ops WS privacy test, 2026-11-23). v2 hardens the prod-safe guard
-- per code-review finding #134.
--
-- driver_locations_select lets a customer (or their merchant) read the
-- assigned driver's live location while an order links them
-- (dispatch_status ASSIGNED/ACCEPTED). Because dispatch_status stays
-- 'ACCEPTED' even after the order reaches 'delivered', the row remained
-- readable after the delivery was over. Live location of a person after
-- the service relationship ends serves no delivery purpose - close it.
--
-- Change: inside the customer/merchant EXISTS predicate only, add
--   AND o.status NOT IN ('delivered','cancelled')
-- Nothing else: the driver's own access, the owner path, the admin
-- permission path, all ACLs and every other policy are untouched.
-- Convergent: prod and staging share this baseline policy.
--
-- Guard: the whole change is one DO block. It reads the live policy's
-- canonical pg_get_expr qual, command and roles and
--   - no-ops when the policy is already at the exact target predicate
--     (idempotent re-run, e.g. staging),
--   - aborts WITHOUT any mutation on any drift from the exact canonical
--     pre-state (different qual, command or roles),
--   - otherwise swaps the policy atomically.
-- The guard block below is copied VERBATIM into
-- supabase/tests/425_driver_locations_post_delivery_test.sql, which proves
-- the no-op path, the drift-abort paths and the apply path.

BEGIN;

DO $g$
DECLARE
  v_qual  text;
  v_cmd   "char";
  v_roles oid[];
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
  SELECT pg_get_expr(p.polqual, p.polrelid), p.polcmd, p.polroles
    INTO v_qual, v_cmd, v_roles
    FROM pg_policy p
    JOIN pg_class c ON c.oid = p.polrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public'
     AND c.relname = 'driver_locations'
     AND p.polname = 'driver_locations_select';

  IF NOT FOUND THEN
    RAISE EXCEPTION '425: driver_locations_select policy missing - aborting';
  END IF;

  IF v_cmd = 'r' AND v_roles = '{0}'::oid[] AND v_qual = c_target THEN
    RAISE NOTICE '425: driver_locations_select already at target state - no-op';
  ELSIF v_cmd <> 'r' OR v_roles <> '{0}'::oid[] OR v_qual IS DISTINCT FROM c_pre THEN
    RAISE EXCEPTION '425: driver_locations_select drifted from expected pre-state - aborting WITHOUT mutation (cmd=%, roles=%, qual=%)', v_cmd, v_roles, v_qual;
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
$g$;

COMMIT;
