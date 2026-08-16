# Phase 2.3 — Support Chat Priority, Region & Assignment (Architecture + Implementation Audit)

**Session:** 49 · **Gate type:** architecture-only (NO code, NO migration, NO commit/push)
**Repository HEAD:** `b1081d2` (`sprint 76: complete Egypt geographic coverage`) · branch `master` clean
**Live project:** `bttnlkmwhorjamzemwda` (Management API via `/tmp/opencode/sq.py`, PAT never committed)
**Authorities:** `PROJECT_CONSTITUTION.md` · AGENTS.md · `PROJECT_CONSTITUTION`-consistent docs 25/26/28 · ADR-049/050/051/052/055/056/057
**This doc supersedes:** the Phase 2.3 contract section of `28_SPRINT_76_PHASE_2_2_ADMIN_HIERARCHY_AUDIT.md` (§5) with a concrete, evidence-backed design.

---

## 1. Existing Infrastructure (reusable — nothing to rebuild)

| # | Asset | Live state (this session) | Reuse in 2.3 |
|---|-------|---------------------------|--------------|
| R1 | `chat_rooms` | cols: `id, room_type, participant_ids uuid[], order_id, complaint_id, is_active, last_message_at, created_at, updated_at` · RLS 016 (participant owner + admin select-all) · already in `supabase_realtime` | **Extended** (additive, ADR-051/052). Realtime broadcast reused. |
| R2 | `chat_messages` | cols: `id, room_id, sender_id, message, message_type, attachment_url, is_read, read_at, created_at` · in `supabase_realtime` | Reused unchanged for messaging. |
| R3 | `complaints` | `status incl. 'escalated'`, `priority ('low','medium','high','urgent')`, admin_notes, resolved_at — **priority set matches 2.3's** | Priority vocabulary reused verbatim. |
| R4 | `notifications` | `type` is **unconstrained `text`** (no CHECK) → new types need **zero schema change** · cols incl. `data jsonb, deep_link, idempotency_key` · in `supabase_realtime` | Insert rows from routing/escalation RPCs → realtime in-app delivery (018 path). |
| R5 | `notification_tokens` | 13 rows · RLS user-own / admin-select (016) | Target audience for assignee push (FCM needs keys; in-app realtime works today). |
| R6 | `users` (identity) | 5 rows: 3 customer · 1 provider · **1 owner** `8a23b719-…` · **0 admin** | Routing fallback = owner (deterministic today). |
| R7 | `user_region_preferences` | cols: `user_id, region_id, source, updated_at` (NO `is_verified`) | Routing join: customer region → nearest admin. |
| R8 | `admin_region_assignments` | 031 applied live: `admin_id, region_id, scope('self'|'descendants'), created_at, created_by` · not in realtime | Routing source (ADR-055). |
| R9 | `is_admin()` / `is_admin_for_region()` | 016 + 031, `is_admin_for_region` single-level descendant check | New routing uses a **recursive ancestor walk** (see §5). |
| R10 | `geo_region_for_point(lat, lon, max_depth, tolerance)` | 032: HIGH/MEDIUM/LOW confidence, EXECUTE authenticated-only | Emergency room region resolution. |
| R11 | `regions` | 28 rows · `parent_region_id` self-FK (030/ADR-050) | Recursive walk for routing/ancestors. |
| R12 | `activity_logs` | exists, `details jsonb`, admin-gated via `is_admin()` after 031 | Escalation audit backplane (see §8). |
| R13 | Flutter `support_chat` module | entities `ChatRoom`/`ChatMessage` · `SupabaseChatDataSource` · `chatRepositoryProvider` · `chatRoomsProvider` (admin-gated `getAllRooms` vs `getMyRooms`) · `chatMessagesProvider(roomId)` · `chatMessageStreamProvider(roomId)` (repo stream) · pages: `admin_support_chat_page`, `client_support_page`, `support_chat_room_page` | Extended in place. |
| R14 | Flutter `admin_access.dart` | `isAdminRoleString`/`isAdminUser`/`User.isAdmin` (016 mirror) | Admin UI gates. |
| R15 | Push/realtime service | `push_notification_service.dart`: FCM + local notif + realtime `in-app-notifications` channel → invalidates `notificationsProvider`/`unreadCountProvider` | New chat notifications ride this channel unchanged. |
| R16 | Migration numbering | next free = **033** (032 schema + 032 seed exist; no 033) | Migration name below. |

---

## 2. Missing Infrastructure (what 2.3 must add)

| # | Gap | Consequence today | 2.3 addition |
|---|-----|-------------------|--------------|
| M1 | No priority on `chat_rooms` | Every chat is equal; no triage | `priority` column + CHECK (extended set, ADR-052) |
| M2 | No `region_id` on `chat_rooms` | Can't route to local admin | `region_id` FK + routing |
| M3 | No assignment | Admins see *all* rooms unfiltered (`getAllRooms`), no ownership | `assigned_admin_id` + auto-route |
| M4 | No status lifecycle | Only `is_active` | `status` + escalation columns |
| M5 | No routing engine | `/admin/support-chat` is a flat list | `resolve_support_admin` + `route_support_chat` |
| M6 | No emergency path | No highest-priority lane | `open_emergency_chat` RPC (ADR-052) |
| M7 | No server-enforced priority lock | Client could set any priority | Insert/update triggers guard priority/status/assignee |
| M8 | No notification for assignment/escalation | Admin never notified | `notifications` rows + realtime in-app |

---

## 3. Schema Diff — MIGRATION `033_support_chat_priority_region_assignment.sql` (spec, NOT written)

All **additive** on `chat_rooms` (ADR-051: extend, never replace the 016/`participant_ids` model).

```sql
ALTER TABLE public.chat_rooms
  ADD COLUMN priority text NOT NULL DEFAULT 'low'
    CHECK (priority IN ('low','medium','high','urgent','emergency')),   -- complaints vocabulary + emergency (ADR-052)
  ADD COLUMN region_id uuid REFERENCES public.regions(id),              -- routing key (null = region unknown)
  ADD COLUMN assigned_admin_id uuid REFERENCES public.users(id),        -- current assignee (null = unassigned)
  ADD COLUMN assigned_at timestamptz,                                  -- SLA/response-time basis (additive)
  ADD COLUMN status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','assigned','escalated','closed')),        -- contract set
  ADD COLUMN escalated_at timestamptz,                                 -- last escalation timestamp
  ADD COLUMN escalated_from_admin_id uuid REFERENCES public.users(id), -- who escalated
  ADD COLUMN closed_at timestamptz;                                    -- audit; syncs with is_active=false

CREATE INDEX IF NOT EXISTS chat_rooms_status_idx        ON public.chat_rooms (status);
CREATE INDEX IF NOT EXISTS chat_rooms_assigned_idx      ON public.chat_rooms (assigned_admin_id);
CREATE INDEX IF NOT EXISTS chat_rooms_region_idx        ON public.chat_rooms (region_id);
CREATE INDEX IF NOT EXISTS chat_rooms_priority_idx      ON public.chat_rooms (priority);
CREATE INDEX IF NOT EXISTS chat_rooms_open_partial_idx  ON public.chat_rooms (assigned_admin_id)
  WHERE status IN ('open','assigned');                                  -- routing + admin queue
```

- **No new table** in 2.3 (escalation audit lives on-row + `activity_logs`; `escalation_events` = 2.5 per contract).
- `is_active` remains the legacy flag; the `close` RPC sets `status='closed', closed_at=now(), is_active=false` atomically.
- `notifications.type` needs **no** migration (unconstrained text — verified live §1-R4).

---

## 4. Security Model (RLS + triggers + RPCs, 016 pattern throughout)

### 4.1 RLS drift fixes already done
`chat_rooms`/`chat_messages`/`complaints`/`notifications`/`notification_tokens` already gate admin ops via `is_admin()` (016) or were fixed in 031. No F1-style literal-`role='admin'` drift on the 2.3 surface (re-verified in §1/§2 and 028-F1/F2 status ✅).

### 4.2 Guard triggers (customer priority lock — M7)
- `chat_rooms_fixup_insert()` **BEFORE INSERT** (SECURITY DEFINER, `SET search_path=public,pg_temp`):
  - if `NOT is_admin()`: force `priority='low'`, `status='open'`, `assigned_admin_id=NULL`, `escalated_from_admin_id=NULL`, `escalated_at=NULL` (server authority — customers **cannot** set priority per 028 §5 contract);
  - if `NEW.region_id IS NULL`: backfill from `user_region_preferences` (deepest) → else leave null.
- `chat_rooms_fixup_update()` **BEFORE UPDATE** (SECURITY DEFINER): if `NOT is_admin()`, restore `priority, status, assigned_admin_id, escalated_at, escalated_from_admin_id, closed_at` to `OLD` values (customers may only change `is_active`/message-level fields).

### 4.3 RPCs (016 pattern: `SECURITY DEFINER` + `SET search_path` + `REVOKE … FROM anon` + `GRANT EXECUTE TO authenticated`)
| RPC | Gate | Effect |
|-----|------|--------|
| `resolve_support_admin(p_region_id uuid, p_prefer_region boolean DEFAULT true)` | — (internal helper, EXECUTE revoked from public) | returns best admin id or owner (algorithm §5) |
| `route_support_chat(p_room_id uuid)` | `is_admin()` | re-runs routing for a room, updates assignee/status/assigned_at, inserts notifications |
| `assign_support_chat(p_room_id uuid, p_admin_id uuid)` | `is_admin()` | manual assignment (override), notifies assignee + customer |
| `escalate_support_chat(p_room_id uuid, p_reason text)` | `is_admin()` | records escalation, re-routes to next tier (§8) |
| `open_emergency_chat(p_lat double precision, p_lon double precision, p_message text)` | `authenticated` (any user) | creates `priority='emergency'` room, resolves region via `geo_region_for_point`, routes immediately, pushes emergency alert (§10) |
| `close_support_chat(p_room_id uuid)` | existing owner-participant or admin | status→closed + closed_at + is_active=false |

- All mutations go through RPCs or the guarded triggers; RLS remains as the backstop.
- Route/assignment decisions are **server-side only** — clients never pick admins (contract).

---

## 5. Routing Model (server-side, deterministic)

**Input:** `p_region_id` (null-safe) · **Tiers, in order** (ADR-055 ranking + 028 §4.2 escalation-parent walk):

1. **Scoped admins** (`role='admin'` with `admin_region_assignments` rows): recursive **ancestor chain** of `p_region_id` up `regions.parent_region_id` (arbitrary depth — the 028 §4.5 note now becomes a recursive CTE, not a single-level join):
   ```sql
   WITH RECURSIVE chain(id, parent_id, depth) AS (
     SELECT r.id, r.parent_region_id, 0 FROM public.regions r WHERE r.id = p_region_id
     UNION ALL
     SELECT r.id, r.parent_region_id, c.depth + 1
     FROM public.regions r JOIN chain c ON r.id = c.parent_id
   )
   SELECT a.admin_id
     FROM public.admin_region_assignments a
     JOIN chain c ON c.id = a.region_id
    WHERE (a.scope = 'self' AND c.depth = 0)
       OR (a.scope = 'descendants')
    ORDER BY c.depth ASC            -- most specific assignment first
   ```
   Tiebreak: admin with fewest open assigned rooms, then lowest `admin_id` (stable/deterministic).
2. **Global admins** (`role='admin'`, **no** assignment rows = global scope, ADR-055): same load/`admin_id` tiebreak.
3. **Owner** (`role='owner'`, implicit global): deterministic lowest `id`. Live today = `8a23b719-…` (0 admins ⇒ owner receives every room — verified baseline, §1-R6).
4. `NULL` if no admin-tier user exists → room stays `status='open'`, unassigned (safe default; admin list UI shows it).

**Emergency variant** (`open_emergency_chat`, `p_prefer_region=true` then fall through): region-scoped → global → any admin → owner, i.e. tolerance for no local match.

**Persistence rule (ADR-050 confidence):** route only on HIGH/MEDIUM `geo_region_for_point` for emergency; customer preferences always override for normal rooms; never overwrite an already-assigned room.

---

## 6. Escalation Model (2.3 slice — full engine is 2.5)

- **Trigger:** `escalate_support_chat(p_room_id, p_reason)` — any admin. Records `escalated_at=now()`, `escalated_from_admin_id=auth.uid()`, `status='escalated'`, then **re-routes** to the next tier: current assignee's region parent admin → global admin → owner (never re-assigns the escalator themselves).
  - Higher admin found → `assigned_admin_id=new, status='assigned', assigned_at=now()`, push to new assignee.
  - No higher admin (owner is escalator) → `status='escalated'`, `assigned_admin_id=NULL` (owner queue; admin list surfaces it).
- **Audit trail (no new table):** `chat_rooms` columns (`escalated_at`, `escalated_from_admin_id`, full `assigned_admin_id`/`assigned_at`/`status` history visible) **+** one `activity_logs` row (`action='support_chat.escalate'`, `resource='chat_rooms'`, `resource_id=room_id`, `details = jsonb {reason, from_admin_id}`). `activity_logs` is `is_admin()`-gated (031-fixed) — safe backplane.
- **`escalation_events` table + engine RPCs = Phase 2.5** (028 §5, untouched now).
- **Complaints:** `status='escalated'` remains UI-only in 2.3; wiring complaints escalation to real assignment is 2.5 (028 §5 row).

---

## 7. Realtime Model (reuse, no new publication)

- `chat_messages`/`chat_rooms`/`notifications` are **already published** (§1-R1/R2/R4). No publication change.
- **Admin rooms feed:** subscribe `postgres_changes` on `chat_rooms` (RLS already yields admin-visible rows); client-side filter to `status IN ('open','assigned')` for the queue, refresh on `UPDATE` (assignment/escalation/priority) and `INSERT` (new room) — broadcasts ride existing row events.
- **Room page:** unchanged `chatMessageStreamProvider(roomId)` (018/016 pattern) for messages.
- **In-app notifications:** existing `in-app-notifications` channel delivers assignment/escalation/emergency rows → badge/banner (zero new wiring; verified 018 path).
- Realtime is **not** the authorization boundary — RLS is (unchanged).

---

## 8. Notification Model (034 pre-split — reusable, deferred FCM)

| Event | `type` (new, unconstrained) | `title`/`body` | `deep_link` | `data` |
|-------|------------------------------|----------------|-------------|--------|
| New room auto-routed | `chat_assigned` | "New support chat assigned" | `/admin/support-chat/room/{roomId}` | `{room_id, priority, customer_id}` |
| Manual assign | `chat_assigned` | same | same | `{room_id, priority}` |
| Escalation | `chat_escalated` | "Support chat escalated" | same | `{room_id, reason, from_admin_id}` |
| Emergency opened | `emergency_alert` | "EMERGENCY support request" | same | `{room_id, lat, lon, region_code}` |
| Room closed | `room_closed` | "Support chat closed" | `/support/room/{roomId}` | `{room_id}` |

- Delivery = `notifications` insert → realtime in-app (018, works with no keys). **FCM** to `notification_tokens` needs keys → lands with 2.4/034 (unchanged; admin broadcast RPC 019 pattern shows the shape).
- Push service (`push_notification_service.dart`) already invalidates `notificationsProvider`/`unreadCountProvider` on the channel — chat notifications surface automatically.

---

## 9. Emergency Model (ADR-052: emergency = `priority='emergency'`, not a second engine)

- **Lane:** dedicated `open_emergency_chat(lat, lon, message)` RPC (any authenticated user) → room with `priority='emergency'`, region via `geo_region_for_point` (HIGH/MEDIUM only), **immediate** auto-route to highest-available admin (region→global→owner), `emergency_alert` push + in-app, red UX treatment.
- **SLA (display-tier, no cron in 2.3):** emergency ≤ 60s · high ≤ 5m · urgent ≤ 15m · normal ≤ 24h first response, computed from `assigned_at`→`last_message_at` deltas; rendered as badges in admin UI. Server-enforced timers/cron deferred (no pg_cron; documented).
- **Separation:** `sos_alerts` stays a distinct ride-safety signal (Phase 2.0 audit) — emergency *chat* is the support lane; no conflation.
- **Ownership invariant:** `priority='emergency'` is **server-set only** (guarded triggers §4.2) — customers trigger the lane via the RPC, never via the column.

---

## 10. UX Contract (Flutter, additive to existing pages)

**Admin (`admin_support_chat_page.dart` + room page):**
- Room card: priority chip (colored: emergency=red pulsing, urgent=orange, high=amber, low/normal=neutral), status chip, region label, assigned-to label.
- Filter/sort bar: by priority, status (open/assigned/escalated), region (reuses `regionSearchProvider`/governorates from 032), assigned-to-me.
- Room actions: **Assign** (to self or pick admin), **Escalate** (with reason dialog), **Close**.
- Emergency lane: top-stacked section (or auto-open) for `priority='emergency'` + SLA countdown badge.
- Provider refactors: `chatRoomsProvider` gets priority/status/region-aware queries + realtime refresh; new `adminChatQueueProvider` (filtered, watching realtime).

**Customer (`client_support_page.dart` + room page):**
- New **Emergency** button (red) → `open_emergency_chat` flow (lat/lon from location service, message) → immediate confirmation + room opens.
- Normal chat unchanged (start → priority locked `low` server-side).
- Room page: priority/status banner (esp. emergency), assignee "support team" note; **no** priority picker (contract).

---

## 11. Migration 033 — Application Strategy (apply pattern, per 028 §6)

1. **Pre-apply gate (implementation session):** `flutter analyze` + `flutter test` green; live read-only baseline reconfirm (§1).
2. **Write 033** — additive DDL + guard triggers + RPCs, 016 pattern for every function, revoke-before-grant (030 lesson: `ALTER DEFAULT PRIVILEGES` auto-grants anon EXECUTE).
3. **Apply** via Management API `bttnlkmwhorjamzemwda`; **verify live** before touching Flutter: schema (columns/constraints/indexes), ACL matrix (anon revoked, authenticated-only EXECUTE), functional RLS probes (owner-vs-admin-vs-customer priority lock, routing matrix §13).
4. **Flutter** changes per sub-phases §14 (0 admin→owner fallback verified against live `8a23b719-…`).
5. Gate: `flutter pub get && flutter analyze && flutter test` → commit `sprint N: ...` → push.

---

## 12. Test Strategy

- **SQL live probes (read-only first, then on 033):**
  - Routing matrix: customer with region pref → scoped admin; no local admin → global; no admins → owner (live today = owner); no admin-tier at all → NULL/unassigned.
  - Priority lock: customer INSERT/UPDATE cannot set priority/status/assignee (trigger resets); admin can.
  - Escalation: tier walk, escalator never re-assigned, owner-escalator terminal `escalated` state.
  - Emergency: region HIGH/MEDIUM resolution, immediate assign + `emergency_alert` row.
  - ACL: `anon` revoked EXECUTE on every new function; `authenticated` only.
- **Unit (Dart):** routing/priority mapping helpers, status/priority chips, filter logic.
- **Dart integration (mocktail):** `AdminChatRepository.assign/escalate/close`, `openEmergencyChat` repository method, provider refresh on realtime event.
- **Regression:** 731/731 existing tests stay green; support_chat/complaints/notifications/regions suites untouched-or-passing.

---

## 13. Risk Register

| # | Risk | Sev | Mitigation |
|---|------|-----|-----------|
| V1 | Customer bypasses priority lock via direct UPDATE | High | Guard triggers force priority/status/assignee for non-admins (§4.2); RLS backstop |
| V2 | Recursive ancestor walk unbounded/costly | Med | `depth` cap in CTE (`WHERE c.depth <= 10`), 28-region tree = trivial; index on `parent_region_id` |
| V3 | `is_admin_for_region` single-level vs routing recursion divergence | Med | Routing uses its own recursive CTE (documented, §5); 2.2 helper untouched (contract note honored) |
| V4 | 0 admins live → owner receives everything | Low (expected) | Verified baseline; deterministic owner fallback; seeding admins = 028 Q3 decision, not repeated |
| V5 | Realtime all-rooms feed noise at scale | Low | Client-side status filter + partial index; 2.6 hardening |
| V6 | SLA countdowns need timers (no cron) | Med | Display-only SLA in 2.3; documented 2.5/2.6 |
| V7 | FCM absent (no keys) | Med | In-app realtime delivery works today (018); FCM with 2.4/034 |
| V8 | Emergency region LOW confidence | Med | Persist only HIGH/MEDIUM; LOW → region null → global/owner route |

---

## 14. Sub-Phases (implementation order, from the gate sequence)

| Step | Scope | Exit |
|------|-------|------|
| 2.3.1 | Schema 033 (DDL + indexes) applied + live verified | schema probe green |
| 2.3.2 | Guard triggers + RPCs (`resolve/route/assign/escalate/open_emergency/close`) + ACL | RLS/RPC matrix green |
| 2.3.3 | Domain/data: `ChatRepository` + impl new methods; entities `priority/status/regionId/assignedAdminId/…` | Dart compiles + unit tests |
| 2.3.4 | Routing/escalation wired through repo + providers (`adminChatQueueProvider`) | integration tests |
| 2.3.5 | Realtime: rooms feed refresh + message stream reuse | realtime probe on device |
| 2.3.6 | Notifications: insert rows on assign/escalate/emergency + deep links | in-app delivery verified |
| 2.3.7 | Emergency: `open_emergency_chat` flow (customer) + admin emergency lane | end-to-end on device |
| 2.3.8 | Admin UI: chips/filters/assign/escalate/close | page tests |
| 2.3.9 | Customer UI: emergency button + status banner | page tests |
| 2.3.10 | Tests + security pass (ACL, priority lock, anon) | full suite + probes |
| 2.3.11 | Audit: docs/HANDOFF/33 gate + DECISION_LOG + ROADMAP + SESSION_STATUS; `flutter analyze/test`; commit+push | commit/push |

**Every step stops at its exit gate; 2.4 (notifications FCM + admin send path) does NOT start.**

---

## 15. Gates & Decision Points

- **This gate = APPROVAL of the architecture in this doc.** NO code/migration/commit has been produced.
- On approval: implement 2.3.1→2.3.11 with the per-step gates in §14, then a fresh gate before commit/push (AGENTS.md rule 7).
- **Open questions for the user:**
  1. Approve the routing order **region-scoped → global → owner** (with owner = sole live admin-tier today)?
  2. Approve the emergency set extension `('low','medium','high','urgent','emergency')` (ADR-052) on `chat_rooms.priority`?
  3. Confirm **no admin seeding** in 033 (owner remains the only admin-tier account, per 028 Q3)?

---

## 16. Deliverables this gate

- **This doc** (sections per §33: existing/reusable/missing/schema/security/routing/escalation/realtime/notification/emergency/UX/033-spec/test-strategy/risks/sub-phases/gates).
- `docs/DECISION_LOG.md`: **ADR-058** (Phase 2.3 support-chat priority/region/assignment model + emergency lane) — recorded separately on approval.
- `ROADMAP.md` + `SESSION_STATUS.md`: updated to mark 2.3 **DESIGNED** (pending approval).
- **NOT produced:** migration 033, product code, tests, commits. Live DB read-only this session.

## 17. Source of Truth

- Live evidence: Management API `bttnlkmwhorjamzemwda` queries this session (users=5 · 1 owner · 0 admin; notifications.type unconstrained; chat_rooms/chat_messages/notifications in `supabase_realtime`; `user_region_preferences` = user_id/region_id/source/updated_at; `admin_region_assignments` shape).
- Repo: `supabase/migrations/016,018,019,030,031,032` · docs 25/26/28 · `lib/features/support_chat/**` · `lib/core/auth/admin_access.dart` · `lib/services/push_notification/**` · `lib/features/regions/**`.
