# STEP 13 (Phase 2.5) — Escalation Engine

> **Date:** 2026-08-18 (Session 53) — ROADMAP row 2.5 (sprint 81) — **COMPLETE, COMMITTED + PUSHED**
> **Authority:** PROJECT_CONSTITUTION §15 · Phase 2 audit doc `25_SPRINT_76_PHASE2_ARCHITECTURE_AUDIT.md`
> **Contract:** `28_SPRINT_76_PHASE_2_2_ADMIN_HIERARCHY_AUDIT.md` §5 (2.5 row) + `32` §6
> **D-resolution:** D4 → 2.5 (escalation engine; priority server-side only)

> **Status:** ✅ Shipped — migration `048_escalation_engine.sql` applied live + probe-verified (incl. real
> PostgREST chain); Flutter `lib/features/escalation/` module wired + registered; targeted suites green;
> ADR-067 in `docs/DECISION_LOG.md`; ROADMAP row 2.5 updated. See **§8 (Result)**.

---

## 1. Objective

Build the **escalation engine** (Phase 2.5, roadmap row 2.5) whose contract is:

> `escalation_events` table + engine RPCs; wire complaints `escalated` status to real assignment
> (not just a string).

Must reuse existing architecture — no duplicate escalation, notification, audit, or admin systems.

## 2. Current-state audit (key facts verified this session)

- `escalation_events` **does NOT exist** (repo or live DB). Migration number `035` was reused for
  member-management, so the ROADMAP's planned `035_escalation_engine` never shipped. Next free
  migration = **`048`**.
- Live chat escalation (built in 033, mig `033_support_chat_priority_region_assignment.sql`):
  `chat_escalations` ledger + `escalate_support_chat(room_id, reason)` + `resolve_support_admin`
  (recursive region→global→owner walk) + `_assign_chat_to_admin` (notify pattern, idempotency key).
- `complaints` live schema: status CHECK incl `'escalated'` as a plain string; NO `assigned_admin_id`,
  `escalated_at`, or `escalated_from_admin_id`. No server-side escalation logic. Flutter currently
  writes `status='escalated'` through direct table UPDATE
  (`lib/features/complaints/data/datasources/remote/supabase_complaints_data_source.dart:40-48`).
- Authz primitives to reuse: `is_admin()`, `is_admin_for_region()`, `has_permission(...)`,
  `resolve_support_admin(p_region_id, p_prefer_region, p_exclude_admin_id)`,
  `_member_region_id(user_id)`, `write_audit(...)`, `is_supervisor_of(...)` (034 / migrations).
- Notification deep-link allowlist seeds (`041`) already include `/admin/complaints` (admin,owner) &
  `/my-complaints`; client mirror `notification_channels.dart`. No new deep-link needed.
- `member_events` CHECK vocabulary (035) already includes `support_escalated` / `complaint_escalated`
  (never surfaced to the member user — timeline whitelist excludes them).

## 3. Design

### 3.1 `escalation_events` table (general escalation ledger)

Matches the 2.5 contract slice (generalized entity ref, per 033 chat_escalations style):

| column | type / default | notes |
|--------|----------------|-------|
| `id` | `uuid PK gen_random_uuid()` | |
| `entity_type` | `text CHECK ('complaint','support_chat')` | future-typed ledger |
| `entity_id` | `uuid NOT NULL` | complaints.id / chat_rooms.id |
| `from_admin_id` | `uuid REFERENCES users(id)` | current assignee being escalated away from |
| `to_admin_id` | `uuid REFERENCES users(id)` | target (NULL = owner queue) |
| `actor_id` | `uuid NOT NULL REFERENCES users(id)` | who triggered |
| `reason` | `text NOT NULL` | required reason |
| `previous_scope` | `text` | unassigned/scoped/global/owner (mirrors 033) |
| `new_scope` | `text` | target scope |
| `created_at` | `timestamptz DEFAULT now()` | |

RLS/ACL (016 pattern): admins select all; actors/participants may select their own events; no direct
insert by clients (SECURITY DEFINER RPCs only). Revoke-before-grant; ANON nothing.

### 3.2 Complaints `escalated` — real assignment

Add to `complaints` (additive, mirrors `chat_rooms` 033):
- `assigned_admin_id uuid REFERENCES users(id)`
- `escalated_at timestamptz`
- `escalated_from_admin_id uuid REFERENCES users(id)`

**Guard trigger** (`complaints_fixup_insert/update`, mirroring `chat_rooms_fixup_*`): non-admin direct
writes are neutralized (status/priority/assignment forced to safe defaults); SECURITY DEFINER RPC
context trusted. This closes the "UI-only escalated string" gap.

### 3.3 Engine RPCs (016 pattern, `SET search_path`)

1. `escalate_complaint(p_complaint_id uuid, p_reason text) RETURNS void`
   - SECURITY DEFINER; `is_admin()` + region scope (`has_permission` / `is_admin_for_region` reuse);
     reason required.
   - Load complaint FOR UPDATE; must exist, not already resolved.
   - Compute target via `resolve_support_admin(region, true, exclude=current assignee)`; if the caller
     is global/owner (cannot escalate above itself) → owner queue (`to_admin_id = NULL`,
     `status='escalated'`, `assigned_admin_id = NULL`).
   - Writes `escalation_events`, sets assignment columns, writes `member_events
     complaint_escalated`, `write_audit`, and inserts a **notification** to the new assignee
     (deep_link `/admin/complaints`) with idempotency key (033 `_assign_chat_to_admin` pattern).
2. `assign_complaint(p_complaint_id uuid, p_admin_id uuid) RETURNS void`
   - SECURITY DEFINER; `is_admin()`; validates target admin is real + in scope/supervised
     (`is_admin()` on target, `is_supervisor_of` not required when assigning region-scoped? → validate
     via `has_permission('ADMIN_ASSIGN', region)`); writes `escalation_events` (assignment path) +
     sets `assigned_admin_id`; notifies assignee; audits.
   - Reuses permission matrix; never lets a client pick the assignee without admin rights.
3. `get_escalation_events(p_entity_type text, p_entity_id uuid) RETURNS jsonb` — engine list RPC for
   the events UI (or rely on RLS select). DECIDE: use a list RPC to avoid a duplicate table path,
   matching `get_member_timeline` style.

### 3.4 Routing (server-side only, contract §5)

- scoped admin → parent region admin → nearest ancestor admin → global admin → owner.
- global cannot escalate above itself.
- priority/status never decrease server-side (guard trigger + RPC-only writes).

## 4. Flutter (existing arch; new `lib/features/escalation/`)

- `domain/entities/escalation_event.dart` (plain model mirroring complaint.dart style)
- `domain/repositories/escalation_repository.dart`
- `data/datasources/remote/supabase_escalation_data_source.dart` (rpc escalate/assign/list)
- `data/repositories/escalation_repository_impl.dart`
- `presentation/escalation_providers.dart`
- `presentation/pages/admin_escalations_page.dart` (events queue + list; reuse admin page chrome)
- `escalation_module.dart` → register in `lib/module_registry.dart`
- **Complaints wiring:** `SupabaseComplaintsDataSource.updateComplaintStatus` stops writing
  `'escalated'` via direct UPDATE → routes to `escalate_complaint` RPC; admin complaints page gets an
  **Escalate** action (with required reason prompt) replacing the free-string status dropdown for
  `escalated`; show `assigned_admin_id` / `escalated_at` in the card.
- l10n: `escalationEscalate`, `escalationReason`, `escalationQueueTitle`, `escalationAssignedTo`,
  `escalationPending`, `escalationRequired`, `escalationFailed`, etc. (en + ar).
- No new deep-link source; notification goes to `/admin/complaints` (already allowlisted).

## 5. Migration `048_escalation_engine.sql` — step list

1. `escalation_events` table + index (`entity_type,entity_id`) + RLS policies + revokes/grants.
2. `complaints` ALTER: `assigned_admin_id`, `escalated_at`, `escalated_from_admin_id`.
3. `complaints_fixup_insert/update` guard triggers (mirror 033 chat_rooms_fixup, incl. trust
   SECURITY DEFINER context).
4. `escalate_complaint` + `assign_complaint` + `get_escalation_events` SECURITY DEFINER RPCs
   (016 pattern, search_path pinned), revoke-then-grant authenticated/service_role.
5. Idempotent (IF NOT EXISTS / DROP IF EXISTS); rerunnable.

## 6. Verification plan

- **Migration applied live** via Management API; rerun → clean.
- **Schema/RPC probes:** columns exist; RPC signatures; EXECUTE grants; anon denied.
- **RLS/role probes (SET ROLE + request.jwt.claims):**
  - ANON deny on escalation_events read & RPCs.
  - CUSTOMER deny on escalate/assign RPCs.
  - ADMIN/OWNER allow; region-scope matrix (scoped admin only within region/descendants).
  - complaint `status='escalated'` via direct UPDATE blocked for non-admin + allowed path via RPC.
- **End-to-end fixture:** create temp complaint (cleanup after) → escalate → verify
  escalation_events row + assigned_admin_id + notification + member_events + audit row → tidy up.
- **Flutter:** `flutter pub get`, `flutter analyze` (touched files 0 issues), targeted tests
  (`flutter test --no-pub --concurrency=2` on escalation + complaints suites).

## 7. Next
- Write + apply migration 048, verify live, then Flutter module + wiring + tests + docs
  (ADR-067 escalation engine; ROADMAP 2.5 ✅; SESSION_STATUS; handoff report; commit/push),
  then NIGHTLY report.

## 8. Result (Session 53, 2026-08-18)

**Backend — migration `048_escalation_engine.sql` applied live (idempotent, rerun-clean):**
1. `escalation_events` ledger + `(entity_type, entity_id)` index + RLS + revokes/grants
   (anon/authenticated cannot read; service_role + SELECT for admins via RLS).
2. `complaints` ALTER: `assigned_admin_id`, `escalated_at`, `escalated_from_admin_id`.
3. `escalate_complaint` / `assign_complaint` / `get_escalation_events` SECURITY DEFINER RPCs
   (016 pattern, pinned `search_path`, revoke-then-grant). Escalate routes **strictly upward**:
   unassigned → best regional (`resolve_support_admin(v_region, true, NULL)`), scoped → global tier
   (`resolve_support_admin(v_region, false, v_current)`), global → **owner queue** (terminal, `to_admin_id=NULL`);
   early RETURN once an owner-queue event exists.
4. **Marker-based server-origin guards**: `escalate_complaint`/`assign_complaint` set
   `set_config('app.escalation_rpc','true',true)`; `_enqueue_push`/`dispatch_push` set `app.notify_dispatch`.
   `complaints_fixup_insert`/`complaints_fixup_update` + `guard_notifications_user_update` trust
   marker → `auth.uid() IS NULL` → `is_admin()`; else force safe defaults (insert) / restore OLD values
   (update); admin direct `status→'escalated'` or assignment-field edits RAISE.
   The `current_user IS DISTINCT FROM session_user` discriminator was removed (unusable under PostgREST:
   `session_user` is always `authenticator`).

**Live verification highlights:**
- Multi-hop probe: routed `unassigned→scoped(R1)→global(G)→owner queue(NULL)`; extra escalate after
  owner queue appends no new ledger row (early return). Fixed prior R1↔G downgrade cycle.
- Forged customer insert (`status='escalated'`, `priority='urgent'`, `assigned_admin_id`) previously HTTP 201
  forged; after fix HTTP 201 with **neutralized** values (`pending`/`medium`/NULL).
- Real PostgREST chain: customer file complaint → neutralized → admin `escalate_complaint` (204) →
  `get_escalation_events` shows `unassigned→scoped` to real admin → complaint state `escalated` with
  assignee → 1 notification row → cleanup.
- Probe suite T1–T4 green (owner/chain, anon deny + customer deny + out-of-scope error, guard matrix,
  owner-queue terminal). Probes isolate the push trigger with
  `ALTER TABLE ... DISABLE TRIGGER notify_notification_push` + `GRANT ALL ON pg_temp` for SET ROLE.

**Flutter (`sprint 81`):**
- New `lib/features/escalation/` module (entity/repo/data source/impl/providers/page/module) registered in
  `lib/module_registry.dart`; `/admin/escalations` route nested under admin module.
- `Complaint` extended with assignment/escalation fields + `isClosed`; `updateComplaintStatus('escalated')`
  raises (`ServerException` must use RPC); `escalateComplaint(id, reason)` wired to `escalate_complaint`.
- Admin complaints page: **Escalate** action with required-reason prompt; dropdown excludes `escalated`.
- l10n EN/AR: 14 escalation keys.

**Verification:** `dart analyze` (touched files) 0 errors/warnings; `escalation_rpc_wiring_test` 8/8 +
`complaint_entity_test` 3/3; live ledger proof + REST chain green. Commit+pushed as `sprint 81`.