-- ─────────────────────────────────────────────────────────────
-- 089: Admin emergency (SOS) management functions
-- The /admin/emergency nav entry existed but had NO route/page.
-- Customer triggers SOS via trigger_sos_alert (rider-scoped);
-- admins need a listing + a close/resolve action. Both functions
-- are SECURITY DEFINER and gated by public.is_admin() — the same
-- gate used by all admin management functions.
-- ─────────────────────────────────────────────────────────────

DROP FUNCTION IF EXISTS public.admin_list_sos_alerts(TEXT);
CREATE OR REPLACE FUNCTION public.admin_list_sos_alerts(
  p_status text DEFAULT 'active'
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_alerts jsonb;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'insufficient_privilege';
  END IF;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', a.id::text,
      'alert_type', a.alert_type,
      'status', a.status,
      'latitude', a.latitude,
      'longitude', a.longitude,
      'address', a.address,
      'notes', a.notes,
      'created_at', a.created_at,
      'resolved_at', a.resolved_at,
      'user_id', a.user_id::text,
      'user_name', u.name,
      'user_phone', u.phone,
      'ride_id', a.ride_id::text,
      'driver_name', d.full_name,
      'driver_phone', d.phone
    ) ORDER BY a.created_at DESC), '[]'::jsonb)
  INTO v_alerts
  FROM public.sos_alerts a
  LEFT JOIN public.users u ON u.id = a.user_id
  LEFT JOIN public.rides r ON r.id = a.ride_id
  LEFT JOIN public.drivers d ON d.id = r.driver_id
  WHERE ($1 IS NULL OR a.status = $1);

  RETURN v_alerts;
END;
$$;

DROP FUNCTION IF EXISTS public.admin_resolve_sos_alert(UUID, TEXT, TEXT);
CREATE OR REPLACE FUNCTION public.admin_resolve_sos_alert(
  p_alert_id uuid,
  p_status text DEFAULT 'resolved',
  p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_updated int;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'insufficient_privilege';
  END IF;

  UPDATE public.sos_alerts
  SET status = p_status,
      resolved_at = NOW(),
      notes = COALESCE(p_note, notes)
  WHERE id = p_alert_id AND status IN ('active', 'escalated');

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  IF v_updated = 0 THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_found_or_already_closed');
  END IF;

  RETURN jsonb_build_object('success', true, 'alert_id', p_alert_id::text, 'status', p_status);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_sos_alerts(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_resolve_sos_alert(UUID, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_list_sos_alerts(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_resolve_sos_alert(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_sos_alerts(TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_resolve_sos_alert(UUID, TEXT, TEXT) TO service_role;