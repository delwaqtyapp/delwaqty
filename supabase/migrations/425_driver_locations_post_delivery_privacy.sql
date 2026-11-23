-- 425: driver_locations post-delivery privacy (owner-directed follow-up to
-- the ops WS privacy test, 2026-11-23).
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

BEGIN;

-- Prod-safe guard: refuse to run unless the policy exists and still has
-- exactly the expected pre-state predicate (the ASSIGNED/ACCEPTED window
-- without a terminal-status clause). Never edit a drifted policy blindly.
DO $$
DECLARE
  v_qual text := (SELECT qual FROM pg_policies
                  WHERE schemaname='public' AND tablename='driver_locations'
                    AND policyname='driver_locations_select');
BEGIN
  IF v_qual IS NULL THEN
    RAISE EXCEPTION '425: driver_locations_select policy missing - aborting';
  END IF;
  IF v_qual NOT LIKE '%ASSIGNED%ACCEPTED%' OR v_qual LIKE '%delivered%' THEN
    RAISE EXCEPTION '425: driver_locations_select not at expected pre-state - aborting: %', v_qual;
  END IF;
END $$;

DROP POLICY driver_locations_select ON public.driver_locations;
CREATE POLICY driver_locations_select ON public.driver_locations AS PERMISSIVE FOR SELECT TO public USING (((driver_id IN ( SELECT drivers.id
   FROM drivers
  WHERE (drivers.user_id = auth.uid()))) OR _is_owner_uid(auth.uid()) OR admin_has_permission('DELIVERY_LOCATION_VIEW'::text, NULL::uuid) OR (EXISTS ( SELECT 1
   FROM orders o
  WHERE ((o.driver_id = driver_locations.driver_id) AND (o.dispatch_status = ANY (ARRAY['ASSIGNED'::text, 'ACCEPTED'::text])) AND (o.status <> ALL (ARRAY['delivered'::text, 'cancelled'::text])) AND ((o.user_id = auth.uid()) OR (o.merchant_id IN ( SELECT merchants.id
           FROM merchants
          WHERE (merchants.owner_user_id = auth.uid())))))))));

COMMIT;
