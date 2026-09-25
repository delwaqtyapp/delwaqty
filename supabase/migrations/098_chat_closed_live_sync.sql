-- 098_chat_closed_live_sync.sql
-- Fixes two LIVE bugs reported after sprint 194:
--  (1) Closing a chat from the admin app did NOT propagate to the customer in
--      real time (no Realtime stream carried the is_active flip) AND the
--      customer could keep sending after the room was closed.
--  (2) The admin/customer received no actionable incoming-call UI outside the
--      open room screen; the app-wide alert service also skipped subscription
--      entirely when auth was not yet ready at app start (fixed on the app
--      side in chat_call_alert_service.dart + chat_providers.dart).
--
-- This migration makes the live sync possible and enforces closure server-side:
--  * REPLICA IDENTITY FULL on chat_rooms + chat_messages: every UPDATE/DELETE
--    (is_active flips, call status meta_data merges) is broadcast with the FULL
--    row, which Realtime needs for reliable filtered change streams.
--  * A BEFORE INSERT trigger on chat_messages rejects any send to a CLOSED
--    room, so a post-close message fails server-side with a clear error
--    instead of silently landing.

ALTER TABLE public.chat_rooms
  REPLICA IDENTITY FULL;

ALTER TABLE public.chat_messages
  REPLICA IDENTITY FULL;

CREATE OR REPLACE FUNCTION public.chat_ensure_room_active()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_active boolean;
BEGIN
  SELECT is_active INTO v_active
    FROM public.chat_rooms
   WHERE id = NEW.room_id;
  IF v_active IS FALSE THEN
    RAISE EXCEPTION 'chat room is closed';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_chat_ensure_room_active ON public.chat_messages;
CREATE TRIGGER trg_chat_ensure_room_active
  BEFORE INSERT ON public.chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.chat_ensure_room_active();