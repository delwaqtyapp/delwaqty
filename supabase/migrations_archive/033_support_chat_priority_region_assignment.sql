-- ============================================================
-- 033_support_chat_priority_region_assignment.sql
-- Phase 2.3 (2.3A) — Support chat priority/region/assignment/
-- escalation + emergency lane + the three live RLS security fixes.
--
-- Scope (approved: docs/HANDOFF/PHASE_2_3_DECISION_LOCK_REPORT.md
-- �16-033, PHASE_2_3_MEMBER_MANAGEMENT_SUPPORT_ARCHITECTURE_AUDIT.md
-- �12-14/�21, and 32_PHASE_2_3_SUPPORT_CHAT_PRIORITY_ASSIGNMENT_AUDIT.md):
--   1. chat_rooms: additive columns priority/region_id/assigned_admin_id/
--      assigned_at/status/escalated_at/escalated_from_admin_id/closed_at
--      + CHECK constraints + indexes (ADR-051/052: extend, never replace).
--   2. chat_escalations: new escalation ledger (full from/to/actor/reason/
--      scope history) + RLS (admin all + participant select) + revoke-before-
--      grant (030 lesson).
--   3. Guard triggers (chat_rooms_fixup_insert / chat_rooms_fixup_update):
--      customers cannot set priority/status/assignee/server fields. Triggers
--      are invoker-security so they can detect RPC-origin via
--      current_user <> session_user (SECURITY DEFINER RPCs run as owner);
--      all privileged lookups inside delegate to SECURITY DEFINER helpers
--      (is_admin / resolve_support_admin). This is a documented deviation
--      from the audit's "SECURITY DEFINER triggers" note: the definer context
--      would mask RPC-origin and let customers bypass via RPC, which is the
--      exact bypass the guard exists to stop.
--   4. chat_rooms_auto_route AFTER INSERT trigger: routes new non-emergency
--      rooms to the deterministic best admin (region -> parent -> global ->
--      owner) and notifies the assignee. Emergency rooms are owned by
--      open_emergency_chat (never overwrite an already-assigned room).
--   5. RPCs (016 pattern: SECURITY DEFINER + SET search_path + revoke-before-
--      grant + anon EXECUTE revoked): resolve_support_admin (internal),
--      route_support_chat, assign_support_chat, escalate_support_chat,
--      open_emergency_chat, close_support_chat, write_audit (internal).
--   6. RLS security fixes (D8): activity_logs INSERT -> service_role only
--      (live finding: TO public WITH CHECK true); driver_locations SELECT ->
--      ride-participant + driver-owner + admin (live finding: any
--      authenticated user); sos_alerts + admin SELECT (command center).
--
-- Security: customers never pick admins; priority is server-locked;
-- routing is deterministic and server-side; realtime reuses the existing
-- chat_rooms/chat_messages/notifications publications (no change).
--
-- Idempotent: safe to re-run. Additive; no data destruction; no admin seeds.
-- ============================================================

BEGIN;

-- ─── 1. CHAT_ROOMS EXTENSION (additive, ADR-051/052) ──────────

ALTER TABLE public.chat_rooms
  ADD COLUMN IF NOT EXISTS priority text NOT NULL DEFAULT 'low'
    CHECK (priority IN ('low','medium','high','urgent','emergency')),
  ADD COLUMN IF NOT EXISTS region_id uuid REFERENCES public.regions(id),
  ADD COLUMN IF NOT EXISTS assigned_admin_id uuid REFERENCES public.users(id),
  ADD COLUMN IF NOT EXISTS assigned_at timestamptz,
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','assigned','escalated','closed')),
  ADD COLUMN IF NOT EXISTS escalated_at timestamptz,
  ADD COLUMN IF NOT EXISTS escalated_from_admin_id uuid REFERENCES public.users(id),
  ADD COLUMN IF NOT EXISTS closed_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_chat_rooms_status
  ON public.chat_rooms (status);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_assigned
  ON public.chat_rooms (assigned_admin_id);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_region
  ON public.chat_rooms (region_id);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_priority
  ON public.chat_rooms (priority);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_open_partial
  ON public.chat_rooms (assigned_admin_id)
  WHERE status IN ('open','assigned');

-- ─── 2. CHAT_ESCALATIONS LEDGER ───────────────────────────────

CREATE TABLE IF NOT EXISTS public.chat_escalations (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id          uuid NOT NULL REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
  previous_admin_id uuid REFERENCES public.users(id),
  new_admin_id     uuid REFERENCES public.users(id),
  actor_id         uuid NOT NULL REFERENCES public.users(id),
  reason           text,
  previous_scope   text,
  new_scope        text,
  created_at       timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.chat_escalations IS
  'Support-chat escalation ledger (Phase 2.3). Full from/to/actor/reason/'
  'scope history; inserted by escalate_support_chat only.';

CREATE INDEX IF NOT EXISTS idx_chat_escalations_room
  ON public.chat_escalations (room_id, created_at);

ALTER TABLE public.chat_escalations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "chat_escalations admin all" ON public.chat_escalations;
CREATE POLICY "chat_escalations admin all" ON public.chat_escalations
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "chat_escalations participant select" ON public.chat_escalations;
CREATE POLICY "chat_escalations participant select" ON public.chat_escalations
  FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM public.chat_rooms r
    WHERE r.id = chat_escalations.room_id
      AND auth.uid() = ANY (r.participant_ids)
  ));

REVOKE ALL ON public.chat_escalations FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.chat_escalations TO authenticated;

-- ─── 3. RLS SECURITY FIXES (D8) ───────────────────────────────

-- 3.1 activity_logs: INSERT was TO public WITH CHECK true (live finding,
-- anon/authenticated could poison the audit log). Only service_role (and the
-- SECURITY DEFINER write_audit helper running as table owner) may insert.
DROP POLICY IF EXISTS "Activity logs insertable by service role"
  ON public.activity_logs;
DROP POLICY IF EXISTS "activity_logs service role insert"
  ON public.activity_logs;
CREATE POLICY "activity_logs service role insert" ON public.activity_logs
  FOR INSERT
  TO service_role
  WITH CHECK (true);

-- 3.2 driver_locations: SELECT was auth.role()='authenticated' (live finding:
-- any authenticated user could read every driver's live location). Now only
-- ride participants, the owning driver, and admins.
DROP POLICY IF EXISTS "driver location read" ON public.driver_locations;
CREATE POLICY "driver location read" ON public.driver_locations
  FOR SELECT
  USING (
    public.is_admin()
    OR driver_id IN (SELECT id FROM public.drivers WHERE user_id = auth.uid())
    OR (
      ride_id IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.rides r
        WHERE r.id = driver_locations.ride_id
          AND (
            r.rider_id = auth.uid()
            OR r.driver_id IN (SELECT id FROM public.drivers WHERE user_id = auth.uid())
          )
      )
    )
  );

-- 3.3 sos_alerts: add admin SELECT (Emergency Command Center feed; the table
-- is already published to supabase_realtime).
DROP POLICY IF EXISTS "sos alerts admin select" ON public.sos_alerts;
CREATE POLICY "sos alerts admin select" ON public.sos_alerts
  FOR SELECT USING (public.is_admin());

-- ─── 4. GUARD TRIGGERS (server-authoritative chat fields) ─────

CREATE OR REPLACE FUNCTION public.chat_rooms_fixup_insert()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  -- SECURITY DEFINER RPC context (current_user = owner, session_user = caller)
  -- is trusted: RPCs validate server-side. Direct client writes by non-admins
  -- are forced to the safe default contract.
  IF current_user IS DISTINCT FROM session_user THEN
    RETURN NEW;
  END IF;
  IF NOT public.is_admin() THEN
    NEW.priority := 'low';
    NEW.status := 'open';
    NEW.assigned_admin_id := NULL;
    NEW.assigned_at := NULL;
    NEW.escalated_at := NULL;
    NEW.escalated_from_admin_id := NULL;
    NEW.closed_at := NULL;
  END IF;
  IF NEW.region_id IS NULL THEN
    SELECT region_id INTO NEW.region_id
    FROM public.user_region_preferences
    WHERE user_id = auth.uid()
    ORDER BY updated_at DESC
    LIMIT 1;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS chat_rooms_fixup_insert ON public.chat_rooms;
CREATE TRIGGER chat_rooms_fixup_insert
  BEFORE INSERT ON public.chat_rooms
  FOR EACH ROW
  EXECUTE FUNCTION public.chat_rooms_fixup_insert();

CREATE OR REPLACE FUNCTION public.chat_rooms_fixup_update()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF current_user IS DISTINCT FROM session_user THEN
    RETURN NEW;
  END IF;
  IF NOT public.is_admin() THEN
    NEW.priority := OLD.priority;
    NEW.status := OLD.status;
    NEW.assigned_admin_id := OLD.assigned_admin_id;
    NEW.assigned_at := OLD.assigned_at;
    NEW.escalated_at := OLD.escalated_at;
    NEW.escalated_from_admin_id := OLD.escalated_from_admin_id;
    NEW.closed_at := OLD.closed_at;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS chat_rooms_fixup_update ON public.chat_rooms;
CREATE TRIGGER chat_rooms_fixup_update
  BEFORE UPDATE ON public.chat_rooms
  FOR EACH ROW
  EXECUTE FUNCTION public.chat_rooms_fixup_update();

-- ─── 5. ROUTING + SUPPORT/EMERGENCY RPCs (016 pattern) ────────

-- Internal audit backplane helper. Insertable only by service_role /
-- the SECURITY DEFINER table-owner context (activity_logs policy 3.1).
CREATE OR REPLACE FUNCTION public.write_audit(
  p_action text,
  p_resource text,
  p_resource_id text DEFAULT NULL,
  p_details jsonb DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  INSERT INTO public.activity_logs
    (user_id, action, resource, resource_id, details, timestamp)
  VALUES (
    auth.uid()::text,
    p_action,
    p_resource,
    p_resource_id,
    p_details,
    now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.write_audit(text, text, text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.write_audit(text, text, text, jsonb)
  TO service_role;

-- Deterministic best-support-admin resolver (internal; customers never call).
-- Tiers: region-scoped (recursive ancestor walk, most-specific first) ->
-- global admins (no assignment rows) -> owner (implicit global). Deterministic
-- tiebreak: fewest open assigned rooms, then lowest admin_id.
CREATE OR REPLACE FUNCTION public.resolve_support_admin(
  p_region_id uuid,
  p_prefer_region boolean DEFAULT true,
  p_exclude_admin_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_admin_id uuid;
BEGIN
  IF p_prefer_region AND p_region_id IS NOT NULL THEN
    SELECT best.admin_id
      INTO v_admin_id
      FROM (
        WITH RECURSIVE chain(id, parent_id, depth) AS (
          SELECT r.id, r.parent_region_id, 0
          FROM public.regions r
          WHERE r.id = p_region_id
          UNION ALL
          SELECT r.id, r.parent_region_id, c.depth + 1
          FROM public.regions r
          JOIN chain c ON r.id = c.parent_id
          WHERE c.depth <= 10
        )
        SELECT a.admin_id,
               MIN(c.depth) AS eff_depth,
               COUNT(DISTINCT r2.id) FILTER (
                 WHERE r2.status IN ('open','assigned')) AS open_count
        FROM public.admin_region_assignments a
        JOIN chain c ON c.id = a.region_id
        LEFT JOIN public.chat_rooms r2 ON r2.assigned_admin_id = a.admin_id
        JOIN public.users u ON u.id = a.admin_id AND u.role = 'admin'
        WHERE (a.scope = 'self' AND c.depth = 0)
           OR a.scope = 'descendants'
        GROUP BY a.admin_id
      ) best
      WHERE best.admin_id IS DISTINCT FROM p_exclude_admin_id
      ORDER BY best.eff_depth ASC, best.open_count ASC, best.admin_id ASC
      LIMIT 1;
    IF v_admin_id IS NOT NULL THEN
      RETURN v_admin_id;
    END IF;
  END IF;

  SELECT u.id
    INTO v_admin_id
    FROM public.users u
    LEFT JOIN public.admin_region_assignments a ON a.admin_id = u.id
    LEFT JOIN public.chat_rooms r2
           ON r2.assigned_admin_id = u.id AND r2.status IN ('open','assigned')
   WHERE u.role = 'admin'
     AND a.admin_id IS NULL
     AND u.id IS DISTINCT FROM p_exclude_admin_id
   GROUP BY u.id
   ORDER BY COUNT(DISTINCT r2.id) ASC, u.id ASC
   LIMIT 1;
  IF v_admin_id IS NOT NULL THEN
    RETURN v_admin_id;
  END IF;

  SELECT u.id
    INTO v_admin_id
    FROM public.users u
   WHERE u.role = 'owner'
     AND u.id IS DISTINCT FROM p_exclude_admin_id
   ORDER BY u.id ASC
   LIMIT 1;

  RETURN v_admin_id;
END;
$$;

REVOKE ALL ON FUNCTION public.resolve_support_admin(uuid, boolean, uuid)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.resolve_support_admin(uuid, boolean, uuid)
  TO service_role;

-- Assign a room to an admin (server-side only; never overwrite an existing
-- assignee here — escalation/assign RPCs manage that explicitly).
CREATE OR REPLACE FUNCTION public._assign_chat_to_admin(
  p_room_id uuid,
  p_admin_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_customer_id uuid;
BEGIN
  UPDATE public.chat_rooms
     SET assigned_admin_id = p_admin_id,
         assigned_at = now(),
         status = p_status
   WHERE id = p_room_id;

  SELECT participant_ids[1] INTO v_customer_id
  FROM public.chat_rooms WHERE id = p_room_id;

  INSERT INTO public.notifications
    (user_id, title, body, type, data, deep_link, idempotency_key)
  VALUES (
    p_admin_id,
    CASE WHEN p_status = 'assigned' THEN 'New support chat assigned' ELSE 'Support chat escalated' END,
    'Room ' || p_room_id::text,
    CASE WHEN p_status = 'assigned' THEN 'chat_assigned' ELSE 'chat_escalated' END,
    jsonb_build_object('room_id', p_room_id::text),
    '/admin/support-chat/room/' || p_room_id::text,
    'chat-assign-' || p_room_id::text || '-' || p_admin_id::text
  )
  ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;
END;
$$;

-- Route an open unassigned room to the best admin (admin RPC).
CREATE OR REPLACE FUNCTION public.route_support_chat(p_room_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_room public.chat_rooms%ROWTYPE;
  v_admin_id uuid;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  SELECT * INTO v_room FROM public.chat_rooms WHERE id = p_room_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Room not found';
  END IF;
  IF v_room.status = 'closed' THEN
    RAISE EXCEPTION 'Room is closed';
  END IF;
  IF v_room.assigned_admin_id IS NOT NULL THEN
    RETURN v_room.assigned_admin_id;
  END IF;

  v_admin_id := public.resolve_support_admin(v_room.region_id, true);
  IF v_admin_id IS NULL THEN
    RETURN NULL;
  END IF;

  PERFORM public._assign_chat_to_admin(p_room_id, v_admin_id, 'assigned');
  PERFORM public.write_audit(
    'SUPPORT_ASSIGNED', 'chat_rooms', p_room_id::text,
    jsonb_build_object('admin_id', v_admin_id, 'priority', v_room.priority)
  );
  RETURN v_admin_id;
END;
$$;

REVOKE ALL ON FUNCTION public.route_support_chat(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.route_support_chat(uuid) TO authenticated;

-- Manual assignment (override) by an admin.
CREATE OR REPLACE FUNCTION public.assign_support_chat(
  p_room_id uuid,
  p_admin_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_room public.chat_rooms%ROWTYPE;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  SELECT * INTO v_room FROM public.chat_rooms WHERE id = p_room_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Room not found';
  END IF;
  IF v_room.status = 'closed' THEN
    RAISE EXCEPTION 'Room is closed';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.users WHERE id = p_admin_id AND role IN ('admin','owner')
  ) THEN
    RAISE EXCEPTION 'Assignee must be an admin';
  END IF;

  PERFORM public._assign_chat_to_admin(p_room_id, p_admin_id, 'assigned');
  PERFORM public.write_audit(
    'SUPPORT_ASSIGNED', 'chat_rooms', p_room_id::text,
    jsonb_build_object(
      'admin_id', p_admin_id,
      'from_admin_id', auth.uid(),
      'manual', true,
      'priority', v_room.priority
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.assign_support_chat(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.assign_support_chat(uuid, uuid)
  TO authenticated;

-- Escalate: record the escalation, then re-route to the next tier EXCLUDING
-- the current assignee (never re-assigns the escalator). Terminal owner
-- escalation -> status 'escalated', unassigned (owner queue).
CREATE OR REPLACE FUNCTION public.escalate_support_chat(
  p_room_id uuid,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_room public.chat_rooms%ROWTYPE;
  v_current uuid;
  v_next uuid;
  v_prev_scope text;
  v_new_scope text;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'Escalation requires a reason';
  END IF;
  SELECT * INTO v_room FROM public.chat_rooms WHERE id = p_room_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Room not found';
  END IF;
  IF v_room.status = 'closed' THEN
    RAISE EXCEPTION 'Room is closed';
  END IF;

  v_current := v_room.assigned_admin_id;
  v_prev_scope := CASE
    WHEN v_current IS NULL THEN 'unassigned'
    WHEN EXISTS (SELECT 1 FROM public.users WHERE id = v_current AND role = 'owner') THEN 'owner'
    WHEN EXISTS (SELECT 1 FROM public.admin_region_assignments WHERE admin_id = v_current) THEN 'scoped'
    ELSE 'global'
  END;

  UPDATE public.chat_rooms
     SET escalated_at = now(),
         escalated_from_admin_id = auth.uid()
   WHERE id = p_room_id;

  -- Owner/escalator terminal -> owner queue.
  IF v_current IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.users WHERE id = v_current AND role = 'owner'
  ) THEN
    UPDATE public.chat_rooms
       SET status = 'escalated', assigned_admin_id = NULL
     WHERE id = p_room_id;
    INSERT INTO public.chat_escalations
      (room_id, previous_admin_id, new_admin_id, actor_id, reason,
       previous_scope, new_scope)
    VALUES (p_room_id, v_current, NULL, auth.uid(), p_reason,
            v_prev_scope, 'owner');
    PERFORM public.write_audit(
      'SUPPORT_ESCALATED', 'chat_rooms', p_room_id::text,
      jsonb_build_object('reason', p_reason, 'from_admin_id', auth.uid(),
                         'to_admin_id', NULL, 'terminal', true)
    );
    RETURN;
  END IF;

  v_next := public.resolve_support_admin(v_room.region_id, true, v_current);
  IF v_next IS NULL OR v_next = v_current THEN
    UPDATE public.chat_rooms
       SET status = 'escalated', assigned_admin_id = NULL
     WHERE id = p_room_id;
    v_new_scope := 'owner';
  ELSE
    PERFORM public._assign_chat_to_admin(p_room_id, v_next, 'assigned');
    v_new_scope := CASE
      WHEN EXISTS (SELECT 1 FROM public.users WHERE id = v_next AND role = 'owner') THEN 'owner'
      WHEN EXISTS (SELECT 1 FROM public.admin_region_assignments WHERE admin_id = v_next) THEN 'scoped'
      ELSE 'global'
    END;
  END IF;

  INSERT INTO public.chat_escalations
    (room_id, previous_admin_id, new_admin_id, actor_id, reason,
     previous_scope, new_scope)
  VALUES (p_room_id, v_current, v_next, auth.uid(), p_reason,
          v_prev_scope, v_new_scope);

  PERFORM public.write_audit(
    'SUPPORT_ESCALATED', 'chat_rooms', p_room_id::text,
    jsonb_build_object('reason', p_reason, 'from_admin_id', auth.uid(),
                       'to_admin_id', v_next, 'previous_scope', v_prev_scope,
                       'new_scope', v_new_scope)
  );

  INSERT INTO public.notifications
    (user_id, title, body, type, data, deep_link, idempotency_key)
  VALUES (
    (SELECT participant_ids[1] FROM public.chat_rooms WHERE id = p_room_id),
    'Support chat escalated',
    'Your chat has been escalated to the next support level.',
    'chat_escalated',
    jsonb_build_object('room_id', p_room_id::text),
    '/support/room/' || p_room_id::text,
    'chat-escalated-customer-' || p_room_id::text
  );
END;
$$;

REVOKE ALL ON FUNCTION public.escalate_support_chat(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.escalate_support_chat(uuid, text)
  TO authenticated;

-- Emergency lane (ADR-052): any authenticated user opens a priority=emergency
-- support room; region resolved via geo_region_for_point (HIGH/MEDIUM only);
-- immediate auto-route region -> parent -> global -> owner.
CREATE OR REPLACE FUNCTION public.open_emergency_chat(
  p_lat double precision,
  p_lon double precision,
  p_message text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_room_id uuid;
  v_region_id uuid;
  v_admin_id uuid;
  v_customer_id uuid := auth.uid();
BEGIN
  SELECT g.region_id INTO v_region_id
  FROM public.geo_region_for_point(p_lat, p_lon, 2, 25000) g
  WHERE g.confidence IN ('HIGH','MEDIUM')
  LIMIT 1;

  INSERT INTO public.chat_rooms
    (room_type, participant_ids, priority, status, region_id)
  VALUES
    ('support', ARRAY[v_customer_id], 'emergency', 'open', v_region_id)
  RETURNING id INTO v_room_id;

  IF p_message IS NOT NULL AND btrim(p_message) <> '' THEN
    INSERT INTO public.chat_messages
      (room_id, sender_id, message, message_type)
    VALUES (v_room_id, v_customer_id, p_message, 'text');
  END IF;

  v_admin_id := public.resolve_support_admin(v_region_id, true);
  IF v_admin_id IS NOT NULL THEN
    PERFORM public._assign_chat_to_admin(v_room_id, v_admin_id, 'assigned');
    INSERT INTO public.notifications
      (user_id, title, body, type, data, deep_link, idempotency_key)
    VALUES (
      v_admin_id,
      'EMERGENCY support request',
      'Immediate assistance required.',
      'emergency_alert',
      jsonb_build_object('room_id', v_room_id::text, 'region_id', v_region_id),
      '/admin/support-chat/room/' || v_room_id::text,
      'emergency-alert-' || v_room_id::text
    );
  END IF;

  PERFORM public.write_audit(
    'EMERGENCY_OPENED', 'chat_rooms', v_room_id::text,
    jsonb_build_object('region_id', v_region_id, 'assigned_admin_id', v_admin_id,
                       'lat', p_lat, 'lon', p_lon)
  );

  RETURN v_room_id;
END;
$$;

REVOKE ALL ON FUNCTION public.open_emergency_chat(
  double precision, double precision, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.open_emergency_chat(
  double precision, double precision, text) TO authenticated;

-- Close a room (owner-participant or admin).
CREATE OR REPLACE FUNCTION public.close_support_chat(p_room_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_room public.chat_rooms%ROWTYPE;
BEGIN
  SELECT * INTO v_room FROM public.chat_rooms WHERE id = p_room_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Room not found';
  END IF;
  IF NOT (public.is_admin()
          OR auth.uid() = ANY (v_room.participant_ids)) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  UPDATE public.chat_rooms
     SET status = 'closed', closed_at = now(), is_active = false
   WHERE id = p_room_id;

  PERFORM public.write_audit(
    'SUPPORT_CLOSED', 'chat_rooms', p_room_id::text,
    jsonb_build_object('priority', v_room.priority, 'assigned_admin_id', v_room.assigned_admin_id)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.close_support_chat(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.close_support_chat(uuid) TO authenticated;

-- ─── 6. AUTO-ROUTE TRIGGER (new non-emergency rooms) ──────────
-- After a customer opens a room, route it immediately (deterministic best
-- admin). Emergency rooms are owned by open_emergency_chat; never overwrite
-- an already-assigned room (ADR-050 persistence rule).
CREATE OR REPLACE FUNCTION public.chat_rooms_auto_route()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_admin_id uuid;
BEGIN
  IF NEW.priority = 'emergency' OR NEW.status = 'closed' THEN
    RETURN NEW;
  END IF;
  IF NEW.assigned_admin_id IS NOT NULL THEN
    RETURN NEW;
  END IF;
  v_admin_id := public.resolve_support_admin(NEW.region_id, true);
  IF v_admin_id IS NOT NULL THEN
    PERFORM public._assign_chat_to_admin(NEW.id, v_admin_id, 'assigned');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS chat_rooms_auto_route ON public.chat_rooms;
CREATE TRIGGER chat_rooms_auto_route
  AFTER INSERT ON public.chat_rooms
  FOR EACH ROW
  EXECUTE FUNCTION public.chat_rooms_auto_route();

COMMIT;
