-- 422 regression: chat tables run REPLICA IDENTITY DEFAULT so DELETE events
-- carry only the PK, and chat_messages stays in the publication. Second
-- block: two-participant runtime lifecycle proof on staging (room create ->
-- message -> typing -> edit -> close/assign by admin -> admin delete),
-- including non-participant isolation. SQL-level only: websocket delivery
-- itself is not measured here (no WS client in this environment).
BEGIN;
DO $$
BEGIN
  ASSERT (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
           WHERE n.nspname='public' AND c.relname IN ('chat_messages','chat_rooms','chat_typing')
             AND c.relreplident = 'd') = 3,
    '422: a chat table is not REPLICA IDENTITY DEFAULT';
  ASSERT EXISTS (SELECT 1 FROM pg_publication_tables
                  WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='chat_messages'),
    '422: chat_messages fell out of the publication';
END $$;

DO $$
DECLARE
  a uuid := gen_random_uuid(); b uuid := gen_random_uuid(); m uuid := gen_random_uuid();
  v_region uuid := '905b0ccc-f2ed-5306-b661-233b49edd400';
  v_room uuid := gen_random_uuid(); v_msg uuid := gen_random_uuid();
  v_n integer; v_err text; -- b doubles as the supervisor user (FK target only)
BEGIN
  INSERT INTO auth.users(id,email) VALUES (a,a::text||'@x.i'),(b,b::text||'@x.i'),(m,m::text||'@x.i');
  -- an auth.users trigger pre-creates public.users rows with the default
  -- role; force the intended roles.
  INSERT INTO public.users(id,email,role) VALUES (a,a::text||'@x.i','customer'),(b,b::text||'@x.i','customer'),(m,m::text||'@x.i','admin')
    ON CONFLICT(id) DO UPDATE SET role = EXCLUDED.role;
  INSERT INTO public.admin_management(admin_id,supervisor_id,is_active) VALUES (m,b,true);
  GET DIAGNOSTICS v_n = ROW_COUNT; ASSERT v_n = 1, '422: admin fixture not created';
  INSERT INTO public.admin_region_assignments(admin_id,region_id,scope) VALUES (m,v_region,'self');

  -- participant A: open room, send, type, edit own message
  PERFORM set_config('role','authenticated',true);
  PERFORM set_config('request.jwt.claim.sub', a::text, true);
  INSERT INTO public.chat_rooms(id, room_type, participant_ids, region_id, is_active, status)
  VALUES (v_room,'support',ARRAY[a],v_region,true,'open');
  INSERT INTO public.chat_messages(id, room_id, sender_id, message, message_type, is_from_admin)
  VALUES (v_msg, v_room, a, 'hello', 'text', false);
  INSERT INTO public.chat_typing(room_id, user_id, is_typing) VALUES (v_room, a, true);
  UPDATE public.chat_typing SET is_typing=false WHERE room_id=v_room AND user_id=a;
  GET DIAGNOSTICS v_n = ROW_COUNT; ASSERT v_n = 1, '422: typing update failed';
  UPDATE public.chat_messages SET message='hello edited' WHERE id=v_msg;
  GET DIAGNOSTICS v_n = ROW_COUNT; ASSERT v_n = 1, '422: participant edit failed';

  -- non-participant B: no read, no edit, no delete, no insert
  PERFORM set_config('request.jwt.claim.sub', b::text, true);
  ASSERT NOT EXISTS (SELECT 1 FROM public.chat_messages WHERE room_id=v_room), '422: non-participant sees messages';
  UPDATE public.chat_messages SET message='hijack' WHERE id=v_msg;
  GET DIAGNOSTICS v_n = ROW_COUNT; ASSERT v_n = 0, '422: non-participant edited message';
  DELETE FROM public.chat_messages WHERE id=v_msg;
  GET DIAGNOSTICS v_n = ROW_COUNT; ASSERT v_n = 0, '422: non-participant deleted message';
  BEGIN
    INSERT INTO public.chat_messages(room_id, sender_id, message) VALUES (v_room, b, 'intrude');
    v_err := 'NO_ERROR';
  EXCEPTION WHEN OTHERS THEN
    v_err := SQLERRM;
  END;
  ASSERT v_err ILIKE '%row-level security%' OR v_err ILIKE '%row security%' OR v_err ILIKE '%policy%',
    '422: non-participant insert not RLS-denied: ' || COALESCE(v_err,'');

  -- admin M (regional, room region assigned): read, assign, close, delete
  PERFORM set_config('request.jwt.claim.sub', m::text, true);
  ASSERT EXISTS (SELECT 1 FROM public.chat_messages WHERE id=v_msg), '422: admin cannot read room';
  UPDATE public.chat_rooms SET assigned_admin_id=m, assigned_at=now(), status='assigned' WHERE id=v_room;
  GET DIAGNOSTICS v_n = ROW_COUNT; ASSERT v_n = 1, '422: admin assignment failed';
  UPDATE public.chat_rooms SET is_active=false, closed_at=now(), status='closed' WHERE id=v_room;
  GET DIAGNOSTICS v_n = ROW_COUNT; ASSERT v_n = 1, '422: admin close failed';
  DELETE FROM public.chat_messages WHERE id=v_msg;
  GET DIAGNOSTICS v_n = ROW_COUNT; ASSERT v_n = 1, '422: admin delete failed';

  PERFORM set_config('role','none',true);
  ASSERT NOT EXISTS (SELECT 1 FROM public.chat_messages WHERE id=v_msg), '422: message not deleted';
END $$;
SELECT '422 assertions + lifecycle proof passed' AS result;
ROLLBACK;
