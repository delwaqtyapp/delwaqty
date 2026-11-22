-- 376: support-chat purge moves off admin screen-load to a nightly cron.
-- The RPC was gated to country admins and ran on every admin rooms-list
-- load; it is now owner/service-only and scheduled via pg_cron.

CREATE OR REPLACE FUNCTION public.admin_purge_expired_chats()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_expired integer;
DECLARE r RECORD;
BEGIN
  -- Owner via API, or server-side callers (pg_cron / service_role) where
  -- auth.uid() is NULL. Everyone else is denied.
  IF auth.uid() IS NOT NULL AND NOT public._is_owner_uid(auth.uid()) THEN
    RAISE EXCEPTION 'Owner only';
  END IF;

  SELECT count(*) INTO v_expired
    FROM public.chat_rooms
    WHERE auto_delete_at IS NOT NULL AND auto_delete_at <= now();

  FOR r IN
    SELECT id FROM public.chat_rooms
    WHERE auto_delete_at IS NOT NULL AND auto_delete_at <= now()
  LOOP
    DELETE FROM public.chat_messages WHERE room_id = r.id;
    -- storage.objects rows cannot be deleted from SQL (Supabase trigger
    -- blocks direct deletes); attachments stay orphaned in the private
    -- chat_attachments bucket until a service-key Storage API sweep exists.
    DELETE FROM public.chat_rooms WHERE id = r.id;
  END LOOP;

  RETURN v_expired;
END;
$function$;

SELECT cron.schedule('purge-expired-chats', '17 3 * * *', $cron$SELECT public.admin_purge_expired_chats();$cron$);
