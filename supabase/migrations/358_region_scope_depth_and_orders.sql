-- 358_region_scope_depth_and_orders.sql
-- Lab regression: _point_region_id used geo_region_for_point's default depth 2,
-- resolving merchants to governorate/district instead of village/center, which
-- denied local admins their own merchants. Depth 3 activates child refinement.
-- Also: orders/drivers/rides admin write policies get the same scope treatment,
-- and _region_in_scope no longer treats unassigned admins as in-scope.

BEGIN;

CREATE OR REPLACE FUNCTION public._point_region_id(p_lat double precision, p_lon double precision)
RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT (public.geo_region_for_point(p_lat, p_lon, 3)).region_id;
$$;

-- Unassigned admins are in scope of nothing (suite F directive).
CREATE OR REPLACE FUNCTION public._region_in_scope(p_uid uuid, p_region_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF EXISTS (SELECT 1 FROM public.users u WHERE u.id = p_uid AND u.role = 'owner') THEN
    RETURN true;
  END IF;
  IF p_region_id IS NULL THEN
    RETURN false;
  END IF;
  RETURN EXISTS (
    SELECT 1 FROM public.admin_region_assignments a
    WHERE a.admin_id = p_uid
      AND (
        (a.scope = 'self' AND a.region_id = p_region_id)
        OR (a.scope = 'descendants' AND p_region_id IN (
          WITH RECURSIVE covered AS (
            SELECT id FROM public.regions WHERE id = a.region_id
            UNION ALL
            SELECT r.id FROM public.regions r JOIN covered c ON r.parent_region_id = c.id
          )
          SELECT id FROM covered
        ))
      )
  );
END;
$function$;

DROP POLICY IF EXISTS "Admins can update any order" ON public.orders;
CREATE POLICY "Admins can update any order" ON public.orders
  FOR UPDATE TO authenticated
  USING (public.admin_has_permission('ORDER_MANAGE')
         AND public._admin_write_scope(public._merchant_region_id(merchant_id)))
  WITH CHECK (public.admin_has_permission('ORDER_MANAGE')
         AND public._admin_write_scope(public._merchant_region_id(merchant_id)));

DROP POLICY IF EXISTS "Admins can update any driver" ON public.drivers;
CREATE POLICY "Admins can update any driver" ON public.drivers
  FOR UPDATE TO authenticated
  USING (public._admin_write_scope(public._member_region_id(user_id)))
  WITH CHECK (public._admin_write_scope(public._member_region_id(user_id)));

DROP POLICY IF EXISTS "Admins can update any ride" ON public.rides;
CREATE POLICY "Admins can update any ride" ON public.rides
  FOR UPDATE TO authenticated
  USING (public._admin_write_scope(public._member_region_id(rider_id)))
  WITH CHECK (public._admin_write_scope(public._member_region_id(rider_id)));

COMMIT;
