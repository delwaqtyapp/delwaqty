-- 041_notification_delivery_layer.sql
-- Phase 2.4.1 (ADR-062 / HANDOFF-34): notification delivery layer.
--
-- Purely ADDITIVE. Does NOT modify 030/031/032/033/034/035/038/039/040.
-- Idempotent: safe to re-run (IF NOT EXISTS / CREATE OR REPLACE /
-- DROP TRIGGER IF EXISTS).
--
-- Adds:
--   1. notifications enrichment columns: priority / sender_id / send_push /
--      push_status / push_sent_at / push_error (+ partial index).
--   2. notification_destinations — server-side deep-link allowlist + seeds.
--   3. notification_push_config — service_role-only edge-function config
--      (NOT platform_settings, which is PUBLIC-readable). No secrets in code.
--   4. Device-scoped FCM token RPCs: register_device_token /
--      deactivate_device_tokens / refresh_token_heartbeat / cleanup_invalid_token.
--   5. Dispatch path: notify_notification_push (AFTER INSERT notifications →
--      pg_net → send-push edge function; graceful unconfigured no-op) +
--      dispatch_push backstop + shared _enqueue_push.
--   6. Security hardening: guard_notifications_user_update (read-state-only
--      UPDATE for non-admins), hardened get_unread_notification_count /
--      deactivate_stale_tokens (search_path + authz), anon EXECUTE revoked on
--      notification RPCs, anon table grants revoked on notification_tokens.
--   7. Automated source notifications (all via triggers, no writer edits):
--      notify_chat_message_reply (support chat, turn-based),
--      notify_complaint_notifications (new complaint → admins;
--      status change → complainant/reporter),
--      notify_sos_alert (emergency → in-scope admins; contacts are external
--      phone/email records, not app users, so no in-app row for them).
--   8. Additive campaigns RLS policy so customers can open /campaign/:id
--      (published + within schedule window only). "campaigns admin select"
--      untouched.
--
-- Realtime: reuses existing supabase_realtime publication of notifications
-- (verified). No table removed; notification_tokens stays unpublished.

-- ============================================================
-- 1. notifications enrichment columns (guarded backfill)
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'notifications'
      AND column_name = 'push_status'
  ) THEN
    ALTER TABLE public.notifications
      ADD COLUMN priority text NOT NULL DEFAULT 'normal',
      ADD COLUMN sender_id uuid,
      ADD COLUMN send_push boolean NOT NULL DEFAULT true,
      ADD COLUMN push_status text NOT NULL DEFAULT 'pending',
      ADD COLUMN push_sent_at timestamptz,
      ADD COLUMN push_error text;

    ALTER TABLE public.notifications
      ADD CONSTRAINT notifications_priority_check
        CHECK (priority IN ('low','normal','high')),
      ADD CONSTRAINT notifications_push_status_check
        CHECK (push_status IN ('pending','sent','failed','unconfigured'));

    -- Existing rows predate the push pipeline: mark them unconfigured so the
    -- AFTER INSERT trigger never enqueues historical notifications.
    UPDATE public.notifications
       SET push_status = 'unconfigured'
     WHERE push_status = 'pending';
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_notifications_user_push_status
  ON public.notifications (user_id, push_status)
  WHERE push_status IN ('pending','failed');

COMMENT ON COLUMN public.notifications.priority IS
  'low|normal|high. high = emergency/escalation (priority chip + high FCM).';
COMMENT ON COLUMN public.notifications.send_push IS
  'false suppresses the push pipeline for this row (in-app/realtime still works).';
COMMENT ON COLUMN public.notifications.push_status IS
  'State machine pending -> sent|failed|unconfigured. unconfigured = no FCM creds configured (graceful no-op; realtime still delivers).';

-- ============================================================
-- 2. notification_destinations (server deep-link allowlist)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.notification_destinations (
  route_pattern text PRIMARY KEY,
  description text,
  allowed_roles text[],
  is_active boolean NOT NULL DEFAULT true
);

COMMENT ON TABLE public.notification_destinations IS
  'Deep-link allowlist consumed by validate_notification_deep_link (server) '
  'and mirrored by the client resolver. Segments prefixed with ":" are '
  'parameterized (match any single segment). NULL allowed_roles = any role.';

ALTER TABLE public.notification_destinations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "destinations authenticated read" ON public.notification_destinations;
CREATE POLICY "destinations authenticated read" ON public.notification_destinations
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "destinations service role all" ON public.notification_destinations;
CREATE POLICY "destinations service role all" ON public.notification_destinations
  FOR ALL TO service_role USING (true) WITH CHECK (true);

GRANT SELECT ON public.notification_destinations TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.notification_destinations TO service_role;

INSERT INTO public.notification_destinations (route_pattern, description, allowed_roles, is_active)
VALUES
  ('/notifications', 'Notification Center', NULL, true),
  ('/profile', 'Profile', NULL, true),
  ('/rewards', 'Rewards hub', NULL, true),
  ('/wallet', 'Wallet / payments', NULL, true),
  ('/orders', 'My orders', NULL, true),
  ('/support/room/:roomId', 'Customer support room', NULL, true),
  ('/admin/support-chat/room/:roomId', 'Admin support room', ARRAY['admin','owner'], true),
  ('/campaign/:id', 'Campaign detail (published only)', NULL, true),
  ('/my-complaints', 'My complaints', NULL, true),
  ('/admin/complaints', 'Admin complaints list', ARRAY['admin','owner'], true),
  ('/safety', 'Safety / emergency', NULL, true),
  ('/admin/live-tracking', 'Admin live tracking (emergency landing)', ARRAY['admin','owner'], true)
ON CONFLICT (route_pattern) DO NOTHING;

-- ============================================================
-- 3. notification_push_config (service_role-only, single row)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.notification_push_config (
  id integer PRIMARY KEY CHECK (id = 1),
  is_enabled boolean NOT NULL DEFAULT false,
  function_url text,
  auth_token text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.notification_push_config IS
  'Trigger -> edge-function config. Single row (id=1). Deliberately NOT in '
  'platform_settings (PUBLIC-readable). Only service_role/postgres may read. '
  'Owner fills function_url + auth_token + is_enabled=true when the send-push '
  'edge function (SP-2.4.2) is deployed with its SEND_PUSH_TOKEN secret.';

ALTER TABLE public.notification_push_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "push config service role all" ON public.notification_push_config;
CREATE POLICY "push config service role all" ON public.notification_push_config
  FOR ALL TO service_role USING (true) WITH CHECK (true);

REVOKE ALL ON public.notification_push_config FROM PUBLIC;
REVOKE ALL ON public.notification_push_config FROM anon;
REVOKE ALL ON public.notification_push_config FROM authenticated;
GRANT SELECT, INSERT, UPDATE ON public.notification_push_config TO service_role;

INSERT INTO public.notification_push_config (id, is_enabled) VALUES (1, false)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 4. Device-scoped FCM token RPCs
-- ============================================================
CREATE OR REPLACE FUNCTION public.register_device_token(
  p_token text,
  p_platform text,
  p_device_id text,
  p_app_version text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF p_token IS NULL OR btrim(p_token) = '' THEN
    RAISE EXCEPTION 'token is required';
  END IF;
  IF p_platform IS NULL OR btrim(p_platform) = '' THEN
    RAISE EXCEPTION 'platform is required';
  END IF;

  INSERT INTO public.notification_tokens
    (user_id, token, platform, device_id, app_version, is_active, last_seen_at)
  VALUES
    (v_uid, p_token, p_platform, p_device_id, p_app_version, true, now())
  ON CONFLICT (user_id, token)
  DO UPDATE SET
    platform = excluded.platform,
    device_id = excluded.device_id,
    app_version = excluded.app_version,
    is_active = true,
    last_seen_at = now(),
    updated_at = now();

  -- Token rotation: any other ACTIVE token registered to the same device is
  -- superseded by this registration (re-install / refresh).
  IF p_device_id IS NOT NULL AND btrim(p_device_id) <> '' THEN
    UPDATE public.notification_tokens
       SET is_active = false,
           updated_at = now()
     WHERE user_id = v_uid
       AND device_id = p_device_id
       AND token <> p_token
       AND is_active = true;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.deactivate_device_tokens(p_device_id text)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_affected integer;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  UPDATE public.notification_tokens
     SET is_active = false,
         updated_at = now()
   WHERE user_id = v_uid
     AND (p_device_id IS NULL OR btrim(p_device_id) = '' OR device_id = p_device_id)
     AND is_active = true;

  GET DIAGNOSTICS v_affected = ROW_COUNT;
  RETURN v_affected;
END;
$$;

CREATE OR REPLACE FUNCTION public.refresh_token_heartbeat(p_token text, p_device_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF p_token IS NULL OR btrim(p_token) = '' THEN
    RETURN;
  END IF;

  UPDATE public.notification_tokens
     SET last_seen_at = now(),
         device_id = COALESCE(p_device_id, device_id)
   WHERE user_id = auth.uid()
     AND token = p_token;
END;
$$;

CREATE OR REPLACE FUNCTION public.cleanup_invalid_token(p_token text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF current_user NOT IN ('service_role','postgres') THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_token IS NULL OR btrim(p_token) = '' THEN
    RETURN;
  END IF;

  UPDATE public.notification_tokens
     SET is_active = false,
         last_seen_at = now(),
         updated_at = now()
   WHERE token = p_token;
END;
$$;

-- ============================================================
-- 5. Dispatch path: _enqueue_push + trigger + backstop RPC
-- ============================================================
CREATE OR REPLACE FUNCTION public._enqueue_push(p_notification_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cfg public.notification_push_config%ROWTYPE;
BEGIN
  SELECT * INTO v_cfg FROM public.notification_push_config WHERE id = 1;
  IF NOT FOUND OR NOT COALESCE(v_cfg.is_enabled, false)
     OR v_cfg.function_url IS NULL OR btrim(v_cfg.function_url) = ''
     OR v_cfg.auth_token IS NULL OR btrim(v_cfg.auth_token) = '' THEN
    UPDATE public.notifications
       SET push_status = 'unconfigured'
     WHERE id = p_notification_id AND push_status = 'pending';
    RETURN;
  END IF;

  BEGIN
    PERFORM net.http_post(
      url := v_cfg.function_url,
      body := jsonb_build_object('notification_id', p_notification_id),
      params := '{}'::jsonb,
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || v_cfg.auth_token,
        'Content-Type', 'application/json'
      ),
      timeout_milliseconds := 5000
    );
  EXCEPTION WHEN OTHERS THEN
    UPDATE public.notifications
       SET push_status = 'failed',
           push_error = 'pg_net_error'
     WHERE id = p_notification_id AND push_status = 'pending';
  END;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_notification_push()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.send_push IS NOT TRUE OR NEW.user_id IS NULL THEN
    RETURN NEW;
  END IF;
  PERFORM public._enqueue_push(NEW.id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_notification_push ON public.notifications;
CREATE TRIGGER notify_notification_push
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_notification_push();

CREATE OR REPLACE FUNCTION public.dispatch_push(p_notification_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row public.notifications%ROWTYPE;
BEGIN
  -- SECURITY DEFINER: current_user is always postgres here; use auth.uid() to
  -- discriminate server-side calls (NULL => service_role/postgres, allowed).
  IF auth.uid() IS NOT NULL AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT * INTO v_row FROM public.notifications WHERE id = p_notification_id;
  IF NOT FOUND THEN
    RETURN;
  END IF;
  -- Idempotent: never re-send an already-sent notification.
  IF v_row.push_status = 'sent' THEN
    RETURN;
  END IF;

  UPDATE public.notifications
     SET push_status = 'pending', push_error = NULL
   WHERE id = p_notification_id;
  PERFORM public._enqueue_push(p_notification_id);
END;
$$;

-- ============================================================
-- 6. Security hardening
-- ============================================================
-- 6.1 guard_notifications_user_update: non-admins may only flip read state.
CREATE OR REPLACE FUNCTION public.guard_notifications_user_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- SECURITY DEFINER: current_user is ALWAYS the owner (postgres) here, so it
  -- cannot identify the caller. auth.uid() IS NULL marks server-side calls
  -- (service_role / postgres, no JWT) => full access; otherwise enforce.
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;
  IF public.is_admin() THEN
    RETURN NEW;
  END IF;

  IF NEW.is_read IS DISTINCT FROM OLD.is_read
     OR NEW.read_at IS DISTINCT FROM OLD.read_at THEN
    -- read-state change is the ONLY column change permitted for the owner.
    IF NEW.title IS DISTINCT FROM OLD.title
       OR NEW.body IS DISTINCT FROM OLD.body
       OR NEW.type IS DISTINCT FROM OLD.type
       OR NEW.data IS DISTINCT FROM OLD.data
       OR NEW.deep_link IS DISTINCT FROM OLD.deep_link
       OR NEW.image_url IS DISTINCT FROM OLD.image_url
       OR NEW.priority IS DISTINCT FROM OLD.priority
       OR NEW.sender_id IS DISTINCT FROM OLD.sender_id
       OR NEW.send_push IS DISTINCT FROM OLD.send_push
       OR NEW.push_status IS DISTINCT FROM OLD.push_status
       OR NEW.push_sent_at IS DISTINCT FROM OLD.push_sent_at
       OR NEW.push_error IS DISTINCT FROM OLD.push_error
       OR NEW.idempotency_key IS DISTINCT FROM OLD.idempotency_key
       OR NEW.user_id IS DISTINCT FROM OLD.user_id
       OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
      RAISE EXCEPTION 'Users may only update their own notification read state';
    END IF;
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'Users may only update their own notification read state';
END;
$$;

DROP TRIGGER IF EXISTS guard_notifications_user_update ON public.notifications;
CREATE TRIGGER guard_notifications_user_update
  BEFORE UPDATE ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_notifications_user_update();

-- 6.2 get_unread_notification_count: search_path + own-or-admin authz.
CREATE OR REPLACE FUNCTION public.get_unread_notification_count(p_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cnt integer;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN 0;
  END IF;
  -- SECURITY DEFINER: current_user is always postgres, so authz must key off
  -- auth.uid(): NULL (service_role / server-side) bypasses; otherwise enforce
  -- own-user-or-admin.
  IF auth.uid() IS NOT NULL
     AND p_user_id <> auth.uid()
     AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT COUNT(*) INTO v_cnt
    FROM public.notifications
   WHERE user_id = p_user_id AND is_read = false;
  RETURN COALESCE(v_cnt, 0);
END;
$$;

-- 6.3 deactivate_stale_tokens: search_path + service-only.
CREATE OR REPLACE FUNCTION public.deactivate_stale_tokens(stale_interval interval DEFAULT '30 days')
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_affected integer;
BEGIN
  IF current_user NOT IN ('service_role','postgres') THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  UPDATE public.notification_tokens
     SET is_active = false,
         updated_at = now()
   WHERE is_active = true
     AND last_seen_at < now() - stale_interval;

  GET DIAGNOSTICS v_affected = ROW_COUNT;
  RETURN v_affected;
END;
$$;

-- 6.4 RPC EXECUTE grants (revoke PUBLIC/anon on all notification RPCs).
-- NOTE: Supabase default privileges grant EXECUTE to anon/authenticated/service_role
-- on every newly-created function, so each sensitive RPC is explicitly locked down.
-- Internal helpers are stripped of PUBLIC/anon/authenticated entirely.
REVOKE ALL ON FUNCTION public.register_device_token(text, text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.register_device_token(text, text, text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.register_device_token(text, text, text, text) TO authenticated;

REVOKE ALL ON FUNCTION public.deactivate_device_tokens(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.deactivate_device_tokens(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.deactivate_device_tokens(text) TO authenticated;

REVOKE ALL ON FUNCTION public.refresh_token_heartbeat(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.refresh_token_heartbeat(text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.refresh_token_heartbeat(text, text) TO authenticated;

REVOKE ALL ON FUNCTION public.cleanup_invalid_token(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.cleanup_invalid_token(text) FROM anon;
REVOKE ALL ON FUNCTION public.cleanup_invalid_token(text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.cleanup_invalid_token(text) TO service_role;

REVOKE ALL ON FUNCTION public._enqueue_push(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._enqueue_push(uuid) FROM anon;
REVOKE ALL ON FUNCTION public._enqueue_push(uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public._enqueue_push(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.dispatch_push(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.dispatch_push(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.dispatch_push(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.dispatch_push(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.get_unread_notification_count(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_unread_notification_count(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_unread_notification_count(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_unread_notification_count(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.deactivate_stale_tokens(interval) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.deactivate_stale_tokens(interval) FROM anon;
REVOKE ALL ON FUNCTION public.deactivate_stale_tokens(interval) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.deactivate_stale_tokens(interval) TO service_role;

-- admin_broadcast_notification: tighten grant (was anon-EXECUTE live; is_admin()
-- inside already gates, this is defense-in-depth). Keep authenticated/service_role.
REVOKE ALL ON FUNCTION public.admin_broadcast_notification(text, text, text, text, text, uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.admin_broadcast_notification(text, text, text, text, text, uuid) TO service_role;

-- 6.5 anon table grants on notification_tokens (RLS already blocks; tighten).
REVOKE ALL ON public.notification_tokens FROM anon;
-- Strip DDL-level privileges that RLS cannot cover (TRUNCATE is not protected
-- by row-level security). Keep row-level DML for own-token management.
REVOKE TRUNCATE, TRIGGER, REFERENCES, MAINTAIN ON public.notification_tokens FROM authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.notification_tokens TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.notification_tokens TO service_role;

-- ============================================================
-- 7. validate_notification_deep_link (server allowlist check)
-- ============================================================
CREATE OR REPLACE FUNCTION public.validate_notification_deep_link(p_deep_link text)
RETURNS text
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_segs text[];
  v_pat text[];
  v_i integer;
  v_role text;
  v_row record;
  v_matched boolean;
BEGIN
  IF p_deep_link IS NULL OR btrim(p_deep_link) = '' THEN
    RETURN NULL;
  END IF;
  IF left(p_deep_link, 1) <> '/' THEN
    RETURN NULL;
  END IF;
  -- Reject scheme injection and path traversal outright.
  IF p_deep_link ~* '^/(javascript|http|https|data|vbscript|file):'
     OR p_deep_link ~ '(^|/)\.\.?(/|$)' THEN
    RETURN NULL;
  END IF;

  v_role := NULL;
  -- SECURITY DEFINER: current_user is ALWAYS the function owner (postgres),
  -- so it cannot discriminate the caller. Use auth.uid() instead: NULL for
  -- service_role / server-side calls (no JWT) => role restriction bypassed;
  -- non-NULL for authenticated JWTs => enforce allowed_roles from users.role.
  SELECT role INTO v_role FROM public.users WHERE id = auth.uid();

  v_segs := string_to_array(p_deep_link, '/');
  FOR v_row IN
    SELECT route_pattern, allowed_roles
      FROM public.notification_destinations
     WHERE is_active
     ORDER BY length(route_pattern) DESC
  LOOP
    v_pat := string_to_array(v_row.route_pattern, '/');
    IF cardinality(v_pat) IS DISTINCT FROM cardinality(v_segs) THEN
      CONTINUE;
    END IF;
    v_matched := true;
    FOR v_i IN 1..cardinality(v_segs) LOOP
      IF left(v_pat[v_i], 1) = ':' THEN
        CONTINUE; -- parameterized segment: matches any single value
      END IF;
      IF v_pat[v_i] <> v_segs[v_i] THEN
        v_matched := false;
        EXIT;
      END IF;
    END LOOP;
    IF v_matched THEN
      IF v_row.allowed_roles IS NULL
         OR auth.uid() IS NULL
         OR v_role = ANY(v_row.allowed_roles) THEN
        RETURN p_deep_link;
      END IF;
    END IF;
  END LOOP;

  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.validate_notification_deep_link(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.validate_notification_deep_link(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.validate_notification_deep_link(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.validate_notification_deep_link(text) TO service_role;

-- ============================================================
-- 8. Automated source notifications (triggers)
-- ============================================================
-- 8.1 notify_chat_message_reply: support chat, first-message-of-turn only.
CREATE OR REPLACE FUNCTION public.notify_chat_message_reply()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_room public.chat_rooms%ROWTYPE;
  v_prev_sender uuid;
  v_customer uuid;
  v_admin_id uuid;
BEGIN
  IF NEW.sender_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_room FROM public.chat_rooms WHERE id = NEW.room_id;
  IF NOT FOUND OR COALESCE(v_room.room_type, '') <> 'support'
     OR COALESCE(v_room.is_active, true) = false
     OR v_room.status = 'closed' THEN
    RETURN NEW;
  END IF;

  -- Noise suppression: only the FIRST message of a turn (author change).
  SELECT sender_id INTO v_prev_sender
    FROM public.chat_messages
   WHERE room_id = NEW.room_id AND id <> NEW.id
   ORDER BY created_at DESC, id DESC
   LIMIT 1;
  IF v_prev_sender IS NOT NULL AND v_prev_sender = NEW.sender_id THEN
    RETURN NEW;
  END IF;

  IF public._is_active_admin_uid(NEW.sender_id) THEN
    -- Admin replied -> notify the customer participant(s).
    FOREACH v_customer IN ARRAY v_room.participant_ids LOOP
      IF v_customer IS NULL OR public._is_active_admin_uid(v_customer) THEN
        CONTINUE;
      END IF;
      INSERT INTO public.notifications
        (user_id, title, body, type, data, deep_link, idempotency_key,
         sender_id, priority, send_push)
      VALUES
        (v_customer, 'New support message', 'You have a new reply in support chat', 'message',
         jsonb_build_object('entity_type','room','entity_id', NEW.room_id::text,'action','reply'),
         '/support/room/' || NEW.room_id::text,
         'chat-msg-' || NEW.id::text,
         NEW.sender_id, 'normal', true)
      ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;
    END LOOP;
  ELSE
    -- Customer replied -> notify assigned admin; unassigned -> in-scope admins.
    v_admin_id := v_room.assigned_admin_id;
    IF v_admin_id IS NOT NULL THEN
      INSERT INTO public.notifications
        (user_id, title, body, type, data, deep_link, idempotency_key,
         sender_id, priority, send_push)
      VALUES
        (v_admin_id, 'New customer message', 'A customer replied in support chat', 'message',
         jsonb_build_object('entity_type','room','entity_id', NEW.room_id::text,'action','reply'),
         '/admin/support-chat/room/' || NEW.room_id::text,
         'chat-msg-' || NEW.id::text,
         NEW.sender_id, 'normal', true)
      ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;
    ELSE
      FOR v_admin_id IN
        SELECT u.id FROM public.users u
         WHERE public._is_active_admin_uid(u.id)
           AND (v_room.region_id IS NULL OR public._region_in_scope(u.id, v_room.region_id))
      LOOP
        INSERT INTO public.notifications
          (user_id, title, body, type, data, deep_link, idempotency_key,
           sender_id, priority, send_push)
        VALUES
          (v_admin_id, 'New customer message', 'A customer replied in support chat', 'message',
           jsonb_build_object('entity_type','room','entity_id', NEW.room_id::text,'action','reply'),
           '/admin/support-chat/room/' || NEW.room_id::text,
           'chat-msg-' || NEW.id::text || '-' || v_admin_id::text,
           NEW.sender_id, 'normal', true)
        ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;
      END LOOP;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_chat_message_reply ON public.chat_messages;
CREATE TRIGGER notify_chat_message_reply
  AFTER INSERT ON public.chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_chat_message_reply();

-- 8.2 notify_complaint_notifications: INSERT (new complaint -> admins) and
--     UPDATE OF status (status change -> complainant/reporter).
CREATE OR REPLACE FUNCTION public.notify_complaint_notifications()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid;
  v_region uuid;
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- New complaint filed -> notify in-scope admins (fallback: all admins).
    v_region := public._member_region_id(NEW.complainant_id);
    FOR v_uid IN
      SELECT u.id FROM public.users u
       WHERE public._is_active_admin_uid(u.id)
         AND (v_region IS NULL OR public._region_in_scope(u.id, v_region))
    LOOP
      INSERT INTO public.notifications
        (user_id, title, body, type, data, deep_link, idempotency_key,
         sender_id, priority, send_push)
      VALUES
        (v_uid, 'New complaint', 'A new complaint requires review', 'complaint',
         jsonb_build_object('entity_type','complaint','entity_id', NEW.id::text,'action','new'),
         '/admin/complaints',
         'complaint-new-' || NEW.id::text || '-' || v_uid::text,
         NEW.complainant_id, 'normal', true)
      ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;
    END LOOP;
  ELSIF TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status THEN
    -- Status change -> complainant + reporter (if present and distinct).
    FOR v_uid IN
      SELECT DISTINCT t.uid FROM (
        SELECT NEW.complainant_id AS uid
        UNION ALL
        SELECT NEW.reporter_id
      ) t WHERE t.uid IS NOT NULL
    LOOP
      INSERT INTO public.notifications
        (user_id, title, body, type, data, deep_link, idempotency_key,
         sender_id, priority, send_push)
      VALUES
        (v_uid, 'Complaint update', 'Your complaint status changed to ' || NEW.status, 'complaint',
         jsonb_build_object('entity_type','complaint','entity_id', NEW.id::text,'action', NEW.status),
         '/my-complaints',
         'complaint-' || NEW.id::text || '-' || NEW.status || '-' || v_uid::text,
         NEW.complainant_id, 'normal', true)
      ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;
    END LOOP;
  END IF;

  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS notify_complaint_new ON public.complaints;
CREATE TRIGGER notify_complaint_new
  AFTER INSERT ON public.complaints
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_complaint_notifications();

DROP TRIGGER IF EXISTS notify_complaint_status ON public.complaints;
CREATE TRIGGER notify_complaint_status
  AFTER UPDATE OF status ON public.complaints
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_complaint_notifications();

-- 8.3 notify_sos_alert: emergency -> in-scope admins (authorized recipients).
CREATE OR REPLACE FUNCTION public.notify_sos_alert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_region uuid;
  v_uid uuid;
BEGIN
  v_region := public._member_region_id(NEW.user_id);
  FOR v_uid IN
    SELECT u.id FROM public.users u
     WHERE public._is_active_admin_uid(u.id)
       AND (v_region IS NULL OR public._region_in_scope(u.id, v_region))
  LOOP
    INSERT INTO public.notifications
      (user_id, title, body, type, data, deep_link, idempotency_key,
       sender_id, priority, send_push)
    VALUES
      (v_uid, 'SOS Emergency Alert', 'A user triggered an SOS alert', 'emergency',
       jsonb_build_object('entity_type','sos','entity_id', NEW.id::text,'action','sos'),
       '/admin/live-tracking',
       'sos-notify-' || NEW.id::text || '-' || v_uid::text,
       NEW.user_id, 'high', true)
    ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;
  END LOOP;

  -- NOTE: sos trusted_contacts are external phone/email records (owner-scoped),
  -- NOT app users, so no in-app notifications row can target them. SMS/call
  -- alerting to contacts is out of scope for Phase 2.4.1 (documented, HANDOFF-35).
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_sos_alert ON public.sos_alerts;
CREATE TRIGGER notify_sos_alert
  AFTER INSERT ON public.sos_alerts
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_sos_alert();

-- ============================================================
-- 9. Additive campaigns RLS: customers open published campaigns
-- ============================================================
DROP POLICY IF EXISTS "campaigns public published select" ON public.campaigns;
CREATE POLICY "campaigns public published select" ON public.campaigns
  FOR SELECT TO authenticated
  USING (
    status = 'published'
    AND (starts_at IS NULL OR starts_at <= now())
    AND (ends_at IS NULL OR ends_at >= now())
  );
