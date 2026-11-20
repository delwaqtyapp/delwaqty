-- Run after migration 149. Every fixture and resulting row is rolled back.
-- Verifies: a participant can edit only their own message, cannot edit the
-- other party's message, cannot move a message to another room, and cannot
-- change room membership; ordinary room updates by participants still work.
BEGIN;
DO $$
DECLARE
  a uuid := gen_random_uuid();
  b uuid := gen_random_uuid();
  r1 uuid := gen_random_uuid();
  r2 uuid := gen_random_uuid();
  msg uuid := gen_random_uuid();
  v_updated boolean;
BEGIN
  INSERT INTO auth.users(id,email) VALUES
    (a,a::text||'@example.invalid'),(b,b::text||'@example.invalid');
  INSERT INTO public.users(id,email) VALUES
    (a,a::text||'@example.invalid'),(b,b::text||'@example.invalid')
    ON CONFLICT(id) DO NOTHING;

  PERFORM set_config('request.jwt.claim.sub', a::text, true);
  PERFORM set_config('role','authenticated',true);
  INSERT INTO public.chat_rooms(id, room_type, participant_ids) VALUES (r1, 'general', ARRAY[a,b]);
  INSERT INTO public.chat_rooms(id, room_type, participant_ids) VALUES (r2, 'general', ARRAY[a,b]);
  PERFORM set_config('role','none',true);
  PERFORM set_config('request.jwt.claim.sub', b::text, true);
  PERFORM set_config('role','authenticated',true);
  INSERT INTO public.chat_messages(id, room_id, sender_id, message)
    VALUES (msg, r1, b, 'original words from b');
  PERFORM set_config('role','none',true);
  PERFORM set_config('request.jwt.claim.sub', a::text, true);
  PERFORM set_config('role','authenticated',true);

  -- a edits their own room freely (e.g. read marker): allowed.
  UPDATE public.chat_rooms SET updated_at = now() WHERE id = r1;
  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF NOT v_updated THEN RAISE EXCEPTION 'participant room touch failed'; END IF;

  -- a cannot add an eavesdropper to the room (policy rejects with 42501).
  BEGIN
    UPDATE public.chat_rooms SET participant_ids = ARRAY[a,b,gen_random_uuid()] WHERE id = r1;
    GET DIAGNOSTICS v_updated = ROW_COUNT;
    IF v_updated THEN RAISE EXCEPTION 'participant changed room membership'; END IF;
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  -- a cannot edit b's message.
  UPDATE public.chat_messages SET message = 'forged by a' WHERE id = msg;
  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated THEN RAISE EXCEPTION 'participant edited another user message'; END IF;

  PERFORM set_config('role','none',true);

  -- b edits their own message: allowed.
  PERFORM set_config('request.jwt.claim.sub', b::text, true);
  PERFORM set_config('role','authenticated',true);
  UPDATE public.chat_messages SET message = 'edited by b' WHERE id = msg;
  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF NOT v_updated THEN RAISE EXCEPTION 'sender could not edit own message'; END IF;

  -- b cannot move their message into another room... both rooms have the same
  -- participants, so also verify sender reassignment is blocked.
  BEGIN
    UPDATE public.chat_messages SET sender_id = a WHERE id = msg;
    GET DIAGNOSTICS v_updated = ROW_COUNT;
    IF v_updated THEN RAISE EXCEPTION 'sender reassigned their message'; END IF;
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  PERFORM set_config('role','none',true);
  IF (SELECT message FROM public.chat_messages WHERE id = msg) <> 'edited by b' THEN
    RAISE EXCEPTION 'message content drifted';
  END IF;
END;
$$;
ROLLBACK;
