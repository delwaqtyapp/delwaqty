-- 372: scoped admin dashboard metrics.
-- One RPC replaces count_table_rows + 13 bare .count() selects. Owner/country
-- admins get global numbers; region-scoped admins get counts limited to rows
-- inside their assigned regions (same region-attribution rules as
-- list_members/admin_list_merchants); anyone else gets zeros, never an error.

CREATE OR REPLACE FUNCTION public.admin_dashboard_metrics()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_global boolean;
  v_today timestamptz := date_trunc('day', now());
  v_month timestamptz := date_trunc('month', now());
BEGIN
  IF v_uid IS NULL OR NOT public.has_permission('ANALYTICS_VIEW', NULL) THEN
    RETURN jsonb_build_object(
      'totalUsers',0,'totalDrivers',0,'totalMerchants',0,'activeDrivers',0,
      'pendingVerifications',0,'totalDeliveries',0,'pendingOrders',0,
      'completedDeliveries',0,'totalRevenue',0,'revenueToday',0,
      'revenueThisMonth',0,'newUsersToday',0,'newUsersThisMonth',0);
  END IF;

  v_global := public._is_owner_uid(v_uid) OR public._is_country_admin_uid(v_uid);

  IF v_global THEN
    RETURN (
      SELECT jsonb_build_object(
        'totalUsers', (SELECT count(*) FROM public.users),
        'totalDrivers', (SELECT count(*) FROM public.drivers),
        'totalMerchants', (SELECT count(*) FROM public.merchants),
        'activeDrivers', (SELECT count(*) FROM public.drivers WHERE is_online),
        'pendingVerifications', (SELECT count(*) FROM public.drivers WHERE verification_status = 'pending'),
        'totalDeliveries', (SELECT count(*) FROM public.rides WHERE service_type IS DISTINCT FROM 'ride'),
        'pendingOrders', (SELECT count(*) FROM public.orders WHERE status = 'pending'),
        'completedDeliveries', (SELECT count(*) FROM public.rides WHERE service_type IS DISTINCT FROM 'ride' AND status = 'completed'),
        'totalRevenue', COALESCE((SELECT sum(fare) FROM public.rides WHERE service_type IS DISTINCT FROM 'ride' AND status = 'completed'),0),
        'revenueToday', COALESCE((SELECT sum(fare) FROM public.rides WHERE service_type IS DISTINCT FROM 'ride' AND status = 'completed' AND completed_at >= v_today),0),
        'revenueThisMonth', COALESCE((SELECT sum(fare) FROM public.rides WHERE service_type IS DISTINCT FROM 'ride' AND status = 'completed' AND completed_at >= v_month),0),
        'newUsersToday', (SELECT count(*) FROM public.users WHERE created_at >= v_today),
        'newUsersThisMonth', (SELECT count(*) FROM public.users WHERE created_at >= v_month)
      ));
  END IF;

  RETURN (
    SELECT jsonb_build_object(
      'totalUsers', (SELECT count(*) FROM public.users u WHERE EXISTS (
        SELECT 1 FROM public.user_region_preferences up
        WHERE up.user_id = u.id AND public._region_in_scope(v_uid, up.region_id))),
      'totalDrivers', (SELECT count(*) FROM public.drivers d WHERE EXISTS (
        SELECT 1 FROM public.user_region_preferences up
        WHERE up.user_id = d.user_id AND public._region_in_scope(v_uid, up.region_id))),
      'totalMerchants', (SELECT count(*) FROM public.merchants m
        WHERE public._region_in_scope(v_uid, public._merchant_region_id(m.id))),
      'activeDrivers', (SELECT count(*) FROM public.drivers d WHERE d.is_online AND EXISTS (
        SELECT 1 FROM public.user_region_preferences up
        WHERE up.user_id = d.user_id AND public._region_in_scope(v_uid, up.region_id))),
      'pendingVerifications', (SELECT count(*) FROM public.drivers d WHERE d.verification_status = 'pending' AND EXISTS (
        SELECT 1 FROM public.user_region_preferences up
        WHERE up.user_id = d.user_id AND public._region_in_scope(v_uid, up.region_id))),
      'totalDeliveries', (SELECT count(*) FROM public.rides x WHERE x.service_type IS DISTINCT FROM 'ride'
        AND public._region_in_scope(v_uid, COALESCE(public._merchant_region_id(x.merchant_id),
            public._point_region_id(x.pickup_latitude, x.pickup_longitude)))),
      'pendingOrders', (SELECT count(*) FROM public.orders o WHERE o.status = 'pending'
        AND public._region_in_scope(v_uid, public._merchant_region_id(o.merchant_id))),
      'completedDeliveries', (SELECT count(*) FROM public.rides x WHERE x.service_type IS DISTINCT FROM 'ride' AND x.status = 'completed'
        AND public._region_in_scope(v_uid, COALESCE(public._merchant_region_id(x.merchant_id),
            public._point_region_id(x.pickup_latitude, x.pickup_longitude)))),
      'totalRevenue', COALESCE((SELECT sum(x.fare) FROM public.rides x WHERE x.service_type IS DISTINCT FROM 'ride' AND x.status = 'completed'
        AND public._region_in_scope(v_uid, COALESCE(public._merchant_region_id(x.merchant_id),
            public._point_region_id(x.pickup_latitude, x.pickup_longitude)))),0),
      'revenueToday', COALESCE((SELECT sum(x.fare) FROM public.rides x WHERE x.service_type IS DISTINCT FROM 'ride' AND x.status = 'completed' AND x.completed_at >= v_today
        AND public._region_in_scope(v_uid, COALESCE(public._merchant_region_id(x.merchant_id),
            public._point_region_id(x.pickup_latitude, x.pickup_longitude)))),0),
      'revenueThisMonth', COALESCE((SELECT sum(x.fare) FROM public.rides x WHERE x.service_type IS DISTINCT FROM 'ride' AND x.status = 'completed' AND x.completed_at >= v_month
        AND public._region_in_scope(v_uid, COALESCE(public._merchant_region_id(x.merchant_id),
            public._point_region_id(x.pickup_latitude, x.pickup_longitude)))),0),
      'newUsersToday', (SELECT count(*) FROM public.users u WHERE u.created_at >= v_today AND EXISTS (
        SELECT 1 FROM public.user_region_preferences up
        WHERE up.user_id = u.id AND public._region_in_scope(v_uid, up.region_id))),
      'newUsersThisMonth', (SELECT count(*) FROM public.users u WHERE u.created_at >= v_month AND EXISTS (
        SELECT 1 FROM public.user_region_preferences up
        WHERE up.user_id = u.id AND public._region_in_scope(v_uid, up.region_id)))
    ));
END;
$function$;

GRANT EXECUTE ON FUNCTION public.admin_dashboard_metrics() TO authenticated;
