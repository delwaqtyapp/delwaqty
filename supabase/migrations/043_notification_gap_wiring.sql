-- ============================================================
-- 043 — Notification gaps: support close, complaint notes,
--        SOS resolution + member_events lifecycle wiring
-- ============================================================
-- Nightly full-platform build, STEP 7/8.
--
-- Patches 3 RPCs that silently mutate state without notifying:
--   1. close_support_chat  (033)  → notify customer + admins
--   2. add_admin_note      (016)  → notify complainant
--   3. resolve_sos_alert   (029)  → notify the user who triggered
--
-- Also wires member_events inserts for complaint + SOS lifecycle.
-- All notification inserts follow the 041 idempotency pattern.
--
-- Idempotent / additive. CREATE OR REPLACE preserves return types.
-- ============================================================

BEGIN;

-- ─── 1. close_support_chat — notify customer ─────────────────
-- Original: 033 line 649-679. Adds notification + member_events.

CREATE OR REPLACE FUNCTION public.close_support_chat(p_room_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_admin    uuid := auth.uid();
  v_customer uuid;
  v_room     public.chat_rooms%ROWTYPE;
BEGIN
  SELECT * INTO v_room FROM public.chat_rooms WHERE id = p_room_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Room not found';
  END IF;

  IF NOT (public.is_admin()
          OR v_admin = ANY (v_room.participant_ids)) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT cp.user_id INTO v_customer
    FROM public.chat_participants cp
   WHERE cp.room_id = p_room_id
     AND cp.user_id != v_admin
     AND cp.role = 'customer'
   LIMIT 1;

  UPDATE public.chat_rooms
     SET status = 'closed', closed_at = now(), is_active = false
   WHERE id = p_room_id;

  PERFORM public.write_audit(
    'SUPPORT_CLOSED', 'chat_rooms', p_room_id::text,
    jsonb_build_object('priority', v_room.priority, 'assigned_admin_id', v_room.assigned_admin_id)
  );

  IF v_customer IS NOT NULL THEN
    INSERT INTO public.notifications
      (user_id, title, body, type, data, deep_link, idempotency_key,
       sender_id, priority, send_push)
    VALUES
      (v_customer,
       'Chat Closed',
       'Your support chat has been closed. If you need further help, open a new chat.',
       'chat_closed',
       jsonb_build_object('entity_type', 'chat_room', 'entity_id', p_room_id::text, 'action', 'closed'),
       '/support/room/' || p_room_id::text,
       'chat-closed-' || p_room_id::text || '-' || v_customer::text,
       v_admin, 'normal', true)
    ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;

    INSERT INTO public.member_events (user_id, event_type, payload)
    VALUES (v_customer, 'support_resolved',
            jsonb_build_object('room_id', p_room_id::text, 'closed_by', 'admin'))
    ON CONFLICT DO NOTHING;
  END IF;

  INSERT INTO public.member_events (user_id, event_type, payload)
  VALUES (v_admin, 'support_resolved',
          jsonb_build_object('room_id', p_room_id::text, 'customer_id', v_customer::text))
  ON CONFLICT DO NOTHING;
END;
$$;

-- ─── 2. add_admin_note — notify complainant ──────────────────
-- Original: 016 (add_admin_note) + add_complaint_admin_note wrapper.
-- We patch the inner add_admin_note to also send notification + events.

CREATE OR REPLACE FUNCTION public.add_admin_note(
  p_complaint_id uuid,
  p_note text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_admin       uuid := auth.uid();
  v_complainant uuid;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT complainant_id INTO v_complainant
    FROM public.complaints
   WHERE id = p_complaint_id;

  UPDATE complaints
  SET admin_notes = array_append(COALESCE(admin_notes, '{}'), p_note),
      updated_at = NOW()
  WHERE id = p_complaint_id;

  IF v_complainant IS NOT NULL THEN
    INSERT INTO public.notifications
      (user_id, title, body, type, data, deep_link, idempotency_key,
       sender_id, priority, send_push)
    VALUES
      (v_complainant,
       'Admin Note Added',
       'An administrator has added a note to your complaint.',
       'complaint_note',
       jsonb_build_object('entity_type', 'complaint', 'entity_id', p_complaint_id::text, 'action', 'admin_note'),
       '/my-complaints',
       'complaint-note-' || p_complaint_id::text || '-' || now()::text,
       v_admin, 'normal', true)
    ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;

    INSERT INTO public.member_events (user_id, event_type, payload)
    VALUES (v_complainant, 'complaint_created',
            jsonb_build_object('complaint_id', p_complaint_id::text, 'action', 'admin_note'))
    ON CONFLICT DO NOTHING;
  END IF;
END;
$$;

-- ─── 3. resolve_sos_alert — notify triggering user ───────────
-- Original: 029 line 134-155. Returns JSONB. We preserve return type.

CREATE OR REPLACE FUNCTION public.resolve_sos_alert(
  p_alert_id uuid,
  p_status text DEFAULT 'resolved'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_resolver uuid := auth.uid();
  v_owner    uuid;
  v_alert    record;
BEGIN
  IF v_resolver IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_authenticated');
  END IF;

  SELECT sa.*, u.id AS user_id INTO v_alert
    FROM public.sos_alerts sa
    JOIN public.users u ON u.id = sa.user_id
   WHERE sa.id = p_alert_id;

  IF v_alert IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'alert_not_found');
  END IF;

  IF v_alert.status != 'active' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'alert_not_active');
  END IF;

  v_owner := v_alert.user_id;

  UPDATE public.sos_alerts
     SET status     = p_status,
         resolved_at = now()
   WHERE id = p_alert_id;

  INSERT INTO public.notifications
    (user_id, title, body, type, data, deep_link, idempotency_key,
     sender_id, priority, send_push)
  VALUES
    (v_owner,
     'SOS Alert Resolved',
     'Your SOS alert has been marked as ' || p_status || '.',
     'emergency_resolved',
     jsonb_build_object('entity_type', 'sos_alert', 'entity_id', p_alert_id::text, 'action', p_status),
     '/safety',
     'sos-resolved-' || p_alert_id::text || '-' || v_owner::text,
     v_resolver, 'high', true)
  ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;

  INSERT INTO public.member_events (user_id, event_type, payload)
  VALUES (v_owner, 'emergency_resolved',
          jsonb_build_object('alert_id', p_alert_id::text, 'resolved_by', v_resolver::text, 'status', p_status))
  ON CONFLICT DO NOTHING;

  INSERT INTO public.member_events (user_id, event_type, payload)
  VALUES (v_resolver, 'emergency_resolved',
          jsonb_build_object('alert_id', p_alert_id::text, 'owner_id', v_owner::text, 'status', p_status))
  ON CONFLICT DO NOTHING;

  RETURN jsonb_build_object('success', true, 'alert_id', p_alert_id, 'status', p_status);
END;
$$;

COMMIT;
