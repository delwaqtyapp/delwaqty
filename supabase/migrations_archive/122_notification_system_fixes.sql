-- Migration 122: Notification System Fixes
-- 1. Ensure /safety destination is allowed in notification_destinations
-- 2. Fix admin_broadcast_notification to only count active device tokens (is_active = true)

INSERT INTO public.notification_destinations (route_prefix, description)
VALUES ('/safety', 'Safety & SOS resolution screen')
ON CONFLICT (route_prefix) DO NOTHING;

CREATE OR REPLACE FUNCTION public.admin_broadcast_notification(
  p_title text,
  p_body text,
  p_target_role text DEFAULT NULL,
  p_type text DEFAULT 'system',
  p_deep_link text DEFAULT NULL,
  p_data jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_is_admin boolean := false;
  v_inserted_count integer := 0;
  v_device_count integer := 0;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = v_caller_id
      AND u.user_type IN ('admin', 'owner', 'super_admin')
  ) INTO v_is_admin;

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Admin privileges required';
  END IF;

  PERFORM set_config('app.notify_dispatch', 'true', true);

  WITH target_users AS (
    SELECT u.id
    FROM public.users u
    WHERE u.is_active = true
      AND (
        p_target_role IS NULL
        OR p_target_role = ''
        OR p_target_role = 'all'
        OR u.user_type = p_target_role
      )
  ),
  inserted AS (
    INSERT INTO public.notifications (
      user_id,
      title,
      body,
      type,
      deep_link,
      data,
      sender_id,
      send_push
    )
    SELECT
      tu.id,
      p_title,
      p_body,
      COALESCE(NULLIF(p_type, ''), 'system'),
      p_deep_link,
      COALESCE(p_data, '{}'::jsonb),
      v_caller_id,
      true
    FROM target_users tu
    RETURNING user_id
  )
  SELECT
    COUNT(*),
    (
      SELECT COUNT(*)
      FROM public.notification_tokens nt
      WHERE nt.user_id IN (SELECT user_id FROM inserted)
        AND nt.is_active = true
    )
  INTO v_inserted_count, v_device_count
  FROM inserted;

  RETURN jsonb_build_object(
    'sent_count', v_inserted_count,
    'device_count', v_device_count
  );
END;
$$;
