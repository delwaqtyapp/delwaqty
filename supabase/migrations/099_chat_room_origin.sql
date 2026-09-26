-- 099: Chat room ORIGIN identity + server-authoritative tagging
--
-- Every chat must be instantly recognizable in the admin panel by WHO opened
-- it (customer / driver / provider / admin) plus — for providers — the
-- service or merchant type, so "understanding the admin dashboard" works on
-- ALL platforms (customer, driver, provider, admin) at once.
--
-- Added:
--   1. chat_rooms.origin_type  -> 'customer' | 'driver' | 'provider' | 'admin'
--   2. chat_rooms.origin_label -> for providers: home-services category_type
--                                 or commerce merchants.type (human type key)
--   3. chat_room_origin() BEFORE INSERT trigger -> AUTHORITATIVE tag derived
--                                 from auth.uid(), NEVER trusted from client
--   4. reference_number DEFAULT pinned in-repo (next_chat_reference()) so a
--                                 freshly created chat ALWAYS gets a brand-new
--                                 DWQ-<seq> number — even after the previous
--                                 chat was closed by the admin.
--   5. Backfill of existing rooms from their originating participant.

ALTER TABLE public.chat_rooms
  ADD COLUMN IF NOT EXISTS origin_type text NOT NULL DEFAULT 'customer',
  ADD COLUMN IF NOT EXISTS origin_label text;

-- Reproducible default: every NEW room = new human-facing DWQ number.
-- (Already live on prod; pinned here so fresh DBs behave identically.)
ALTER TABLE public.chat_rooms
  ALTER COLUMN reference_number SET DEFAULT public.next_chat_reference();

-- Server-authoritative origin. Recomputes from the ACTUAL authenticated user
-- (auth.uid()) on every insert; a client can never spoof its own role.
CREATE OR REPLACE FUNCTION public.chat_room_origin()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid;
  v_role text;
  v_label text;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    v_uid := NEW.participant_ids[1];
  END IF;

  SELECT role INTO v_role FROM public.users WHERE id = v_uid;

  CASE
    WHEN v_role IN ('admin', 'owner') THEN NEW.origin_type := 'admin';
    WHEN v_role IN ('driver', 'delivery') THEN NEW.origin_type := 'driver';
    WHEN v_role IN ('provider', 'merchant') THEN NEW.origin_type := 'provider';
    ELSE NEW.origin_type := 'customer';
  END CASE;

  IF NEW.origin_type = 'provider' THEN
    v_label := NULL;
    SELECT category_type INTO v_label
      FROM public.service_providers
      WHERE user_id = v_uid
      ORDER BY created_at
      LIMIT 1;
    IF v_label IS NULL THEN
      SELECT type INTO v_label
        FROM public.merchants
        WHERE owner_user_id = v_uid
        ORDER BY created_at
        LIMIT 1;
    END IF;
    NEW.origin_label := v_label;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_chat_room_origin ON public.chat_rooms;
CREATE TRIGGER trg_chat_room_origin
  BEFORE INSERT ON public.chat_rooms
  FOR EACH ROW EXECUTE FUNCTION public.chat_room_origin();

-- Backfill existing rooms from their FIRST participant (the room creator on
-- every platform that built rooms so far). Only rooms still at the untouched
-- 'customer' default get rewritten.
UPDATE public.chat_rooms cr
SET origin_type = CASE u.role
        WHEN 'admin' THEN 'admin'
        WHEN 'owner' THEN 'admin'
        WHEN 'driver' THEN 'driver'
        WHEN 'delivery' THEN 'driver'
        WHEN 'provider' THEN 'provider'
        WHEN 'merchant' THEN 'provider'
        ELSE 'customer'
      END,
    origin_label = CASE
      WHEN u.role IN ('provider', 'merchant') THEN COALESCE(
        (SELECT sp.category_type FROM public.service_providers sp
          WHERE sp.user_id = cr.participant_ids[1] ORDER BY sp.created_at LIMIT 1),
        (SELECT m.type FROM public.merchants m
          WHERE m.owner_user_id = cr.participant_ids[1] ORDER BY m.created_at LIMIT 1)
      )
      ELSE NULL
    END
FROM public.users u
WHERE u.id = cr.participant_ids[1]
  AND cr.origin_type = 'customer';

GRANT EXECUTE ON FUNCTION public.chat_room_origin() TO authenticated, service_role;