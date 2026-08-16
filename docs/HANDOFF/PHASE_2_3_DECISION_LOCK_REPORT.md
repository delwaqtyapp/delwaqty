# PHASE 2.3 — OWNER DECISION & ARCHITECTURE LOCK REPORT

**Project:** Delwaqty (no other project name).
**Gate:** Architecture lock review ONLY — **no product code, no migration 033+, no commit, no push, no Phase 2.4/2.5.**
**HEAD:** `b1081d28b317223ff61f381e9ce1809c8c912ead` (master; this session produced docs only).
**Source of truth:** `docs/HANDOFF/PHASE_2_3_MEMBER_MANAGEMENT_SUPPORT_ARCHITECTURE_AUDIT.md` (master audit, §32 extracted below) · doc 32 (support-chat sub-audit, superseded) · ADR-055/056/057/058 · live schema verified read-only this session.
**Evidence re-verified this session (live, Management API):** baseline unchanged — 5 users (3 customer · 1 provider · 1 owner `8a23b719-…` · 0 admin); `users.email` **UNIQUE** (constraint confirmed — matters for anonymization); Flutter only **reads** `activity_logs` (`admin_repository.dart:525 getRecentActivity`) → service_role-only INSERT is safe; `sos_alerts` has no admin SELECT policy; `driver_locations` SELECT = `auth.role()='authenticated'` (wide); `activity_logs` INSERT = `TO public` (anon). No migration 033 in repo.

---

## 1. The 10 Owner Decisions from §32 (extracted verbatim)

1. **D1** — Approve the supervision + region-scope dual model (`admin_management` tree for management/approvals; `admin_region_assignments` for visibility/routing). Owner = implicit root, no row.
2. **D2** — Approve permission model: computed defaults + `admin_permission_grants` (no RBAC engine), final penalty/approval mapping left config-driven.
3. **D3** — Approve `users` additions: `date_of_birth` + `account_status` (guarded, server-only writes).
4. **D4** — Approve soft-delete + anonymize for account deletion (audit preserved, no hard destroy).
5. **D5** — Approve emergency audio foundation-only in 2.3 (sessions + permissions + audit + customer-visible state; **no transport choice, no recording**); WebRTC/Twilio decision deferred to a dedicated audio review.
6. **D6** — Approve `member_events` as a separate customer-readable timeline (vs reusing admin-only `activity_logs`).
7. **D7** — Approve new tables `regional_offers`+`offer_reviews` (distinct from merchant `offers`), `approval_requests` (generic Approval Center), `member_rewards`, `chat_escalations`, `emergency_audio_sessions`.
8. **D8** — Approve RLS fixes in 033: `activity_logs` INSERT→service_role, `driver_locations` read→participant+admin, `sos_alerts` admin SELECT.
9. **D9** — Approve routing order region-scoped → parent-region → global → owner (deterministic; live = owner fallback).
10. **D10** — Confirm no admin seeding — owner `8a23b719-…` remains the only admin-tier account.

---

## 2. Status of Each Decision

Format: **Decision ID / Existing proposal / Why / Impact / Risks / Recommendation / Final status.**

### D1 — Dual admin model (supervision tree + region scope)
- **Why:** Ownership/approvals need a per-admin chain (no fixed levels); routing/visibility need region scope. One axis alone cannot express "who manages whom" vs "which members an admin may see". Mandated by directive §3 (supervision tree + region scope per ADR-055/056).
- **Impact:**
  - *DB:* new `admin_management` (admin_id PK, supervisor_id, is_active, created_by, created_at, updated_at; CHECK admin_id<>supervisor_id). `admin_region_assignments` unchanged.
  - *RLS:* admin_management ALL `TO public` USING `is_admin()`; supervisor/scope enforcement inside RPCs.
  - *RPCs:* create/assign/role/region/supervisor/deactivate admin — all validate `is_descendant_of(actor,target)` recursive CTE + region containment.
  - *Flutter:* admin branch-management pages under existing `/admin` shell + `admin_web` gate; UI reflects only.
  - *Admin hierarchy:* depth derived from the tree (recursive), never stored.
  - *Member management/emergency:* supervisors see subordinates' scope; emergency oversight owner/higher.
  - *Future apps:* Provider/Driver admins plug into the same tree (no new authz system).
- **Risks:** supervision cycles (mit: RPC-level recursive CTE rejection + CHECK); supervisor granting regions outside own scope (mit: containment invariant); orphaned admins on owner deactivation (owner cannot be deactivated — owner row is root).
- **Recommendation:** APPROVED WITH MODIFICATION — add explicit invariants in 034: (a) no cycles, (b) subordinate region assignments must be contained in the supervisor's own reachable scope, (c) only owner creates admin at root level, (d) supervisor must hold every permission they grant.
- **Final status:** 🟢 APPROVED WITH MODIFICATION (modifications M1–M2 confirmed in this directive's §3; owner to ratify at implementation gate).

### D2 — Permission model (computed defaults + grants)
- **Why:** The directive requires capability-based, server-enforced authorization with permission codes, but forbids unnecessary RBAC machinery ("smallest clean model"). Defaults from (role, admin, scope) + small grants table for deviations.
- **Impact:**
  - *DB:* `admin_permission_grants(admin_id, permission, granted_by, granted_at)` PK(admin_id, permission).
  - *RLS/RPCs:* single `has_permission(permission, region, target_admin)` SECURITY DEFINER used by every sensitive RPC + policy.
  - *Flutter:* admin pages fetch permission set; hide/disable but never rely on UI.
  - *Hierarchy/member/emergency/future:* one evaluator across all surfaces.
- **Risks:** default-matrix drift (mit: matrix defined once in `has_permission` + documented); grants never revoked (mit: DELETE = revoke, audited); grantor escaping authority (mit: grantor-possession check).
- **Recommendation:** APPROVED WITH MODIFICATION — (a) define the default matrix explicitly in the 034 migration (documented CASE), (b) enforce "grantor must possess the permission or be owner", (c) no self-grant, (d) EMERGENCY_AUDIO and MEMBER_DELETE only grantable (never default).
- **Final status:** 🟢 APPROVED WITH MODIFICATION.

### D3 — `users` additions (date_of_birth + account_status)
- **Why:** Birthday engine needs official DOB; moderation needs an enforceable status (sanctions is the ledger, not enforcement). Mandated by directive §4 (member profile fields incl. date of birth, account status).
- **Impact:**
  - *DB:* `ALTER TABLE users ADD COLUMN date_of_birth date; ADD COLUMN account_status text NOT NULL DEFAULT 'active' CHECK (IN ('active','restricted','suspended','banned','deactivated'));`
  - *RLS/triggers:* BEFORE UPDATE guard restores role/account_status/DOB to OLD for non-RPC writers; only SECURITY DEFINER RPCs change them.
  - *RPCs:* `issue_sanction`/`revoke_sanction`/`delete_member_account` are the only writers.
  - *Flutter:* member profile displays status/DOB per MEMBER_VIEW.
  - *Future:* Phase 2.5 profiles build on these primitives.
- **Risks:** PII exposure (DOB sensitive → gated in `get_member_profile`); status drift vs sanctions (mit: status derived from sanction mapping on write + engine reconciles).
- **Recommendation:** APPROVED — additive, guarded. (Add `users.anonymized_at` in the same migration for D4.)
- **Final status:** 🟢 APPROVED.

### D4 — Soft-delete + anonymize
- **Why:** Directive §4: audit, complaints, support, sanctions, financial records, legal evidence must survive account deletion. No hard destroy.
- **Impact:**
  - *DB:* `account_status='deactivated'`, `anonymized_at`, PII → null/hash, `email → deleted-<uuid>@anonymized.invalid` (users.email UNIQUE confirmed live — scheme respects it).
  - *RLS:* no DELETE policy on `users` (none exists today — kept); deletion only via RPC.
  - *RPCs:* `delete_member_account(member_id, confirmation_token, reason)` — MEMBER_DELETE + approval + deliberate confirmation; audit `MEMBER_DELETED`.
  - *Flutter:* member-management delete flow with confirmation dialog.
  - *Future:* re-registration produces a new identity (Phase 2.5 concern, noted).
- **Risks:** orphaned FKs (mit: FKs are RESTRICT/keep-uuid, references survive by design); re-activation by mistake (mit: deactivated is terminal for the identity; separate restore path gated owner-only if ever needed).
- **Recommendation:** APPROVED (directive-mandated). Reference-id preservation is by design.
- **Final status:** 🟢 APPROVED.

### D5 — Emergency audio foundation-only
- **Why:** Directive §5 explicitly: foundation only — session identity, lifecycle, initiator/listener, timestamps, status, audit, customer-visible state. **No** recording, storage, surveillance, provider, WebRTC.
- **Impact:**
  - *DB:* `emergency_audio_sessions` (no media columns — metadata/state only).
  - *RLS/RPCs:* `start/end_emergency_audio` require EMERGENCY_AUDIO + active emergency room + participant; status broadcast via realtime (chat_rooms already published).
  - *Flutter:* customer-visible "audio active" indicator; admin start/end controls.
  - *Future:* transport decision (WebRTC/Twilio) is a dedicated later review; 2.3 state model is transport-agnostic.
- **Risks:** scope creep into recording (mit: no storage/media fields at all); unauthorized access (mit: EMERGENCY_AUDIO explicit grant + active-session validation).
- **Recommendation:** APPROVED — as-is, foundation only.
- **Final status:** 🟢 APPROVED.

### D6 — `member_events` as separate timeline
- **Why:** Directive §10 — unified operational timeline for authorized admins AND customer-readable subset. `activity_logs` is admin-only + security-shaped; customers cannot and should not see it.
- **Impact:**
  - *DB:* `member_events` (references/metadata only — no content duplication per directive §10).
  - *RLS:* user reads own safe event_type whitelist; admin reads via MEMBER_VIEW_TIMELINE + scope.
  - *RPCs:* domain RPCs write events atomically; `get_member_timeline(member_id, cursor)` paginated.
  - *Flutter:* timeline page (admin member profile + customer profile).
  - *Future:* profile/registration events in Phase 2.5 append here.
- **Risks:** event bloat (mit: whitelisted types + pagination); duplicating subsystem content (mit: store event_type + related_entity_id + metadata only).
- **Recommendation:** APPROVED.
- **Final status:** 🟢 APPROVED.

### D7 — New tables set
- **Why:** Each was justified in the audit against reuse (merchant `offers` is commerce-shaped; no generic approval exists; rewards need idempotency; escalation needs a ledger; audio needs a session record). Endorsed by directive §6 (`chat_escalations`) and §9 (`member_rewards`, `regional_offers`, `offer_reviews`, `approval_requests`).
- **Impact:** see §16 migration map for the exact DDL scope per table.
- **Risks:** table proliferation (mit: 8 tables total across 6 migrations, each with a documented non-reuse reason); generic `approval_requests` over-abstraction (mit: partial unique pending index + typed request_type constants).
- **Recommendation:** APPROVED.
- **Final status:** 🟢 APPROVED.

### D8 — RLS fixes in 033 (three live findings)
- **Why:** Directive §11 mandates classification + secure fix or documented deferral. Findings are live security defects, not hypotheticals.
- **Impact:**
  - *activity_logs:* INSERT `TO public` → `TO service_role` (+ internal `write_audit` SECURITY DEFINER helper). Verified safe: Flutter only SELECTs (`admin_repository.dart:525`); 0 rows live.
  - *driver_locations:* SELECT `auth.role()='authenticated'` → ride-participant (`ride_id` match) OR driver-owner OR `is_admin()`. Preserves legitimate live-share while closing the wide read.
  - *sos_alerts:* add admin SELECT `USING (is_admin())` (realtime already publishes the table → command center feed works immediately).
- **Risks:** breaking live-share (mit: participant clause preserved); admin overscope on SOS (mit: EMERGENCY_VIEW permission at RPC/UI; region-scoped refinement can come later).
- **Recommendation:** APPROVED — include all three in 033 (they are the security-critical batch and cheapest to verify together). This matches the audit's D8 wording.
- **Final status:** 🟢 APPROVED (classification: security fix, owner = platform, migration 033, risk without fix = audit-poisoning/privacy leak, follow-up gate = 2.3A live attack matrix).

### D9 — Routing order
- **Why:** Directive §6 mandates: region-scoped → parent region → global → owner; continue upward when a level is empty; deterministic; emergency uses the priority lane.
- **Impact:** DB RPC `resolve_support_admin`/`route_support_chat` (recursive ancestor walk over `regions.parent_region_id`); deterministic tiebreak (fewest open rooms → lowest admin_id); live baseline = owner fallback (0 admins).
- **Risks:** ties (mit: deterministic tiebreak); region-less customers (mit: preference backfill on insert; else global/owner).
- **Recommendation:** APPROVED.
- **Final status:** 🟢 APPROVED.

### D10 — No admin seeding
- **Why:** Directive §1.2/baseline: production state must remain valid with owner + zero admins. Never seed fake accounts.
- **Impact:** migrations create no admin rows; `admin_region_assignments` stays 0; owner is the only admin-tier live (verified).
- **Risks:** none.
- **Recommendation:** APPROVED.
- **Final status:** 🟢 APPROVED.

**Decision summary table:**

| # | Decision | Status |
|---|----------|--------|
| D1 | Supervision + region-scope dual model | 🟢 APPROVED WITH MODIFICATION |
| D2 | Computed defaults + permission grants | 🟢 APPROVED WITH MODIFICATION |
| D3 | users.date_of_birth + account_status | 🟢 APPROVED |
| D4 | Soft-delete + anonymize | 🟢 APPROVED |
| D5 | Audio foundation-only | 🟢 APPROVED |
| D6 | member_events timeline | 🟢 APPROVED |
| D7 | New tables set | 🟢 APPROVED |
| D8 | RLS fixes in 033 | 🟢 APPROVED |
| D9 | Routing order | 🟢 APPROVED |
| D10 | No admin seeding | 🟢 APPROVED |

---

## 3. Contradictions

| # | Item | Resolution |
|---|------|-----------|
| C1 | `is_admin_for_region()` (031, single-level descendant) vs recursive routing walk (033). | **Not a contradiction** — different purposes (boolean "am I scoped here" vs "find best admin up the chain"). Document in 033; keep `is_admin_for_region` for compatibility; `has_permission()` becomes the single evaluator going forward. Flag as drift-risk. |
| C2 | "No fixed admin levels" (ADR-055) vs supervision depth. | Consistent — depth is derived recursively, never stored as a rank. |
| C3 | `activity_logs` service_role-only INSERT vs Flutter `getRecentActivity` read. | Consistent — Flutter reads only; verified no client INSERT. |
| C4 | `offers` (merchant) vs `regional_offers`. | Distinct objects; no reuse possible without contamination. Resolved in D7. |
| C5 | SOS admin SELECT = global `is_admin()` vs region-scoped principle. | Accepted for 033 (emergency oversight is intentionally wide at admin tier); EMERGENCY_VIEW gates data at RPC/UI; region-scoped SOS = documented refinement. |
| C6 | `run_member_engines` needs a scheduler; no pg_cron today. | Documented: edge-function timer (Phase 2.4 infra) + app-open best-effort; engine itself is idempotent. |

---

## 4. Missing Decisions (must be resolved before implementation)

| # | Missing decision | Where it bites | Proposed default |
|---|------------------|----------------|------------------|
| M1 | **Retention defaults** (audit §25) — not in §32 | Privacy directive §14; purge engine (038) | Configurable `retention_policies`; defaults: location 90d, member_events 5y, audit 7y, sanctions 7y, chat 2y, audio metadata 2y, notifications 1y |
| M2 | **Offer approval depth** (which supervision levels approve) | 037 workflow | Config-driven `offer_approval_chain` (region→supervisor→owner); owner final; no silent approval |
| M3 | **Sanction→approval mapping defaults** (which penalties require Approval Center) | 035 | Config-driven defaults: warning/restrict no approval; suspension by supervisor; ban + permanent_ban require approval; delete always approval |
| M4 | **Birthday/anniversary benefit content** (incl. free-delivery option, directive §9) | 038 | Content = campaign config in `platform_settings` (never hardcoded); free-delivery benefit only if business approves; idempotency guaranteed |
| M5 | **Deletion confirmation token format** | 035 | Server-generated confirmation string `"DELETE <email-hash>"`; recorded in audit |
| M6 | **Phase 2.5 account/profile primitive boundary** | 035/038 | 2.3 adds only DOB/account_status/member_events; no profile tables yet (keeps 2.5 clean) |

---

## 5. Recommended Modifications (to ratify)

1. **M-D1** — `admin_management` invariants (no cycles; region containment; root creation owner-only; grantor-possession).
2. **M-D2** — default permission matrix written explicitly in 034 migration (documented CASE) + EMERGENCY_AUDIO/MEMBER_DELETE grant-only.
3. **M-D3** — add `users.anonymized_at` alongside D3 columns (needed by D4).
4. **M-D6** — `member_events` stores references/metadata only + customer-safe event_type whitelist (already the audit's intent; now explicit).
5. **M-D7** — `approval_requests` partial unique index on (request_type, entity_id) WHERE state='pending'; reason required on every approve/reject.
6. **M-D8** — fix all three findings together in 033 (cheapest single verification gate).

---

## 6. Final Architecture Diagram

```
                        ┌──────────────────────────────────────────────┐
                        │        AUTHORIZATION (single evaluator)       │
                        │   has_permission(permission, region, target)  │
                        │     identity + role + supervisor + grants +   │
                        │     scope + target + action   (server-only)   │
                        └──────────────────────────────────────────────┘
                                        ▲ enforces
   ┌───────────────┬───────────────┬───────────────┬───────────────┐
   │ Customer App  │ Provider App  │ Driver App    │ Admin Platform │
   └───────────────┴───────────────┴───────────────┴───────┬───────┘
              │                    (all four over ONE backend)      │
              └────────── Supabase (realtime: chat, notif, sos, ────┘
                                 sanctions, location)
    ┌──────────────────────────────────────────────────────────────────┐
    │ CORE (existing, reused):  users · chat_rooms/messages ·           │
    │ complaints · sanctions · sos_alerts · notifications ·             │
    │ regions + geo (032) · admin_region_assignments · activity_logs ·  │
    │ driver_locations / location_updates · driver_documents            │
    └───────────────┬──────────────────────────────────────────────────┘
                    │ ADDITIONS (033→038, additive only)
    ┌───────────────▼──────────────────────────────────────────────────┐
    │ hierarchy: admin_management (supervision) + admin_permission_grants│
    │ support:   chat_rooms+priority/region/assign + chat_escalations    │
    │ member:    users(+dob,+account_status,+anonymized_at) + member_events│
    │ emergency: emergency_audio_sessions (foundation)                   │
    │ rewards:   member_rewards · regional_offers + offer_reviews        │
    │ approvals: approval_requests (Approval Center)                     │
    └──────────────────────────────────────────────────────────────────┘
```

---

## 7. Permission Model

- Single source: `has_permission(p_permission, p_region_id, p_target_admin_id)` (SECURITY DEFINER).
- Defaults computed from (role, admin, region scope) — documented matrix in 034 (§6 of master audit): owner = all; admin = in-scope defaults (MEMBER_VIEW*, EMERGENCY_VIEW, MEMBER_MODERATE/WARN/RESTRICT, OFFER_CREATE, ADMIN_* on subordinates); grant-only: MEMBER_VIEW_DOCUMENTS, MEMBER_BAN, MEMBER_DELETE, EMERGENCY_AUDIO, OFFER_APPROVE.
- `admin_permission_grants` stores only grants/deviations; grant requires grantor-possession; revoke = row delete (audited).
- Config-driven penalty/approval mapping (no hardcoded final mapping).
- Flutter: permission-set fetch for UX only; PostgreSQL is the authority (never trust UI).

## 8. Admin Hierarchy Model

- **Supervision tree** (`admin_management`): owner = root (no row); each admin has one supervisor; depth derived recursively (no fixed levels); supports "Higher Admin — Giza → City Admin → District → Village" and "Global Admin" (no region rows = global scope) at any depth.
- **Rules (server-enforced):** subordinates-only management; no self/upward modification; no owner creation except owner; region containment for assignments; no scope escape; deactivation cascades down (subordinates orphan→re-assigned by superior).

## 9. Region-Scope Model

- `admin_region_assignments` (self/descendants) + no-rows=global + owner implicit global.
- Recursive ancestor walk for routing (up `regions.parent_region_id`).
- Visibility = MEMBER_* within reachable scope; cross-region denied server-side.
- Canonical Egypt hierarchy (030/032) untouched: governorates, centers, cities, villages, new cities, geo_places, boundaries, GPS resolution.

## 10. Member-Management Model

- `get_member_profile(member_id)` aggregate RPC, permission-sectioned (basic/location/docs/support/moderation/emergency/rewards) — no raw-table exposure.
- `explain_admin_access()` = "why can I see this?" (admin debug only; never customer-facing).
- Deletion = member management (not moderation): soft-delete + anonymize + confirmation + approval + audit; historical records survive.

## 11. Emergency Model

- `sos_alerts` (ride-safety, realtime) + `chat_rooms.priority='emergency'` lane (ADR-052) + `emergency_audio_sessions` (foundation).
- Command center: realtime feed (SOS + emergency chat + audio status), GPS snapshot → canonical region → routing.
- Audio: EMERGENCY_AUDIO grant + active-emergency validation + customer-visible state + full audit; **no recording/transport in 2.3**.

## 12. Support Routing Model

`region-scoped → parent region (ancestor walk) → global → owner`, deterministic tiebreak (fewest open rooms → lowest admin_id), server-only, priority server-locked, live = owner fallback. Escalation re-routes up the same chain excluding current assignee, same conversation, `chat_escalations` ledger.

## 13. Sanctions Model

- Ledger = `sanctions` (additive: `approving_admin_id`, `evidence_url`, `action_status`).
- Enforcement = `users.account_status` (single-writer RPCs).
- Mapping sanction-type → resulting status + duration = config-driven; expiry reconciled by engine.
- Every action: actor, target, reason, timestamp, type, duration, previous/resulting status, audit.

## 14. Rewards/Offers Model

- `member_rewards` idempotent (UNIQUE user+type+period_key) for birthday/anniversary; benefit content config-driven (no hardcoded rewards; free-delivery only if business approves).
- `regional_offers` + `offer_reviews`: propose → hierarchy approval → owner final → publish; every transition recorded with reason; no silent approval; expiry handled by engine.

## 15. Approval Model

- Generic `approval_requests` (Approval Center) for admin lifecycle, bans, deletes, offer approval/publish; pending-unique partial index; decide = approve/reject with mandatory reason; notifications to requester; audited end-to-end with correlation_id.

---

## 16. Migration 033–038 Map

> All additive/non-destructive. **Never DROP TABLE/COLUMN, TRUNCATE, DELETE-all.** If a migration would require table recreation, STOP and request approval. Idempotency: `IF NOT EXISTS`/`ADD COLUMN IF NOT EXISTS`/`CREATE OR REPLACE`/`DO UPDATE`; revoke-before-grant on every new function/table (030 lesson); anon EXECUTE revoked; `SET search_path=public,pg_temp` on all SECURITY DEFINER.

### 033 — Support chat priority/region/assignment + RLS security fixes
- **Purpose:** Phase 2.3 core support/emergency lane + the three live security fixes (D8).
- **Tables:** `chat_rooms` (extend), `chat_escalations` (new).
- **Columns (chat_rooms):** `priority text NOT NULL DEFAULT 'low' CHECK('low','medium','high','urgent','emergency')` · `region_id uuid FK regions` · `assigned_admin_id uuid FK users` · `assigned_at timestamptz` · `status text NOT NULL DEFAULT 'open' CHECK('open','assigned','escalated','closed')` · `escalated_at timestamptz` · `escalated_from_admin_id uuid FK users` · `closed_at timestamptz`. **chat_escalations:** `id, room_id FK chat_rooms, previous_admin_id, new_admin_id, actor_id, reason, previous_scope, new_scope, created_at`.
- **Indexes:** `chat_rooms(status)`, `(assigned_admin_id)`, `(region_id)`, `(priority)`, partial `(assigned_admin_id) WHERE status IN ('open','assigned')`; `chat_escalations(room_id, created_at)`.
- **RLS:** `chat_escalations` admin SELECT/INSERT + participant SELECT (room membership) — 016 pattern; **fixes:** `activity_logs` INSERT → `service_role`; `driver_locations` SELECT → participant/driver-owner/admin; `sos_alerts` + admin SELECT.
- **RPCs:** `resolve_support_admin` (helper) · `route_support_chat` · `assign_support_chat` · `escalate_support_chat` · `open_emergency_chat` · `close_support_chat` · `write_audit` (internal, service_role).
- **Triggers:** `chat_rooms_fixup_insert` / `chat_rooms_fixup_update` (SECURITY DEFINER guard: non-admins can't set priority/status/assignee; region backfill from `user_region_preferences`).
- **Security:** guard triggers + server-only routing + anon-revoked EXECUTE + RLS fixes above.
- **Dependencies:** 016/018/030/031/032 (all live). **Rollback:** reverse column drops only with owner approval; safe rollback = leave additive columns (forward-only; documented).
- **Idempotency:** IF NOT EXISTS + OR REPLACE. **Live verification:** schema + ACL + routing matrix + priority-lock probes + the 3 RLS fixes.
- **Security tests:** anon/customer/scoped/global/owner attack matrix on priority lock + routing + audit fix. **Flutter gate:** admin queue chips/filters/assign/escalate; customer emergency button.

### 034 — Admin delegation + permissions + approvals
- **Purpose:** supervision tree, permission grants, Approval Center, centralized authz.
- **Tables:** `admin_management`, `admin_permission_grants`, `approval_requests`.
- **Columns:** as defined in §2/D1/D2/D7. **Indexes:** `admin_management(supervisor_id)`; `admin_permission_grants(admin_id)`; `approval_requests(state, required_approver)`, partial unique `(request_type, entity_id) WHERE state='pending'`.
- **RLS:** all three ALL `TO public` USING/WITH CHECK `is_admin()`; anon revoked.
- **RPCs:** `has_permission` · `explain_admin_access` · `create_admin_account` · `assign_admin_role` · `assign_admin_region` · `change_admin_supervisor` · `deactivate_admin` · `submit_approval_request` · `decide_approval_request`.
- **Triggers:** none (invariants in RPCs). **Security:** capability-based, supervisor/containment checks, grantor-possession, no self-grant.
- **Dependencies:** 033. **Rollback/idempotency:** additive + IF NOT EXISTS. **Live verification:** hierarchy attack matrix (§13 of this doc).
- **Flutter gate:** admin branch management + Approval Center pages.

### 035 — Member management, timeline, moderation, deletion
- **Purpose:** member profile primitives, timeline, sanction extension + enforcement, deletion.
- **Tables:** `users` (extend), `member_events` (new), `sanctions` (extend).
- **Columns:** `users: date_of_birth date, account_status text DEFAULT 'active' CHECK(...), anonymized_at timestamptz`; `member_events` (per §10/§15 audit); `sanctions: approving_admin_id uuid FK users, evidence_url text, action_status text CHECK('active','expired','revoked','completed') DEFAULT 'active'`.
- **Indexes:** `member_events(user_id, created_at DESC)`; `sanctions(target_user_id, created_at)`; `users(account_status)`.
- **RLS:** `member_events` user-own-safe-types SELECT + admin SELECT (permission+scope); `users` guard trigger; `sanctions` unchanged + additive cols.
- **RPCs:** `get_member_profile` · `get_member_timeline` · `issue_sanction` · `revoke_sanction` · `delete_member_account` · `get_member_status`.
- **Triggers:** `users_guard_account_fields` (BEFORE UPDATE/INSERT: role/account_status/DOB/anonymized_at only via RPC).
- **Security:** least-privilege member sections; deletion audit + confirmation; no hard delete.
- **Dependencies:** 034 (permissions), 033. **Live verification:** member-visibility matrix + deletion/anonymization probes.
- **Flutter gate:** member profile page (permission-sectioned), timeline page, moderation UI, deletion flow.

### 036 — Emergency Command Center + audio foundation
- **Purpose:** unified emergency workflow + audio session state.
- **Tables:** `emergency_audio_sessions` (metadata/state only — **no media columns**).
- **Columns:** `id, emergency_chat_id FK chat_rooms, customer_id FK users, admin_id FK users, region_id FK regions, status CHECK('requested','active','ended','cancelled'), started_at, ended_at, reason, created_by, created_at`.
- **Indexes:** `(emergency_chat_id)`, `(admin_id)`, `(status)`. **RLS:** admin (EMERGENCY_VIEW/EMERGENCY_AUDIO) + customer own (status only).
- **RPCs:** `start_emergency_audio` · `end_emergency_audio` · `resolve_emergency` · `get_emergency_command_center` (aggregate feed).
- **Triggers:** none. **Security:** active-emergency validation + grant + no recording/storage.
- **Dependencies:** 033 (emergency lane). **Live verification:** audio session lifecycle + customer-visible state + audit.
- **Flutter gate:** Command Center page + customer active-audio indicator.

### 037 — Regional offers + approval workflow
- **Purpose:** admin-proposed regional offers with hierarchical approval.
- **Tables:** `regional_offers`, `offer_reviews`.
- **Columns:** per §18 of the audit (region FK, title/description/benefit/eligibility, dates, limits/budget, proposed_by, reason, status CHECK('draft','submitted','under_review','approved','rejected','published','expired','cancelled'), published_at, timestamps; `offer_reviews`: offer_id, reviewer_id, action CHECK('submit','approve','reject','publish','cancel'), reason, previous_state, new_state, created_at).
- **Indexes:** `regional_offers(region_id, status)`, `(status, starts_at)`; `offer_reviews(offer_id, created_at)`.
- **RLS:** public SELECT only published+in-window; admin per OFFER_* permission.
- **RPCs:** `propose_regional_offer` · `submit_regional_offer` · `review_regional_offer(action, reason)` · `publish_regional_offer` (owner).
- **Security:** approval depth via supervision chain + `approval_requests` where configured; reason mandatory on approve/reject; no self-publish.
- **Dependencies:** 034 (permissions/approvals). **Live verification:** full workflow state machine + unauthorized-approval denial.
- **Flutter gate:** offer proposal + Approval Center offer items + published-offer display.

### 038 — Birthday/anniversary + retention engine
- **Purpose:** reward engines + configurable retention.
- **Tables:** `member_rewards`, `retention_policies` (config) or platform_settings keys.
- **Columns:** `member_rewards: user_id, reward_type CHECK('birthday','anniversary'), period_key, benefit, campaign_id, status, created_at, notified_at, UNIQUE(user_id, reward_type, period_key)`; `retention_policies: domain text PK, retention_days int, enabled bool`.
- **Indexes:** `member_rewards(user_id, period_key)`.
- **RLS:** user own + admin per permission.
- **RPCs:** `run_member_engines(run_date)` (birthday + anniversary + offer expiry + retention purge; idempotent) · `apply_retention_policies()`.
- **Triggers:** none. **Security:** duplicate prevention via unique constraint; content config-driven.
- **Dependencies:** 035 (DOB/account_status), 037 (offers). **Live verification:** idempotency double-run + correct-region/campaign tests.
- **Flutter gate:** reward notification display; no engine UI needed.

---

## 17. Test Strategy (defined before implementation)

Categories A–S: unit (A) · repository (B) · RLS (C) · RPC authz (D) · admin-hierarchy attack matrix (E) · region-scope attack matrix (F) · escalation (G) · emergency flow (H) · sanctions (I) · deletion/anonymization (J) · offer approval (K) · birthday idempotency (L) · anniversary idempotency (M) · notifications (N) · realtime (O) · migration idempotency (P) · live DB verification (Q) · secret scan (R) · flutter analyze/test gate (S).

**Minimum actors in security tests:** anon · customer · provider · scoped admin · parent admin · global admin · owner.
**Minimum attack scenarios:** privilege escalation · cross-region access · self-role escalation · self-permission escalation · owner impersonation · unauthorized member data · unauthorized sanction · unauthorized deletion · unauthorized emergency access · unauthorized audio access · unauthorized escalation. **All unauthorized MUST fail server-side.**

---

## 18. Privacy Model

- Least privilege for: exact GPS, last known location, documents, emergency data, audio-session info, account security info.
- **Never expose** passwords/auth secrets or biometric credentials to admins; **no password field in `users`** (Supabase auth owns credentials; `users` is profile only — verified: no password column live).
- Member sections permission-gated (`get_member_profile`); cross-region denied; admin identity/location never shown to customers; "why can I see this?" admin-debug only; retention configurable (M1).

## 19. Phase 2.5 Contract

Phase 2.5 = ACCOUNT + REGISTRATION + PROFILE architecture (Customer/Provider/Driver/Admin). **Not implemented now.**
- 2.3 establishes the required backend primitives only: one authenticated identity (`users` + auth), role-guarded profile fields (DOB/account_status), `member_events` feed, permission/scope plumbing. **No profile tables, no registration rework in 2.3** (boundary M6).
- 2.3 keeps the door open: `users.user_type` + `users.role` already model the four personas; `admin_management`/region scope extend to all personas; member_events per-user.

## 20. Risk Register

| # | Risk | Sev | Mitigation |
|---|------|-----|-----------|
| R1 | Supervision cycle / infinite recursion | High | CHECK + RPC recursive-CTE cycle rejection |
| R2 | Permission-model drift (UI vs server) | High | single `has_permission()` + `explain_admin_access` |
| R3 | Audit-log poisoning (anon INSERT) | High (live) | 033 fix (service_role) |
| R4 | Location privacy leak (driver_locations) | High (live) | 033 fix (participant/admin) |
| R5 | Priority/status client manipulation | High | guard triggers + server routing |
| R6 | Deletion destroys audit | High | soft-delete + anonymize + uuid-preserving refs |
| R7 | Audio misuse / hidden mic | High | foundation-only; grant + active-session + visible state |
| R8 | Cross-region member access | High | scope containment in all member RPCs/RLS |
| R9 | Double rewards (birthday/anniversary) | Med | UNIQUE (user,type,period_key) |
| R10 | No scheduler → engines dormant | Med | edge timer (2.4) + app-open + idempotent engine |
| R11 | Retention purge harming evidence | Med | configurable + archive-then-anonymize |
| R12 | Transport complexity (audio) | Med | deferred; foundation is transport-agnostic |
| R13 | `is_admin_for_region` vs recursive walk drift | Med | document + route via `has_permission` |
| R14 | Table proliferation | Low | 8 tables, each justified; D7 approved |

## 21. Exact Implementation Order

1. **2.3A (033):** schema → RLS fixes → triggers → RPCs → live verify → Flutter (support/emergency lane) → tests → gate.
2. **2.3B (034):** admin_management/permissions/approvals → `has_permission` → admin lifecycle RPCs → Approval Center UI → hierarchy attack matrix → gate.
3. **2.3C (035):** member primitives + timeline + moderation + deletion → member profile/timeline UI → visibility matrix → gate.
4. **2.3D (036):** Command Center + audio foundation → customer-visible indicator → emergency suite → gate.
5. **2.3E (037):** offers + reviews → offer workflow UI → workflow tests → gate.
6. **2.3F (038):** engines + retention → idempotency tests → gate.
7. **2.3G:** final gate report (docs 34) + commit `sprint N: phase 2.3 …` + push.
   Each step = apply → live-verify → Flutter → tests → **stop at gate**; no 2.4/2.5.

## 22. Exit Criteria per Sub-phase

| Sub-phase | Exit criteria |
|-----------|---------------|
| 2.3A | 033 applied + live probes green (routing matrix, priority lock, 3 RLS fixes, anon-revoked); Flutter queue/assign/escalate/emergency-button tested; full suite green |
| 2.3B | hierarchy attack matrix all-pass (self-promote ❌, owner-create ❌, cross-branch ❌, region-escape ❌, subordinate ops ✅); Approval Center works; permissions enforced server-side |
| 2.3C | member-visibility matrix (permission × region) all-pass; deletion + anonymization probes (audit survives, PII cleared, email unique respected); no cross-region leak |
| 2.3D | audio lifecycle (start/end/audit/customer-visible) pass; unauthorized audio ❌; no media columns; command center realtime feed verified |
| 2.3E | offer workflow state machine pass (propose→…→publish; reject/approve require reason; unauthorized approve ❌; no self-publish) |
| 2.3F | engine double-run = no duplicate rewards; correct region/campaign; retention config applied |
| 2.3G | full pre-commit gate (pub get, analyze 0 errors, tests green, secret scan clean) + commit/push + handoff doc |

---

## Final Gate

**Reviewed:** master audit §1–§32 · doc 32 · ADR-055/056/057/058 · directive §§1–18 · live schema (read-only, verified this session).
**Challenges raised & resolved:** dual-model invariants (D1), permission-matrix explicitness + grant-possession (D2), audit-fix safety vs Flutter read (D8/C3), SOS admin scope (C5), scheduler gap (C6), retention defaults (M1), offer approval depth (M2), sanction-approval mapping (M3).
**Remaining items requiring explicit Owner confirmation before implementation starts:** the **6 modifications** (M-D1…M-D8 refs) and **6 missing decisions** (M1…M6), plus ratification of the D1/D2 "APPROVED WITH MODIFICATION" statuses.

ARCHITECTURE LOCK STATUS:

🟡 **REQUIRES OWNER DECISION**

The 10 §32 decisions are individually **recommended-approve** (8 approve, 2 approve-with-modification) and none are rejected, but per the gate rule an approval must not be invented: the Owner must ratify (a) the two APPROVED WITH MODIFICATION decisions (D1 invariants, D2 explicit matrix + grant-possession), (b) the six missing decisions (retention defaults, offer approval depth, sanction-approval mapping, birthday benefit approach, deletion token format, Phase 2.5 primitive boundary), and (c) the six modifications (M-D1…M-D6). On confirmation, this report flips to 🟢 READY FOR IMPLEMENTATION and sub-phase 2.3A (migration 033) may be written. **No code, no migration, no commit/push produced in this gate.**
