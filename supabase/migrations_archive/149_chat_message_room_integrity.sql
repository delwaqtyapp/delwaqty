-- 149: chat integrity - participants could rewrite each other's messages and
-- mutate room membership.
--
-- "users update own room messages" allowed ANY room participant to UPDATE ANY
-- message in the room, including the other party's text and sender_id: a
-- customer could edit a merchant's words and the history would show them as
-- the merchant's own. Updates are now limited to the message's own sender,
-- and the sender/room binding cannot be moved.
--
-- "users update own rooms" allowed a participant to UPDATE the room row,
-- including participant_ids - adding an eavesdropper to a private room or
-- removing the other party. Membership is now frozen under the participant
-- policy; admins keep their full-access policies.
BEGIN;

DROP POLICY IF EXISTS "users update own room messages" ON public.chat_messages;
CREATE POLICY "users update own room messages" ON public.chat_messages
  FOR UPDATE TO public
  USING (sender_id = auth.uid() AND EXISTS (
    SELECT 1 FROM public.chat_rooms
    WHERE chat_rooms.id = chat_messages.room_id
      AND auth.uid() = ANY (chat_rooms.participant_ids)))
  WITH CHECK (sender_id = auth.uid() AND EXISTS (
    SELECT 1 FROM public.chat_rooms
    WHERE chat_rooms.id = chat_messages.room_id
      AND auth.uid() = ANY (chat_rooms.participant_ids)));

DROP POLICY IF EXISTS "users update own rooms" ON public.chat_rooms;
CREATE POLICY "users update own rooms" ON public.chat_rooms
  FOR UPDATE TO public
  USING (auth.uid() = ANY (participant_ids))
  WITH CHECK (
    auth.uid() = ANY (participant_ids)
    AND participant_ids = (SELECT r.participant_ids FROM public.chat_rooms r WHERE r.id = chat_rooms.id)
  );

NOTIFY pgrst, 'reload schema';
COMMIT;
