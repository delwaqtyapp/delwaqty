-- 202: get_admin_analytics truthful totals
-- Defects fixed:
--   1. total_* fields were actually 30-day-window counts, mislabeled as totals.
--   2. Orders were counted from the rides (deliveries) table instead of orders.
--   3. Revenue was summed from rides.fare instead of orders.total_amount.
-- Fix: total_* keys become true all-time totals from the authoritative tables
-- (orders / users / drivers / merchants), and explicitly-labeled window_*
-- fields carry the date-range values. Existing callers keep their keys.

CREATE OR REPLACE FUNCTION public.get_admin_analytics(
  date_from timestamptz DEFAULT NULL,
  date_to   timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_from TIMESTAMPTZ := COALESCE(date_from, NOW() - INTERVAL '30 days');
  v_to   TIMESTAMPTZ := COALESCE(date_to, NOW());
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN jsonb_build_object(
    -- All-time true totals (key names preserved for existing callers)
    'total_orders',    (SELECT COUNT(*) FROM public.orders),
    'total_revenue',   (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'delivered'),
    'total_users',     (SELECT COUNT(*) FROM public.users),
    'total_drivers',   (SELECT COUNT(*) FROM public.drivers),
    'total_merchants', (SELECT COUNT(*) FROM public.merchants),
    -- Windowed values, explicitly labeled
    'window_orders',        (SELECT COUNT(*) FROM public.orders WHERE created_at BETWEEN v_from AND v_to),
    'window_revenue',       (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'delivered' AND created_at BETWEEN v_from AND v_to),
    'window_new_users',     (SELECT COUNT(*) FROM public.users WHERE created_at BETWEEN v_from AND v_to),
    'window_new_drivers',   (SELECT COUNT(*) FROM public.drivers WHERE created_at BETWEEN v_from AND v_to),
    'window_new_merchants', (SELECT COUNT(*) FROM public.merchants WHERE created_at BETWEEN v_from AND v_to),
    'window_from', v_from,
    'window_to',   v_to
  );
END;
$function$;

NOTIFY pgrst, 'reload schema';
