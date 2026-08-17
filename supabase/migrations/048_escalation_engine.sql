-- ============================================================
-- 048_escalation_engine.sql
-- Phase 2.5 (STEP 13) — escalation engine.
--
-- Roadmap 2.5 contract: escalation_events table + engine RPCs;
-- wire complaints 'escalated' status to a REAL assignment (region ->
-- parent -> global -> owner) instead of a UI-only string.
--
-- Design (docs/HANDOFF/STEP_13_ESCALATION_ENGINE_PLAN.md):
--   1. escalation_events — general escalation ledger (entity_type +
--      entity_id), inserted only by the SECURITY DEFINER engine RPCs.
--      RLS: admin select all; no direct client writes (SELECT-only grant).
--   2. complaints extension (additive, mirrors chat_rooms 033):
--      assigned_admin_id / escalated_at / escalated_from_admin_id.
--   3. Guard triggers (complaints_fixup_insert/update) mirroring
--      chat_rooms_fixup_*: non-admin direct writes forced to safe
--      defaults; SECURITY DEFINER RPC context (current_user IS DISTINCT
--      FROM session_user) is trusted.
--   4. Engine RPCs (016/047 pattern — SECURITY DEFINER + search_path +
--      REVOKE-before-GRANT + anon EXECUTE revoked):
--        escalate_complaint(id, reason)   — route via resolve_support_admin
--                                            excluding the current assignee;
--                                            owner queue = terminal.
--        assign_complaint(id, admin_id)   — explicit assignment in scope.
--        get_escalation_events(id)        — jsonb list for the events UI.
--      Every path: escalation_events row + member_events
--      complaint_escalated/complaint_assigned + notification to the new
--      assignee (deep_link /admin/complaints, already allowlisted) +
--      write_audit.
--
-- Idempotent: safe to re-run. Additive; no data destruction.
-- ============================================================

BEGIN;

-- ─── 1. ESCALATION_EVENTS LEDGER ─────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.escalation_events (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type      text NOT NULL
    CHECK (entity_type IN ('complaint','support_chat')),
  entity_id        uuid NOT NULL,
  from_admin_id    uuid REFERENCES public.users(id) ON DELETE SET NULL,
  to_admin_id      uuid REFERENCES public.users(id) ON DELETE SET NULL,
  actor_id         uuid NOT NULL REFERENCES public.users(id) ON DELETE SET NULL,
  reason           text NOT NULL,
  previous_scope   text,
  new_scope        text,
  created_at       timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.escalation_events IS
  'General escalation ledger (Phase 2.5). Complaint escalations land here '
  'with entity_type=''complaint''; support-chat escalations continue to use '
  'chat_escalations (033). Inserted by escalate_complaint / assign_complaint '
  'only; clients get SELECT via RLS (admins).';

CREATE INDEX IF NOT EXISTS idx_escalation_events_entity
  ON public.escalation_events (entity_type, entity_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_escalation_events_to_admin
  ON public.escalation_events (to_admin_id, created_at DESC);

ALTER TABLE public.escalation_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "escalation_events admin select" ON public.escalation_events;
CREATE POLICY "escalation_events admin select" ON public.escalation_events
  FOR SELECT
  USING (public.is_admin());

-- No INSERT/UPDATE/DELETE grant for authenticated: engine writes flow
-- exclusively through the SECURITY DEFINER RPCs (owner context).
REVOKE ALL ON public.escalation_events FROM PUBLIC;
REVOKE ALL ON public.escalation_events FROM anon;
GRANT SELECT ON public.escalation_events TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.escalation_events
  TO service_role;

-- ─── 2. COMPLAINTS EXTENSION (additive, mirrors chat_rooms 033) ─────────

ALTER TABLE public.complaints
  ADD COLUMN IF NOT EXISTS assigned_admin_id uuid REFERENCES public.users(id)
    ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS escalated_at timestamptz,
  ADD COLUMN IF NOT EXISTS escalated_from_admin_id uuid REFERENCES public.users(id)
    ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_complaints_assigned
  ON public.complaints (assigned_admin_id);
CREATE INDEX IF NOT EXISTS idx_complaints_escalated_partial
  ON public.complaints (assigned_admin_id)
  WHERE status = 'escalated';

-- ─── 3. GUARD TRIGGERS (server-authoritative complaint fields) ──────────

CREATE OR REPLACE FUNCTION public.complaints_fixup_insert()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  -- Server-origin proof: admins, no-JWT calls (service_role/cron), or the
  -- escalation-RPC marker set by the SECURITY DEFINER engine RPCs.
  -- IMPORTANT: do NOT use `current_user IS DISTINCT FROM session_user` here.
  -- Supabase's PostgREST pooler always runs with session_user='authenticator'
  -- and SET LOCAL ROLE, so that test is TRUE for every client write and would
  -- trust forged inserts/updates (verified live). The marker is transaction-
  -- local and set ONLY by escalate_complaint/assign_complaint -> unspoofable.
  IF public.is_admin() THEN
    RETURN NEW;
  END IF;
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;
  IF current_setting('app.escalation_rpc', true) = 'true' THEN
    RETURN NEW;
  END IF;
  NEW.status := 'pending';
  NEW.priority := 'medium';
  NEW.assigned_admin_id := NULL;
  NEW.escalated_at := NULL;
  NEW.escalated_from_admin_id := NULL;
  NEW.resolved_at := NULL;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS complaints_fixup_insert ON public.complaints;
CREATE TRIGGER complaints_fixup_insert
  BEFORE INSERT ON public.complaints
  FOR EACH ROW
  EXECUTE FUNCTION public.complaints_fixup_insert();

CREATE OR REPLACE FUNCTION public.complaints_fixup_update()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  -- See complaints_fixup_insert for why the marker (not the session-role
  -- discriminator) is the correct server-origin proof under PostgREST.
  -- RPC-origin marker: set_config('app.escalation_rpc','true',true) inside the
  -- SECURITY DEFINER engine RPCs (escalate/assign). PostgREST clients cannot
  -- set this via table CRUD, so it is unspoofable proof of RPC origin.
  IF current_setting('app.escalation_rpc', true) = 'true' THEN
    RETURN NEW;
  END IF;
  -- No-JWT server calls (service_role / cron / edge worker / operational tooling).
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;
  IF NOT public.is_admin() THEN
    NEW.status := OLD.status;
    NEW.priority := OLD.priority;
    NEW.assigned_admin_id := OLD.assigned_admin_id;
    NEW.escalated_at := OLD.escalated_at;
    NEW.escalated_from_admin_id := OLD.escalated_from_admin_id;
    NEW.resolved_at := OLD.resolved_at;
    RETURN NEW;
  END IF;

  -- Admin direct client writes: any status transition is allowed EXCEPT the
  -- RPC-only ones (escalated status / assignment fields).
  IF NEW.status = 'escalated' AND NEW.status IS DISTINCT FROM OLD.status THEN
    RAISE EXCEPTION 'Complaint must be escalated via escalate_complaint()';
  END IF;
  IF NEW.assigned_admin_id IS DISTINCT FROM OLD.assigned_admin_id
     OR NEW.escalated_at IS DISTINCT FROM OLD.escalated_at
     OR NEW.escalated_from_admin_id IS DISTINCT FROM OLD.escalated_from_admin_id THEN
    RAISE EXCEPTION 'Complaint assignment fields are managed by the escalation RPCs';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS complaints_fixup_update ON public.complaints;
CREATE TRIGGER complaints_fixup_update
  BEFORE UPDATE ON public.complaints
  FOR EACH ROW
  EXECUTE FUNCTION public.complaints_fixup_update();

-- ─── 3.1 041 GUARD FIX (documented ADR-069) ─────────────────────────────
-- PRECONDITION: guard_notifications_user_update (041) only treated
-- `auth.uid() IS NULL` as server-origin. The push dispatch path runs
-- SECURITY DEFINER on behalf of ANY authenticated caller, so a customer-
-- originated server-side write (e.g. notify_complaint_new when a customer
-- files a complaint, or notify_chat_message_reply) aborts the whole DML:
--
--   Users may only update their own notification read state
--   PL/pgSQL function _enqueue_push(uuid) line 9 ...
--
-- This means customer complaint creation BY a customer was failing live
-- (verified by probe). The correct server-origin proof is a transaction-
-- local marker set by the SECURITY DEFINER dispatch path (_enqueue_push /
-- dispatch_push / notify_notification_push) via set_config(..., true).
--
-- IMPORTANT: the `current_user IS DISTINCT FROM session_user` discriminator
-- is NOT usable under Supabase's PostgREST pooler: PostgREST connects as
-- 'authenticator' and SET ROLEs per-request, so session_user='authenticator'
-- ALWAYS differs from current_user for every client write, making every
-- client update look "server-origin" (verified live: a customer could
-- forge escalation fields). Markers are unspoofable by PostgREST clients.
CREATE OR REPLACE FUNCTION public.guard_notifications_user_update()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  -- Push-dispatch marker set by the SECURITY DEFINER dispatch functions.
  IF current_setting('app.notify_dispatch', true) = 'true' THEN
    RETURN NEW;
  END IF;
  -- No-JWT server calls (service_role / cron / edge worker).
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;
  -- Admins may keep full control (read-state or content).
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

-- Dispatch functions re-declared to set the notify-dispatch marker so the
-- guard above trusts server push-dispatch updates (idempotent re-declare).
CREATE OR REPLACE FUNCTION public._enqueue_push(p_notification_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cfg public.notification_push_config%ROWTYPE;
BEGIN
  PERFORM set_config('app.notify_dispatch', 'true', true);

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

CREATE OR REPLACE FUNCTION public.dispatch_push(p_notification_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row public.notifications%ROWTYPE;
BEGIN
  IF auth.uid() IS NOT NULL AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  PERFORM set_config('app.notify_dispatch', 'true', true);

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

-- ─── 4. ENGINE RPCs (016/047 pattern) ───────────────────────────────────

-- Escalate a complaint: record the escalation, then re-route to the next
-- tier EXCLUDING the current assignee. Terminal owner / no candidate ->
-- status 'escalated', unassigned (owner queue).
CREATE OR REPLACE FUNCTION public.escalate_complaint(
  p_complaint_id uuid,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_complaint public.complaints%ROWTYPE;
  v_region uuid;
  v_current uuid;
  v_next uuid;
  v_prev_scope text;
  v_new_scope text;
  v_assignee uuid;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'Escalation requires a reason';
  END IF;

  -- Prove server-origin to complaints_fixup_update (RPC path marker).
  PERFORM set_config('app.escalation_rpc', 'true', true);

  SELECT * INTO v_complaint
    FROM public.complaints WHERE id = p_complaint_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Complaint not found';
  END IF;
  IF v_complaint.status IN ('resolved','rejected','dismissed') THEN
    RAISE EXCEPTION 'Complaint is already closed';
  END IF;

  v_region := public._member_region_id(v_complaint.complainant_id);
  IF NOT public.has_permission('MEMBER_VIEW_COMPLAINTS', v_region) THEN
    RAISE EXCEPTION 'Not authorized for this complaint region';
  END IF;

  v_current := v_complaint.assigned_admin_id;
  v_prev_scope := CASE
    WHEN v_current IS NULL THEN 'unassigned'
    WHEN EXISTS (SELECT 1 FROM public.users WHERE id = v_current AND role = 'owner') THEN 'owner'
    WHEN EXISTS (SELECT 1 FROM public.admin_region_assignments WHERE admin_id = v_current) THEN 'scoped'
    ELSE 'global'
  END;

  -- Owner/escalator terminal -> owner queue.
  IF v_current IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.users WHERE id = v_current AND role = 'owner'
  ) THEN
    UPDATE public.complaints
       SET status = 'escalated',
           assigned_admin_id = NULL,
           escalated_at = now(),
           escalated_from_admin_id = auth.uid(),
           updated_at = now()
     WHERE id = p_complaint_id;
    INSERT INTO public.escalation_events
      (entity_type, entity_id, from_admin_id, to_admin_id, actor_id, reason,
       previous_scope, new_scope)
    VALUES ('complaint', p_complaint_id, v_current, NULL, auth.uid(), p_reason,
            v_prev_scope, 'owner');
    PERFORM public.write_audit(
      'COMPLAINT_ESCALATED', 'complaints', p_complaint_id::text,
      jsonb_build_object('reason', p_reason, 'from_admin_id', auth.uid(),
                         'to_admin_id', NULL, 'terminal', true)
    );
    RETURN;
  END IF;

  -- Strict upward routing: an already-owner-queued complaint is terminal.
  IF v_current IS NULL AND EXISTS (
    SELECT 1 FROM public.escalation_events e
     WHERE e.entity_type = 'complaint'
       AND e.entity_id = p_complaint_id
       AND e.new_scope = 'owner'
  ) THEN
    RETURN;
  END IF;

  -- Route to the NEXT HIGHER tier from the current assignee (never down):
  --   unassigned -> best regional (else global/owner)
  --   scoped     -> global tier (else owner)
  --   global     -> owner queue (terminal)
  IF v_current IS NULL THEN
    v_next := public.resolve_support_admin(v_region, true, NULL);
  ELSIF EXISTS (
    SELECT 1 FROM public.admin_region_assignments WHERE admin_id = v_current
  ) THEN
    v_next := public.resolve_support_admin(v_region, false, v_current);
  ELSE
    v_next := NULL;
  END IF;
  IF v_next IS NULL OR v_next = v_current THEN
    v_assignee := NULL;
    v_new_scope := 'owner';
  ELSE
    v_assignee := v_next;
    v_new_scope := CASE
      WHEN EXISTS (SELECT 1 FROM public.users WHERE id = v_next AND role = 'owner') THEN 'owner'
      WHEN EXISTS (SELECT 1 FROM public.admin_region_assignments WHERE admin_id = v_next) THEN 'scoped'
      ELSE 'global'
    END;
  END IF;

  UPDATE public.complaints
     SET status = 'escalated',
         assigned_admin_id = v_assignee,
         escalated_at = now(),
         escalated_from_admin_id = auth.uid(),
         updated_at = now()
   WHERE id = p_complaint_id;

  INSERT INTO public.escalation_events
    (entity_type, entity_id, from_admin_id, to_admin_id, actor_id, reason,
     previous_scope, new_scope)
  VALUES ('complaint', p_complaint_id, v_current, v_next, auth.uid(), p_reason,
          v_prev_scope, v_new_scope);

  INSERT INTO public.member_events (user_id, event_type, payload)
  VALUES (v_complaint.complainant_id, 'complaint_escalated',
          jsonb_build_object('complaint_id', p_complaint_id::text,
                             'escalated_by', auth.uid()::text))
  ON CONFLICT DO NOTHING;

  IF v_assignee IS NOT NULL THEN
    INSERT INTO public.notifications
      (user_id, title, body, type, data, deep_link, idempotency_key,
       sender_id, priority, send_push)
    VALUES (
      v_assignee,
      'Escalated complaint assigned',
      'An escalated complaint requires your review.',
      'complaint_escalated',
      jsonb_build_object('entity_type', 'complaint',
                         'entity_id', p_complaint_id::text,
                         'action', 'escalated'),
      '/admin/complaints',
      'complaint-escalated-' || p_complaint_id::text || '-' || v_assignee::text,
      auth.uid(), 'high', true
    )
    ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;
  END IF;

  PERFORM public.write_audit(
    'COMPLAINT_ESCALATED', 'complaints', p_complaint_id::text,
    jsonb_build_object('reason', p_reason, 'from_admin_id', auth.uid(),
                       'to_admin_id', v_next, 'previous_scope', v_prev_scope,
                       'new_scope', v_new_scope)
  );
END;
$$;

-- Explicit assignment by an admin (region-scoped).
CREATE OR REPLACE FUNCTION public.assign_complaint(
  p_complaint_id uuid,
  p_admin_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_complaint public.complaints%ROWTYPE;
  v_region uuid;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  -- Prove server-origin to complaints_fixup_update (RPC path marker).
  PERFORM set_config('app.escalation_rpc', 'true', true);

  SELECT * INTO v_complaint
    FROM public.complaints WHERE id = p_complaint_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Complaint not found';
  END IF;
  IF v_complaint.status IN ('resolved','rejected','dismissed') THEN
    RAISE EXCEPTION 'Complaint is already closed';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = p_admin_id AND role IN ('admin','owner')
  ) THEN
    RAISE EXCEPTION 'Assignee must be an admin';
  END IF;

  v_region := public._member_region_id(v_complaint.complainant_id);
  IF NOT public.has_permission('MEMBER_VIEW_COMPLAINTS', v_region) THEN
    RAISE EXCEPTION 'Not authorized for this complaint region';
  END IF;
  IF p_admin_id <> auth.uid()
     AND NOT public.is_admin_for_region(v_region) THEN
    RAISE EXCEPTION 'Assignee must be in scope for the complaint region';
  END IF;

  UPDATE public.complaints
     SET status = 'escalated',
         assigned_admin_id = p_admin_id,
         escalated_at = now(),
         escalated_from_admin_id = auth.uid(),
         updated_at = now()
   WHERE id = p_complaint_id;

  INSERT INTO public.escalation_events
    (entity_type, entity_id, from_admin_id, to_admin_id, actor_id, reason,
     previous_scope, new_scope)
  VALUES ('complaint', p_complaint_id,
          v_complaint.assigned_admin_id, p_admin_id, auth.uid(),
          'Assigned to admin',
          CASE WHEN v_complaint.assigned_admin_id IS NULL THEN 'unassigned'
               ELSE 'assigned' END,
          CASE WHEN EXISTS (SELECT 1 FROM public.users
                            WHERE id = p_admin_id AND role = 'owner')
               THEN 'owner' ELSE 'scoped' END);

  INSERT INTO public.member_events (user_id, event_type, payload)
  VALUES (v_complaint.complainant_id, 'complaint_assigned',
          jsonb_build_object('complaint_id', p_complaint_id::text,
                             'assigned_to', p_admin_id::text))
  ON CONFLICT DO NOTHING;

  INSERT INTO public.notifications
    (user_id, title, body, type, data, deep_link, idempotency_key,
     sender_id, priority, send_push)
  VALUES (
    p_admin_id,
    'Complaint assigned to you',
    'A complaint has been assigned to you for review.',
    'complaint_assigned',
    jsonb_build_object('entity_type', 'complaint',
                       'entity_id', p_complaint_id::text,
                       'action', 'assigned'),
    '/admin/complaints',
    'complaint-assigned-' || p_complaint_id::text || '-' || p_admin_id::text,
    auth.uid(), 'high', true
  )
  ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;

  PERFORM public.write_audit(
    'COMPLAINT_ASSIGNED', 'complaints', p_complaint_id::text,
    jsonb_build_object('from_admin_id', auth.uid(),
                       'to_admin_id', p_admin_id)
  );
END;
$$;

-- Escalation events list RPC (admin-scoped; the events queue UI source).
CREATE OR REPLACE FUNCTION public.get_escalation_events(
  p_complaint_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_rows jsonb;
  v_region uuid;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF p_complaint_id IS NOT NULL THEN
    SELECT public._member_region_id(c.complainant_id)
      INTO v_region FROM public.complaints c WHERE c.id = p_complaint_id;
    IF NOT public.has_permission('MEMBER_VIEW_COMPLAINTS', v_region) THEN
      RAISE EXCEPTION 'Not authorized for this complaint region';
    END IF;
    SELECT jsonb_agg(to_jsonb(e) ORDER BY e.created_at DESC)
      INTO v_rows
      FROM public.escalation_events e
     WHERE e.entity_type = 'complaint' AND e.entity_id = p_complaint_id;
  ELSE
    SELECT jsonb_agg(to_jsonb(e) ORDER BY e.created_at DESC)
      INTO v_rows
      FROM public.escalation_events e
     WHERE e.entity_type = 'complaint'
       AND (
         public.has_permission('MEMBER_VIEW_COMPLAINTS', NULL)
         OR EXISTS (
           SELECT 1 FROM public.complaints c
           WHERE c.id = e.entity_id
             AND public.has_permission(
                   'MEMBER_VIEW_COMPLAINTS',
                   public._member_region_id(c.complainant_id))
         )
       );
  END IF;

  RETURN COALESCE(v_rows, '[]'::jsonb);
END;
$$;

-- ─── 5. ACL: REVOKE-before-GRANT ────────────────────────────────────────

REVOKE ALL ON FUNCTION public.escalate_complaint(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.escalate_complaint(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.escalate_complaint(uuid, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.escalate_complaint(uuid, text)
  TO service_role;

REVOKE ALL ON FUNCTION public.assign_complaint(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.assign_complaint(uuid, uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.assign_complaint(uuid, uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.assign_complaint(uuid, uuid)
  TO service_role;

REVOKE ALL ON FUNCTION public.get_escalation_events(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_escalation_events(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_escalation_events(uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_escalation_events(uuid)
  TO service_role;

REVOKE ALL ON FUNCTION public.complaints_fixup_insert() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.complaints_fixup_insert() FROM anon;
REVOKE ALL ON FUNCTION public.complaints_fixup_update() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.complaints_fixup_update() FROM anon;

COMMIT;

-- ============================================================
-- END 048_escalation_engine.sql
-- ============================================================
