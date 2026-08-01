-- 019_push_broadcast_device_count.sql
-- Upgrade the admin broadcast RPC to return the number of DEVICES
-- (notification_tokens rows) belonging to the matched recipients,
-- so the admin dashboard can show "how many devices received".
--
-- The RPC still inserts one notifications row per matching USER; each
-- matching device (token) of those users receives it in-app via
-- Supabase Realtime. The return value is now the device count.
--
-- Idempotent: safe to re-run in a SQL editor or via Management API.

CREATE OR REPLACE FUNCTION public.admin_broadcast_notification(
  p_title TEXT,
  p_body TEXT,
  p_type TEXT DEFAULT 'info',
  p_deep_link TEXT DEFAULT NULL,
  p_target_role TEXT DEFAULT NULL,
  p_target_user_id UUID DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  matched_ids uuid[];
  device_count INTEGER;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT array_agg(u.id) INTO matched_ids
  FROM public.users u
  WHERE (p_target_user_id IS NULL OR u.id = p_target_user_id)
    AND (p_target_role IS NULL OR u.role = p_target_role);

  IF matched_ids IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, title, body, type, data, is_read)
    SELECT
      unnest(matched_ids),
      p_title,
      p_body,
      p_type,
      CASE
        WHEN p_deep_link IS NULL THEN NULL
        ELSE jsonb_build_object('deep_link', p_deep_link)
      END,
      false;
  END IF;

  SELECT COUNT(*) INTO device_count
  FROM public.notification_tokens t
  WHERE t.user_id = ANY(matched_ids);

  RETURN device_count;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_broadcast_notification(TEXT, TEXT, TEXT, TEXT, TEXT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_broadcast_notification(TEXT, TEXT, TEXT, TEXT, TEXT, UUID) TO authenticated;
