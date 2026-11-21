-- 095: Chat typing indicator
--
-- Lightweight realtime typing status per (room, user). RLS:
--   SELECT  -> participants of the room or admins
--   INSERT  -> the user's own row (any participant)
--   UPDATE  -> the user's own row
-- Consumers listen via a realtime stream (chat_typing table).

CREATE TABLE IF NOT EXISTS public.chat_typing (
  room_id uuid NOT NULL REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  is_typing boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (room_id, user_id)
);

ALTER TABLE public.chat_typing ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "typing select room participants" ON public.chat_typing;
CREATE POLICY "typing select room participants" ON public.chat_typing
  FOR SELECT TO authenticated
  USING (
    public.is_admin()
    OR (
      room_id IN (
        SELECT cr.id FROM public.chat_rooms cr
        WHERE auth.uid() = ANY (cr.participant_ids)
      )
    )
  );

DROP POLICY IF EXISTS "typing insert own" ON public.chat_typing;
CREATE POLICY "typing insert own" ON public.chat_typing
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "typing update own" ON public.chat_typing;
CREATE POLICY "typing update own" ON public.chat_typing
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "typing admin delete" ON public.chat_typing;
CREATE POLICY "typing admin delete" ON public.chat_typing
  FOR DELETE TO authenticated
  USING (public.is_admin());

ALTER TABLE public.chat_typing REPLICA IDENTITY FULL;