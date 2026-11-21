-- 094: Chat room reference number + owner-delete + expired auto-purge
--
-- Adds:
--   1. chat_rooms.reference_number  -> human-facing ticket number (DWQ-<seq>)
--   2. admin_delete_chat(room_id)   -> HARD delete room + messages + storage (OWNER ONLY)
--   3. admin_purge_expired_chats()  -> hard-delete rooms past auto_delete_at (ADMIN; owner incl.)
-- Every closed chat gets auto_delete_at = now()+7d in closeRoom, so this
-- purge realizes the "auto-delete after one week unless deleted" rule.

CREATE SEQUENCE IF NOT EXISTS public.chat_reference_seq START 1000;

ALTER TABLE public.chat_rooms
  ADD COLUMN IF NOT EXISTS reference_number text;

-- Fill any existing rows then make it auto-assigned.
UPDATE public.chat_rooms
SET reference_number = 'DWQ-' || (1000 + rn)
FROM (
  SELECT id, row_number() OVER (ORDER BY created_at) AS rn
  FROM public.chat_rooms
) sub
WHERE public.chat_rooms.id = sub.id
  AND (public.chat_rooms.reference_number IS NULL OR public.chat_rooms.reference_number = '');

CREATE OR REPLACE FUNCTION public.next_chat_reference()
RETURNS text
LANGUAGE sql
SECURITY INVOKER
STABLE
AS $$
  SELECT 'DWQ-' || nextval('public.chat_reference_seq')::text;
$$;

-- Owner-only hard delete: room + its messages + its attachments in storage.
CREATE OR REPLACE FUNCTION public.admin_delete_chat(p_room_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_role text;
BEGIN
  SELECT role INTO v_role FROM public.users WHERE id = auth.uid();
  IF v_role IS DISTINCT FROM 'owner' THEN
    RAISE EXCEPTION 'Only an owner can delete a chat';
  END IF;

  DELETE FROM public.chat_messages WHERE room_id = p_room_id;
  DELETE FROM storage.objects
    WHERE bucket_id = 'chat_attachments'
      AND name LIKE p_room_id::text || '/%';
  DELETE FROM public.chat_rooms WHERE id = p_room_id;
END;
$$;

-- Auto-purge: hard-delete every chat whose auto_delete_at has elapsed.
CREATE OR REPLACE FUNCTION public.admin_purge_expired_chats()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_expired integer;
DECLARE r RECORD;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Admins only';
  END IF;

  SELECT count(*) INTO v_expired
    FROM public.chat_rooms
    WHERE auto_delete_at IS NOT NULL AND auto_delete_at <= now();

  FOR r IN
    SELECT id FROM public.chat_rooms
    WHERE auto_delete_at IS NOT NULL AND auto_delete_at <= now()
  LOOP
    DELETE FROM public.chat_messages WHERE room_id = r.id;
    DELETE FROM storage.objects
      WHERE bucket_id = 'chat_attachments'
        AND name LIKE r.id::text || '/%';
    DELETE FROM public.chat_rooms WHERE id = r.id;
  END LOOP;

  RETURN v_expired;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_delete_chat(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_delete_chat(uuid) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.admin_purge_expired_chats() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_purge_expired_chats() TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.next_chat_reference() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.next_chat_reference() TO authenticated, service_role;