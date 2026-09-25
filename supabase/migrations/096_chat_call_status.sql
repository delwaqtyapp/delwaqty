-- 096: Call-state RPC — update the SAME call message rows' meta_data.status
-- instead of appending a new message per accept/decline, so both sides see
-- ringing -> accepted/declined/ended instantly on the single bubble.
--
-- Session identity follows the APP the user is running (customer app = customer,
-- admin app = admin), so `sender_type`/`is_from_admin` are decided on the client.

CREATE OR REPLACE FUNCTION public.chat_set_call_status(
  p_message_id uuid,
  p_status text,
  p_responder_id uuid DEFAULT NULL,
  p_responder_type text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_room_id uuid;
  v_participants uuid[];
BEGIN
  SELECT room_id, (SELECT cr.participant_ids FROM public.chat_rooms cr WHERE cr.id = m.room_id)
    INTO v_room_id, v_participants
  FROM public.chat_messages m
  WHERE m.id = p_message_id;

  IF v_room_id IS NULL THEN
    RAISE EXCEPTION 'message not found';
  END IF;

  -- Caller must be a participant of the room (or an admin/owner).
  IF NOT (p_responder_id IS NOT NULL
          AND (auth.uid() = ANY(v_participants)
               OR (SELECT role FROM public.users WHERE id = auth.uid()) IN ('admin', 'owner'))) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.chat_messages
  SET meta_data = COALESCE(meta_data, '{}'::jsonb)
                  || jsonb_build_object(
                       'status', p_status,
                       'responder_id', p_responder_id,
                       'responder_type', p_responder_type,
                       'responded_at', now()::text
                     )
  WHERE id = p_message_id;
END;
$$;

REVOKE ALL ON FUNCTION public.chat_set_call_status(uuid, text, uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.chat_set_call_status(uuid, text, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chat_set_call_status(uuid, text, uuid, text) TO service_role;