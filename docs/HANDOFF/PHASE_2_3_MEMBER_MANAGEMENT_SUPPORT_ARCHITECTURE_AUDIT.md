# PHASE 2.3 — MEMBER MANAGEMENT + SUPPORT + EMERGENCY ARCHITECTURE AUDIT

**Project:** Delwaqty (no other project name).
**Gate:** Architecture Audit ONLY — **no product code, no migration 033, no migrations beyond 033, no commit, no push, no Phase 2.4.**
**HEAD:** `b1081d28b317223ff61f381e9ce1809c8c912ead` (master, clean baseline before this gate's docs).
**Live project:** `bttnlkmwhorjamzemwda` — evidence captured this session via Management API (`/tmp/opencode/sq.py`, PAT never printed/committed).
**Supersedes:** `docs/HANDOFF/32_PHASE_2_3_SUPPORT_CHAT_PRIORITY_ASSIGNMENT_AUDIT.md` for the Phase 2.3 design (that doc's support-chat sections are incorporated here and extended per this directive).
**Authorities:** `PROJECT_CONSTITUTION.md` · AGENTS.md · ADR-049/050/051/052/055/056/057 · docs 25/26/28/30/31.

---

## 1. Current-State Inventory (verified live this session)

### 1.1 Tables (65 public tables, all RLS-enabled except PostGIS `spatial_ref_sys`)

| Domain | Tables (live) | Reuse verdict for 2.3 |
|--------|---------------|------------------------|
| Identity | `users` (5 policies), `admin_users` (dormant legacy) | Reuse `users` as canonical identity; `admin_users` stays dormant (ADR-049/055) |
| Regions | `regions`, `user_region_preferences`, `geo_places`, `geo_aliases`, `geo_admin_boundaries` | Reuse (030/032) |
| Admin authz | `admin_region_assignments` | Reuse for region scope (031) |
| Support | `chat_rooms`, `chat_messages` | Reuse, extend additively (ADR-051/052) |
| Complaints | `complaints` | Reuse (member support history) |
| Moderation | `sanctions` (CHECK: warning/fine/temporary_ban/permanent_ban/suspension; `issued_by`, `duration_days`, `start/end_date`, `is_active`, `complaint_id`) | **Reuse** as moderation ledger |
| Emergency | `sos_alerts` (CHECK alert_type manual/automatic/timer; status active/escalated/resolved/falseAlarm; `ride_id NOT NULL`, lat/lon/address, notified_contact_ids) | Reuse for ride-safety SOS; emergency *support lane* = `chat_rooms.priority='emergency'` (ADR-052) |
| Location | `location_updates` (user GPS), `driver_locations`, `live_share_sessions`, `saved_places`, `user_addresses` | Reuse for member location |
| Docs | `driver_documents` (+ `users.id_card_url/trade_license_url/driving_license_url/profile_photo_url`) | Reuse — no duplicate doc storage |
| Notifications | `notifications`, `notification_tokens` | Reuse (delivery = realtime in-app; FCM = Phase 2.4) |
| Audit | `activity_logs` | Reuse as admin security-audit backplane (**fix insert policy**, §22) |
| Commerce | `offers` (merchant offers), `coupons`, `promo_codes`, `promo_redemptions` | `offers` is merchant-commerce; **regional offers = NEW** (§18) |
| Platform | `platform_settings`, `service_audio_logs`, `activity_logs` | Reuse `platform_settings` for configurable benefit/campaign content |

### 1.2 Users shape (live) — gaps for member management

`id, email, full_name, phone, avatar_url, language, is_onboarded, role (CHECK: customer/merchant/driver/admin/owner/provider/delivery), created_at, updated_at, user_type (CHECK: customer/provider/delivery), verification_status (pending/approved/rejected), id_card_url, profile_photo_url, is_biometric_enabled, username, trade_license_url, driving_license_url`

**Missing for 2.3:** `date_of_birth` (birthday engine), `account_status` (enforceable member status). No DELETE policy exists (deletion = server-side only, correct).

### 1.3 Realtime publication (`supabase_realtime`, live)

`chat_messages, chat_rooms, complaints, notifications, sos_alerts, sanctions, location_updates, driver_locations, driver_documents, driver_earnings, delivery_pricing, live_share_sessions, ride_requests, rides, wallets, withdrawal_requests` — **chat, notifications, sos, sanctions already realtime.** No publication change needed in 2.3.

### 1.4 RPCs (app surface, live)

`is_admin()` · `is_admin(uid)` · `is_admin_for_region(region_id)` (016/031) · `admin_set_user_role(user,role)` + `users_guard_role_change` (031) · `admin_broadcast_notification(...)` (019) · `add_admin_note`/`add_complaint_admin_note` · `resolve_sos_alert`/`trigger_sos_alert` (012) · `get_unread_notification_count` · `get_user_role` · `handle_new_user` · `geo_region_for_point` (032) · ride/driver/merchant RPCs. All new 2.3 RPCs follow the established SECURITY DEFINER pattern (SET search_path, revoke-before-grant, anon EXECUTE revoked).

### 1.5 Policy surface (live, key quals)

| Table | Policy | Live qual | Verdict |
|-------|--------|-----------|---------|
| `activity_logs` | INSERT | **`TO public` WITH CHECK true** | 🔴 FIX (anon/authenticated can poison the audit log) |
| `driver_locations` | "driver location read" SELECT | **`auth.role()='authenticated'`** | 🔴 FIX (any user reads any driver live location) |
| `sos_alerts` | owner rw / ride-participant read | no admin SELECT | 🟡 ADD admin SELECT (emergency command center) |
| `chat_rooms` | "users update own rooms" | `auth.uid() = ANY(participant_ids)` | 🟡 guard trigger (protect priority/status/assignee) |
| `users` | self INSERT/UPDATE/SELECT + admin SELECT/UPDATE (`is_admin()`) | — | 🟡 guard trigger (protect `account_status`/`date_of_birth`/`role`) |
| `sanctions` | admins CRUD (`is_admin()`) + user own SELECT | — | ✅ reuse |
| `notifications` | users own + admins select/insert/delete + service_role insert | — | ✅ reuse |

### 1.6 Baseline facts (live)

`users` = 5 (3 customer, 1 provider, **1 owner** `8a23b719-…`, **0 admin**) · `admin_region_assignments` = 0 · `sanctions` = 0 · `sos_alerts` = 0 · `activity_logs` = 0 · `chat_rooms` = 1 · `complaints` = 0. **Owner fallback is the deterministic routing endpoint today** (0 admins).

---

## 2. Reusable Infrastructure (build on, do not duplicate)

1. **Identity & authz:** `users.role` + `is_admin()` (016) + `is_admin_for_region()` (031) + `admin_region_assignments` (scope self/descendants).
2. **Regions + geo:** full Egypt hierarchy (6,157 regions), `geo_region_for_point` spatial resolution, per-user preference.
3. **Chat:** `chat_rooms`/`chat_messages` + realtime (extend, ADR-051/052).
4. **Notifications:** `notifications` (+`data jsonb`, `deep_link`, idempotency) + realtime in-app; FCM path deferred.
5. **Moderation:** `sanctions` ledger (additive columns only).
6. **Emergency (ride-safety):** `sos_alerts` + `trigger_sos_alert`/`resolve_sos_alert` + realtime.
7. **Location:** `location_updates` (user) / `driver_locations` (driver) with existing admin policies.
8. **Audit:** `activity_logs` (after the §1.5 fix).
9. **Platform settings:** `platform_settings` for configurable campaign/benefit content (not hardcoded).
10. **Flutter:** `support_chat`, `complaints`, `notifications`, `regions`, `sanctions`, `location_tracking`, `safety`, `admin_access.dart`, push/realtime service, admin shell + gate.

---

## 3. Missing Infrastructure (what must be added)

| # | Capability | Gap | Why new (reuse justification) |
|---|-----------|-----|-------------------------------|
| M1 | Admin supervision hierarchy | No supervisor/delegation relation | `admin_region_assignments` is per-(admin,region); supervision is per-admin → new `admin_management` |
| M2 | Permission grants | No permission model beyond `is_admin()` | Defaults computable from role/scope; only deviations need storage → small `admin_permission_grants` (no RBAC engine) |
| M3 | Approval workflow | No generic approvals | Bans/offers/admin-changes need hierarchical approve/reject → `approval_requests` |
| M4 | Member DOB + status | `users` lacks both | Additive columns (server-guarded) |
| M5 | Member timeline | No typed business event feed | `activity_logs` is admin-only + security-shaped; customers must read their own timeline → `member_events` |
| M6 | Emergency live audio | No session/audit model | New `emergency_audio_sessions` (state + audit; transport deferred, §11) |
| M7 | Escalation ledger | On-row columns insufficient for history | `chat_escalations` (previous/new admin, actor, reason, scope transitions) |
| M8 | Regional offers | `offers` is merchant-commerce shaped (merchant_id/branch_id/discount_type/product_ids) | Regional admin-proposed offer with approval chain is a different object → `regional_offers` + `offer_reviews` |
| M9 | Birthday/anniversary rewards | No DOB, no reward ledger | `users.date_of_birth` + `member_rewards` (idempotent) |
| M10 | Moderation enforcement | `sanctions` is audit-only; nothing enforces ban | `users.account_status` (single writer via RPC) |
| M11 | Audit-log fix + location privacy fix | §1.5 findings | RLS changes in 033 |

---

## 4. Proposed Architecture (overview)

```
┌─ Customer/Provider/Driver App ─┐   ┌─ Admin Platform (web + admin_web) ─┐
│  emergency open · chat · docs ·│   │  Command Center · Member Mgmt ·    │
│  timeline · birthday/anniv.    │   │  Moderation · Approval Center ·    │
└──────────────┬─────────────────┘   └──────────────┬────────────────────┘
               │  Supabase Realtime (existing)      │
               └──────────────────┬─────────────────┘
                                  ▼
        ┌─── Server-side authority (RPCs, SECURITY DEFINER) ───┐
        │  permission engine: identity+role+supervisor+scope+   │
        │  permission+target+target-region+action  (server)     │
        │  is_admin() · is_admin_for_region() · has_permission()│
        └───────────────┬───────────────────────────────────────┘
                        ▼
        ┌─ data: chat_rooms+escalations · sos_alerts ·          ┐
        │ sanctions · users+account_status · member_events ·    │
        │ regional_offers+reviews · approval_requests ·         │
        │ emergency_audio_sessions · member_rewards ·           │
        │ activity_logs (audit) · notifications · location      │
        └───────────────────────────────────────────────────────┘
```
All four clients (Customer/Provider/Driver/Admin) operate over the **same** backend; the server is the only authorization authority. UI reflects permissions; RLS/RPCs enforce them.

---

## 5. Admin Hierarchy (hierarchical delegation, no hardcoded levels)

**Model — two orthogonal axes:**

1. **Supervision tree** (management/delegation/approvals): new `admin_management(admin_id PK, supervisor_id FK, is_active, created_by, created_at, updated_at)`, `CHECK (admin_id <> supervisor_id)`.
   - `owner` has **no row** (implicit root, global authority). Only owner creates/promotes Owner.
   - An `admin`'s `supervisor_id` = the admin above them (chain terminates at owner).
   - Depth is **derived from the tree** (recursive CTE), never a stored rank → "no fixed admin levels".
   - Example: owner → Higher Admin (Giza) → City Admin → District Admin → Village Admin (any depth).
2. **Region scope** (visibility/routing): existing `admin_region_assignments` (scope self/descendants; no rows = global; owner implicit global). Routed scope follows the *region* hierarchy (parent-region walk); management scope follows the *supervision* tree.

**Rules enforced server-side:**
- Admin may create/assign/deactivate **only subordinates** (`is_descendant_of(actor, target)` recursive check in RPC).
- Admin may **not** modify superior, self-promote, create owner, escape their region scope, or assign regions outside their own scope.
- Region assignment of a subordinate must be **contained in** the actor's own scope (or actor is owner/global).
- No admin seeds (owner = `8a23b719-…` only admin-tier live).

---

## 6. Permission Matrix (smallest clean model)

**Decision:** *Computed defaults + explicit grants.* No full RBAC engine.

- **Defaults** derived per (role, admin, region scope): owner = all; admin = all **within scope** except the explicitly-granted list below.
- **`admin_permission_grants(admin_id, permission, granted_by, granted_at)`** stores only explicit grants (and the permission constants are text, single table, additive).
- Server evaluates **all seven inputs** (directive): actor identity + actor role + supervisor relationship + delegated permission + actor geographic scope + target + target region + requested action.

| Permission | Default (admin, in-scope) | Requires explicit grant | Notes |
|-----------|:---:|:---:|-------|
| MEMBER_VIEW | ✅ | — | |
| MEMBER_VIEW_LOCATION | ✅ | — | subject to retention/privacy gate (§24/25) |
| MEMBER_VIEW_DOCUMENTS | — | ✅ | sensitive (§14) |
| MEMBER_VIEW_CHAT_HISTORY | ✅ | — | within scope |
| MEMBER_VIEW_COMPLAINTS | ✅ | — | within scope |
| MEMBER_VIEW_TIMELINE | ✅ | — | customer sees own; admin per scope |
| MEMBER_MODERATE / WARN / RESTRICT | ✅ | — | issued_by = actor |
| MEMBER_SUSPEND | ✅ (≤ tier) | — | longer/higher-tier penalties require approval (approval center) |
| MEMBER_BAN | — | ✅ + approval | approval required (higher admin/owner) |
| MEMBER_DELETE | — | ✅ + owner/higher + deliberate confirmation | deletion = member management, NOT moderation (§8) |
| EMERGENCY_VIEW | ✅ | — | |
| EMERGENCY_AUDIO | — | ✅ | opt-in; only for eligible active emergency sessions (§11) |
| ADMIN_CREATE / ASSIGN / ROLE_ASSIGN / REGION_ASSIGN / SUPERVISOR_ASSIGN / SUSPEND | ✅ (subordinates only) | — | always supervisor-scoped |
| OFFER_CREATE | ✅ | — | propose only |
| OFFER_REVIEW | ✅ (higher admin) | — | |
| OFFER_APPROVE | — | ✅ (hierarchy-dependent) | approval depth = supervision chain |
| OFFER_PUBLISH | owner | — | owner final authority |

**Key helper (server):**
```sql
public.has_permission(p_permission text, p_region_id uuid DEFAULT NULL, p_target_admin_id uuid DEFAULT NULL) RETURNS boolean
-- SECURITY DEFINER; evaluates the 7-input tuple; used by every sensitive RPC/RLS policy.
```
Final exact penalty/approval mapping is **not hardcoded now** — the matrix is data/config-driven so the mapping can be tuned without schema changes.

---

## 7. Member Visibility Matrix + "Why Can I See This?"

### 7.1 Visibility (permission × region × relation)

| Member data | Member (self) | Admin (in-scope + permission) | Other |
|-------------|:---:|:---:|:---:|
| Basic (name, phone, email, join date, status) | ✅ own | ✅ MEMBER_VIEW | ❌ |
| DOB / account status | ✅ own | ✅ MEMBER_VIEW (status) / sensitive-guarded (DOB shown to admin) | ❌ |
| Last known location / activity | ✅ own (recent) | ✅ MEMBER_VIEW_LOCATION (+retention) | ❌ |
| Documents metadata | ✅ own | ✅ MEMBER_VIEW_DOCUMENTS (explicit grant) — metadata only; raw URL additionally gated | ❌ |
| Support chats / complaints / resolutions / escalation history | ✅ own | ✅ MEMBER_VIEW_CHAT_HISTORY / COMPLAINTS (in scope) | ❌ |
| Moderation history | ✅ own (their penalties) | ✅ MEMBER_VIEW (in scope) | ❌ |
| Emergency (SOS, emergency chat, GPS, audio) | ✅ own (active) | ✅ EMERGENCY_VIEW (+EMERGENCY_AUDIO for audio) | ❌ |

Sensitive sections are returned by a **single aggregate RPC** `get_member_profile(p_member_id uuid)` that sections the payload by permission — no raw table exposure. Cross-region access denied server-side.

### 7.2 "Why can I see this?" (internal debug/support only)

RPC `explain_admin_access(p_member_id uuid) RETURNS jsonb` returns the reason chain, e.g.:
```json
{"access": true, "reasons": [
  {"dimension": "role", "detail": "admin"},
  {"dimension": "supervisor", "detail": "within branch of Giza Higher Admin"},
  {"dimension": "region_scope", "detail": "admin_region_assignments covers member region EG-ADM2-2106 (self/descendants)"},
  {"dimension": "permission", "detail": "MEMBER_VIEW (default)"}]}
```
Shown only inside the admin member-profile debug panel. **Never exposed to customers.** Uses the same evaluation function as enforcement (no drift).

---

## 8. Moderation Architecture

- **Ledger:** reuse `sanctions` (live CHECK covers warning/fine/temporary_ban/permanent_ban/suspension; `target_role` covers customer/driver/merchant/provider/admin). Additive columns in a later migration:
  - `approving_admin_id uuid REFERENCES users(id)` (approver when required)
  - `evidence_url text` (reference)
  - `action_status text CHECK ('active','expired','revoked','completed') DEFAULT 'active'`
- **Enforcement:** `users.account_status` (`active/restricted/suspended/banned/deactivated`) — set **only** by SECURITY DEFINER RPCs `issue_sanction` / `revoke_sanction` (+ trigger guards so clients/RLS can't touch it). Sanction → status mapping server-side (ban→banned, suspension→suspended, warning/restrict→restricted; auto-expiry flips back).
- **Penalty authority:** hierarchical (role + delegation + region + permission + approval) — §6; final mapping config-driven, not hardcoded.
- **Account deletion is NOT a moderation action** — it lives in member management (§9).

---

## 9. Account Deletion Architecture

- **RPC:** `delete_member_account(p_member_id uuid, p_confirmation_token text, p_reason text)` — requires MEMBER_DELETE grant + supervisor/owner authority + a deliberate confirmation token (e.g., `"DELETE <email>"` supplied server-side) + approval where configured.
- **Soft-delete + anonymize, never destroy audit:**
  1. `users.account_status = 'deactivated'`, `anonymized_at = now()`.
  2. PII columns anonymized (`full_name/email/phone/avatar_url/id_card_url/*_url/username` → `null` or deterministic hash); `email` replaced with `deleted-<uuid>@anonymized`.
  3. Historical rows keep FKs via a stable reference (uuid id is NOT deleted); `member_events`/`activity_logs`/`sanctions`/`chat_messages` retain the anonymized identity — audit integrity preserved.
  4. Real-time/app access blocked by `account_status='deactivated'`.
- **Prevent accidental deletion:** confirmation token + audit `activity_logs` entry (`MEMBER_DELETED`, actor, reason, token-verified flag).
- Retention of records = audit policy (§25).

---

## 10. Emergency Command Center

One coherent admin workflow: **SOS → Member → GPS → Region → Assigned Admin → Emergency Chat → Live Audio → Escalation → Resolution.**

```
sos_alerts (ride-safety, live)        chat_rooms.priority='emergency' (support lane, ADR-052)
        │                                        │
        └──────────► Command Center view ◄───────┘
        GPS (sos lat/lon or geo_region_for_point) → canonical region
        → routing (region → parent → global → owner) → assigned admin
        → emergency chat (same engine as support) → live audio (§11)
        → escalation (§14) → resolution (status closed / sos resolved)
```

- **Add:** `sos_alerts` admin SELECT policy (`is_admin()`); realtime already publishes `sos_alerts` and `chat_rooms` → the center is a realtime feed, no polling.
- **Resolution:** `resolve_emergency(p_chat_id)` closes the chat lane; `resolve_sos_alert` already exists for ride SOS.
- Emergency GPS is **not** a live map by default — region + snapshot (privacy, §24).

---

## 11. Emergency Live Audio Security Model

**Not surveillance.** Microphone access only for an eligible **active** emergency session, only by an admin with the explicit **EMERGENCY_AUDIO** grant, always customer-visible, never hidden, never recording unless explicitly required (not required now).

- **New table** `emergency_audio_sessions` (state + audit; transport deferred):
  ```sql
  CREATE TABLE public.emergency_audio_sessions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    emergency_chat_id uuid NOT NULL REFERENCES public.chat_rooms(id),
    customer_id uuid NOT NULL REFERENCES public.users(id),
    admin_id uuid NOT NULL REFERENCES public.users(id),
    region_id uuid REFERENCES public.regions(id),
    status text NOT NULL DEFAULT 'requested'
      CHECK (status IN ('requested','active','ended','cancelled')),
    started_at timestamptz,
    ended_at timestamptz,
    reason text,
    created_by uuid NOT NULL REFERENCES public.users(id),
    created_at timestamptz NOT NULL DEFAULT now()
  );
  ```
- **RPCs** (016 pattern): `start_emergency_audio(p_emergency_chat_id, p_reason)` — validates: active emergency room (`priority='emergency'`, status open/assigned) + admin has EMERGENCY_AUDIO + customer is a participant → status 'requested'→'active', realtime broadcast → **customer sees active indicator** (in-app banner + red persistent chip). `end_emergency_audio(p_session_id)` — status 'ended', `ended_at`, audit.
- **Audit:** row + `activity_logs` (`EMERGENCY_AUDIO_STARTED`/`EMERGENCY_AUDIO_ENDED` with session_id, customer, admin, region, reason).
- **Transport:** **deferred, no WebRTC chosen yet.** 2.3 builds the permission/state/audit foundation. Options (documented for a dedicated audio review, Phase 2.4+): (a) app-native WebRTC with a small SFU, (b) Twilio Voice (managed, PA is KSA/Egypt—latency review), (c) third-party voice rooms. Rejected now: always-on mic, silent mic, background surveillance, hidden recording — **DO NOT implement**.

---

## 12. Support Chat (Phase 2.3 core — incorporated from doc 32)

**Migration 033** (additive, data-preserving, on `chat_rooms`, ADR-051/052):

| Column | Type / constraint |
|--------|-------------------|
| `priority` | `text NOT NULL DEFAULT 'low' CHECK (IN ('low','medium','high','urgent','emergency'))` |
| `region_id` | `uuid REFERENCES regions(id)` |
| `assigned_admin_id` | `uuid REFERENCES users(id)` |
| `assigned_at` | `timestamptz` |
| `status` | `text NOT NULL DEFAULT 'open' CHECK (IN ('open','assigned','escalated','closed'))` |
| `escalated_at` | `timestamptz` |
| `escalated_from_admin_id` | `uuid REFERENCES users(id)` |
| `closed_at` | `timestamptz` |

Indexes: `(status)`, `(assigned_admin_id)`, `(region_id)`, `(priority)`, partial `(assigned_admin_id) WHERE status IN ('open','assigned')`.

**Guard triggers** (SECURITY DEFINER): BEFORE INSERT forces `priority='low'` + `status='open'` + null assignee for non-admins, backfills `region_id` from `user_region_preferences`; BEFORE UPDATE restores `priority/status/assigned_admin_id/escalation fields/closed_at` to OLD for non-admins (customers may only touch message-level fields). Customers **cannot** set priority (contract).

**RPCs:** `resolve_support_admin(region_id, prefer_region)` · `route_support_chat(room_id)` · `assign_support_chat(room_id, admin_id)` · `escalate_support_chat(room_id, reason)` · `open_emergency_chat(lat, lon, message)` · `close_support_chat(room_id)`.

**Realtime:** reuse existing `chat_rooms`/`chat_messages` publications; admin feed filters `status IN ('open','assigned')` client-side; room row UPDATE broadcasts assignment/escalation/status.

---

## 13. Routing (deterministic, server-side)

`Customer → Canonical Region → Regional Admin → Parent Region Admin → Higher Regional Admin → Global Admin → Owner`

1. Customer canonical region = `user_region_preferences` (normal) or `geo_region_for_point` HIGH/MEDIUM (emergency).
2. **Region-scoped admins:** recursive ancestor chain of `regions.parent_region_id` matched against `admin_region_assignments` (scope self/descendants), **most-specific match first** (depth ASC), tiebreak = fewest open assigned rooms → lowest `admin_id` (stable).
3. **Parent-region walk:** no match at a level → next ancestor region's admin (reuses chain).
4. **Global admins** (no assignment rows) — load tiebreak.
5. **Owner** (implicit global) — deterministic lowest id. **Live baseline: 0 admins → all rooms route to owner `8a23b719-…`.**
6. NULL if no admin-tier exists → `status='open'`, unassigned (surfaced in admin queue).

Clients never choose admins; priority is server-forced; routing is reproducible (same inputs → same admin).

---

## 14. Escalation

- **Same conversation, never a new room** (ADR-051).
- On-row columns (`escalated_at`, `escalated_from_admin_id`) + **new `chat_escalations` ledger** for full history (previous/new admin, actor, timestamp, reason, previous scope, new scope) + `activity_logs` entry.
- `escalate_support_chat(room_id, reason)`: records escalation, then re-routes to next tier (§13 steps 2–5) **excluding the current assignee**; notifies new assignee + customer.
- Terminal: owner escalator → `status='escalated'`, `assigned_admin_id=NULL` (owner queue).
- Priority **never decreases** on escalation; region scope transitions recorded in ledger.

---

## 15. Member Timeline

- **New `member_events`** (typed business feed — customer-readable subset + admin-readable superset, per-scope):
  ```sql
  CREATE TABLE public.member_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    event_type text NOT NULL,
    actor_id uuid REFERENCES public.users(id),
    related_entity text, related_entity_id text,
    region_id uuid REFERENCES public.regions(id),
    metadata jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
  );
  CREATE INDEX member_events_user_created_idx ON public.member_events (user_id, created_at DESC);
  ```
- `event_type` CHECK covers: `account_created, login, location_update, support_opened, support_assigned, support_escalated, support_resolved, complaint_created, complaint_assigned, complaint_escalated, complaint_resolved, moderation_action, suspension, ban, sos, emergency_opened, emergency_admin_connected, emergency_resolved, document_verified, birthday_reward, anniversary_reward, account_deactivated`.
- Written by the domain RPCs/triggers themselves (no N+1, no generic hooks).
- **RLS:** user reads own rows (server filters out internal/security metadata types); admin reads via `MEMBER_VIEW_TIMELINE` + region scope. Pagination (keyset) — never load whole timeline.
- Rationale vs `activity_logs`: different audiences (customer-facing vs admin-security audit), different retention, customer RLS visibility. Both are written from the same actions.

---

## 16. Birthday Engine

- `users.date_of_birth` (new, guarded — only self + MEMBER_VIEW admin).
- **RPC** `run_member_engines(p_run_date date DEFAULT current_date)` — idempotent:
  1. eligibility (account_status active, DOB set);
  2. member region (`user_region_preferences`/geo);
  3. active regional birthday campaign lookup (content from `platform_settings`/campaign config — **not hardcoded**);
  4. apply approved benefit;
  5. personalized notification using `full_name` (l10n-keyed template; example content EN/AR provided by config, not code).
- **Duplicate prevention:** `member_rewards(user_id, reward_type='birthday', period_key='birthday:2026') UNIQUE` → second run is a no-op.
- Trigger: scheduled edge function (Phase 2.4 infra) or best-effort app-open call; no pg_cron today (documented).

---

## 17. Anniversary Engine

- Uses `users.created_at` (join date); every completed year (1, 2, 3, …).
- Same `run_member_engines` flow; `period_key='anniversary:2'` → **unique per (member, year)**.
- Notification: registered name + years count + greeting + approved benefit (configurable). Duplicate prevention via the same unique constraint.

---

## 18. Regional Offers

- **New `regional_offers`** (admin-proposed, region-scoped — distinct from merchant `offers`):
  ```sql
  CREATE TABLE public.regional_offers (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    region_id uuid NOT NULL REFERENCES public.regions(id),
    title text NOT NULL, description text, benefit text, eligibility jsonb,
    starts_at timestamptz, ends_at timestamptz,
    limits jsonb, budget numeric,
    proposed_by uuid NOT NULL REFERENCES public.users(id),
    reason text,
    status text NOT NULL DEFAULT 'draft'
      CHECK (status IN ('draft','submitted','under_review','approved','rejected','published','expired','cancelled')),
    published_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
  );
  CREATE TABLE public.offer_reviews (          -- full approval audit
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    offer_id uuid NOT NULL REFERENCES public.regional_offers(id) ON DELETE CASCADE,
    reviewer_id uuid NOT NULL REFERENCES public.users(id),
    action text NOT NULL CHECK (action IN ('submit','approve','reject','publish','cancel')),
    reason text, previous_state text NOT NULL, new_state text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
  );
  ```
- **Workflow:** Regional Admin proposes (DRAFT→SUBMITTED) → Higher Admin reviews (UNDER_REVIEW) → …approval depth follows the **supervision chain** → Owner final approval (APPROVED) → publish (PUBLISHED). A Regional Admin **never** self-publishes.
- Every transition requires reason (`offer_reviews.reason` NOT NULL for approve/reject).
- RPCs: `propose_regional_offer`, `submit_regional_offer`, `review_regional_offer(action, reason)` — each validates authority via `has_permission(OFFER_*)` + supervision chain.
- Expiry: `expires_at < now()` → status `expired` (via engine).

---

## 19. Approval Workflow

- **Generic `approval_requests`** — one center, no scattered approval UIs:
  ```sql
  CREATE TABLE public.approval_requests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    request_type text NOT NULL,              -- admin_create | admin_role_change | admin_region_change |
                                             -- admin_supervisor_change | admin_deactivate | ban |
                                             -- member_delete | offer_approve | offer_publish | ...
    entity_type text NOT NULL, entity_id uuid,
    payload jsonb,
    requested_by uuid NOT NULL REFERENCES public.users(id),
    required_approver uuid REFERENCES public.users(id),   -- null = owner
    state text NOT NULL DEFAULT 'pending'
      CHECK (state IN ('pending','approved','rejected','cancelled')),
    reason text,
    decided_by uuid REFERENCES public.users(id),
    decided_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
  );
  CREATE UNIQUE INDEX approval_requests_pending_unique
    ON public.approval_requests (request_type, entity_id) WHERE state = 'pending';
  ```
- RPCs: `submit_approval_request(...)`, `decide_approval_request(p_request_id, p_decision, p_reason)` — `required_approver` or a superior can decide; reason required for reject (and approve where configured).
- Types that flow through it (config-driven which require approval): bans, member delete, admin create/role/region/supervisor changes, offer approval/publish.
- Pending items surface in the **Approval Center** (admin platform page) filtered by `required_approver` scope.

---

## 20. Approval Center (UI contract)

- Admin platform page `/admin/approvals`: pending list (type, entity, requester, reason, requested_at), detail (payload), **Approve / Reject (reason mandatory on reject)**.
- Visibility = items the actor may decide (owner: all; admin: subordinates' requests within their branch/scope per `has_permission`).
- Every decision → `approval_requests` state change + `offer_reviews`/`admin_management`/`sanctions` execution where applicable + `activity_logs` entry + notification to requester.
- No scattered approval flows in other pages.

---

## 21. RLS Design (migration-scoped)

**In 033 (core fixes + support chat):**
1. `activity_logs` INSERT: drop `TO public` → `TO service_role` (audit writes only via SECURITY DEFINER RPCs) — **fixes live anon-write finding**.
2. `driver_locations` read: replace `auth.role()='authenticated'` with ride-participant + admin (`is_admin()`) — **fixes live privacy finding**.
3. `sos_alerts`: add admin SELECT (`is_admin()`).
4. `chat_rooms`: guard triggers protect `priority/status/assigned_admin_id/escalation/closed_at`.
5. `users`: guard trigger protects `role/account_status/date_of_birth` from client writes (self-update policy remains for safe fields).

**In later migrations (per domain):**
- `admin_management`, `admin_permission_grants`, `approval_requests`: ALL `TO public` USING/WITH CHECK `is_admin()`; `member_events`: user own SELECT (safe types) + admin SELECT (`has_permission(MEMBER_VIEW_TIMELINE)` + scope); `regional_offers`: public SELECT only published+within-window, admin CRUD per permission; `offer_reviews`/`emergency_audio_sessions`: admin (permission-gated) + customer own-view (audio status only); `member_rewards`: user own + admin.
- Every new table: revoke-before-grant (030 lesson), anon EXECUTE revoked, authenticated-only grants.

---

## 22. RPC Design (016 pattern everywhere)

| RPC | Gate | Purpose |
|-----|------|---------|
| `has_permission(permission, region, target_admin)` | — | central decision engine (used by policies/other RPCs) |
| `explain_admin_access(member_id)` | admin | "why can I see this?" (debug, §7.2) |
| `get_member_profile(member_id)` | admin | sectioned member payload by permission |
| `create_admin_account / assign_admin_role / assign_admin_region / change_supervisor / deactivate_admin` | supervisor + permission | admin lifecycle (supervision tree + region containment) |
| `issue_sanction / revoke_sanction` | permission + approval | moderation + `account_status` enforcement |
| `delete_member_account(member_id, token, reason)` | MEMBER_DELETE + approval | deletion (§9) |
| `route_support_chat / assign_support_chat / escalate_support_chat / open_emergency_chat / close_support_chat` | §12–14 | support/emergency lane |
| `start_emergency_audio / end_emergency_audio` | EMERGENCY_AUDIO + active session | §11 |
| `propose/submit/review_regional_offer` | OFFER_* + supervision | §18 |
| `submit/decide_approval_request` | authority + scope | §19 |
| `run_member_engines(date)` | service | birthday/anniversary/offer-expiry (idempotent) |
| `write_audit(action, resource, resource_id, details)` | — | internal helper (service_role-only writes) |

All: `SECURITY DEFINER`, `SET search_path = public, pg_temp`, revoke anon, grant authenticated/service_role, validate server-side, write `activity_logs` + `member_events` + notifications atomically.

---

## 23. Audit Design

- **Backplane:** `activity_logs` (post-fix). Every security-sensitive action writes: `action` (vocabulary below), `user_id` (actor, text), `resource`/`resource_id` (target), `details` jsonb (previous state, new state, reason, region, correlation id), `timestamp`.
- **Vocabulary (from directive):** `ADMIN_CREATED, ADMIN_ROLE_CHANGED, ADMIN_REGION_ASSIGNED, ADMIN_REGION_CHANGED, ADMIN_SUPERVISOR_CHANGED, ADMIN_DEACTIVATED, ADMIN_REASSIGNED, MEMBER_WARNED, MEMBER_RESTRICTED, MEMBER_SUSPENDED, MEMBER_BANNED, MEMBER_DELETED, EMERGENCY_AUDIO_STARTED, EMERGENCY_AUDIO_ENDED, OFFER_CREATED, OFFER_APPROVED, OFFER_REJECTED, OFFER_PUBLISHED, SUPPORT_ASSIGNED, SUPPORT_ESCALATED, SUPPORT_CLOSED`.
- Domain ledgers add structure: `chat_escalations`, `offer_reviews`, `approval_requests`, `emergency_audio_sessions`, `sanctions`, `member_rewards`.
- `correlation_id` (uuid) threaded through multi-step flows (e.g., one ban = request + sanction + status change + notification share an id).
- Anon/authenticated direct writes blocked (§21-1); only SECURITY DEFINER RPCs append.

---

## 24. Privacy Model

| Sensitive type | Default access | Guards |
|----------------|----------------|--------|
| GPS / location | owner-of-record, admin w/ MEMBER_VIEW_LOCATION, ride participants | permission + retention + no exact admin location exposed to customers |
| Documents | owner, admin w/ MEMBER_VIEW_DOCUMENTS (explicit) | metadata-first; raw URL additionally gated |
| Emergency data | customer + assigned admin (EMERGENCY_VIEW) | scope + active-session only |
| Microphone | none; EMERGENCY_AUDIO grant + active emergency + customer-visible | no hidden/always-on/recording |
| Support history | participants + in-scope admin | scope + permission |
| Moderation history | member (own) + in-scope admin | scope |

- No unlimited location history (§25). Customer-facing surfaces never expose admin identity/location. "Why can I see this?" is admin-only debug.

---

## 25. Retention Model

Configurable, not arbitrary-infinite. New `retention_policies` table (or `platform_settings` keys) with documented assumptions (product/legal review pending):

| Domain | Proposed default | Configurable |
|--------|------------------|:---:|
| `location_updates` / `driver_locations` | 90 days | ✅ |
| `member_events` | 5 years | ✅ |
| `activity_logs` (audit) | 7 years (legal) | ✅ |
| `sanctions` / moderation | 7 years | ✅ |
| `chat_messages` | 2 years | ✅ |
| `emergency_audio_sessions` (metadata; no recordings) | 2 years | ✅ |
| `notifications` | 1 year (read) | ✅ |
| `regional_offers` | lifecycle + 5 years audit | ✅ |

Engine RPC `apply_retention_policies()` runs on the same schedule as member engines; purges/anonymizes per config (location rows hard-deleted; audit rows archived-then-anonymized, never silently destroyed).

---

## 26. Database Schema Proposal (summary of additions, all migrations)

| Migration (proposed) | Scope |
|----------------------|-------|
| **033** | `chat_rooms` priority/region/assignment/escalation/closed + indexes + guard triggers + routing/emergency/close RPCs + RLS fixes (`activity_logs` insert, `driver_locations` read, `sos_alerts` admin) |
| **034** | `admin_management` + `admin_permission_grants` + `approval_requests` + admin lifecycle RPCs + `has_permission`/`explain_admin_access` + audit vocabulary |
| **035** | `users.date_of_birth` + `users.account_status` + `member_events` + `sanctions` additive cols + moderation/deletion RPCs + `get_member_profile` |
| **036** | `emergency_audio_sessions` + command-center RPCs + realtime status surface |
| **037** | `regional_offers` + `offer_reviews` + offer workflow RPCs |
| **038** | `member_rewards` + `run_member_engines` (birthday/anniversary) + retention config + engine schedule hook |

Each migration = its own gate (apply → live verify → Flutter layer → tests). **Numbers above are proposals; only 033 is next, and 033 is not written in this gate.**

---

## 27. Migration Strategy

1. Pre-apply gate per migration: `flutter analyze` + `flutter test` green; live read-only baseline reconfirm.
2. Write migration idempotent (IF NOT EXISTS / revoke-before-grant / DO UPDATE), 016-pattern RPCs, anon EXECUTE revoked.
3. Apply via Management API `bttnlkmwhorjamzemwda`; **live verify** schema + ACL + functional RLS attack matrix before Flutter.
4. Flutter layer additive (reuse support_chat/complaints/notifications/regions/sanctions modules; new admin pages under existing `/admin` shell + `admin_web` gate).
5. Gate: full pre-commit gate (pub get, analyze, test), commit `sprint N: …`, push.

---

## 28. Test Strategy

| Domain | Tests |
|--------|-------|
| Member visibility | region-scope ✅/deny · permission-based sections · cross-region deny · location/docs/chat/complaint/timeline access |
| Admin hierarchy | create subordinate ✅ · self-promote ❌ · create owner (non-owner) ❌ · change own supervisor ❌ · Giza→Alexandria admin ❌ · modify higher admin ❌ · escape region ❌ · deactivate subordinate ✅ |
| Moderation | warn/restrict/suspend/ban · unauthorized action ❌ · approval-gated bans · revocation/expiry |
| Deletion | unauthorized ❌ · authorized ✅ + audit preserved + anonymization + double-confirm |
| Emergency | active-emergency requirement · EMERGENCY_AUDIO-granted admin ✅ · non-granted ❌ · start/end · audit · customer-visible state · **no hidden audio** |
| Support | create · routing determinism · assignment · escalation same-room · owner fallback (live 0-admin baseline) · priority lock · emergency priority · realtime state |
| Offers | propose · higher review · owner final · reject/approve require reason · unauthorized approve ❌ · publication rules |
| Birthday/Anniversary | correct date/member/region/campaign · duplicate prevention (unique key) |
| Migration | fresh install · upgrade · idempotency · data preservation |
| Security (attack matrix) | the 15-scenario list from the directive (self-promotion, owner-create, supervisor-change, cross-branch modify, cross-region access, region escape, member deletion, ban, audio, docs, location, owner valid, delegated valid) — **all unauthorized MUST fail server-side** |

Unit (mocktail) + SQL live probes (JWT-claims sim, the established pattern) + Dart integration.

---

## 29. Performance / Scale

- Indexes on every authz filter (`admin_region_assignments(region_id)`, `member_events(user_id, created_at DESC)`, `approval_requests(state, required_approver)`, `regional_offers(region_id, status)`, `chat_rooms(status)` partial).
- **No N+1:** aggregate member profile is a single RPC with batched queries; routing uses set-based CTEs, not per-admin lookups.
- **Pagination everywhere** (keyset, not OFFSET): member lists, timeline, chat history, approvals, offers, audit.
- Realtime only on relevant tables (already published); admin feeds filter client-side with partial indexes backing server queries.
- No unbounded streams; no `SELECT *` admin lists without filters; no full-table scans in RLS quals (containment joins indexed).

---

## 30. Risk Register

| # | Risk | Sev | Mitigation |
|---|------|-----|-----------|
| R1 | Admin supervision tree cycles | High | `CHECK admin_id <> supervisor_id` + RPC-level cycle rejection (recursive CTE walk) |
| R2 | Permission model drift (UI vs server) | High | Single `has_permission()` used by RPCs+RLS; `explain_admin_access` surfaces the same decision |
| R3 | `activity_logs` anon-write poisons audit | High (live) | Fixed in 033 (service_role only) |
| R4 | `driver_locations` readable by any user | High (live) | Fixed in 033 (participant + admin) |
| R5 | Customer manipulates chat priority/status | High | Guard triggers + server-only routing |
| R6 | Account deletion destroys audit | High | Soft-delete + anonymize + FK-preserving stable ids |
| R7 | Emergency audio abuse/hidden recording | High | EMERGENCY_AUDIO grant + active-session-only + customer-visible state + no recording |
| R8 | Unauthorized cross-region member access | High | Scope containment in every member RPC/RLS |
| R9 | Birthday/anniversary double-reward | Med | Unique (user, type, period_key) |
| R10 | No cron → engines not triggered | Med | Edge-function schedule (Phase 2.4) + app-open best-effort + documented |
| R11 | Retention purge destroys audit prematurely | Med | Configurable defaults + archive-then-anonymize, never silent destroy |
| R12 | WebRTC/SFU complexity | Med | Transport deferred; 2.3 = permission/state/audit foundation only |
| R13 | Scale: unindexed authz queries | Med | Indexes + set-based routing + pagination (§29) |

---

## 31. Implementation Phases

| Phase | Content | Exit gate |
|-------|---------|-----------|
| 2.3A (033) | Support chat priority/region/assignment/escalation + guard triggers + routing + emergency chat lane + RLS fixes + Flutter (admin queue/priority/assign/escalate, customer emergency button) + tests | Live probes + full pre-commit gate |
| 2.3B (034) | Admin delegation: `admin_management`, permission grants, `approval_requests`, `has_permission`, admin lifecycle RPCs, Approval Center UI + admin branch/scope management | Live hierarchy attack matrix |
| 2.3C (035) | Member management: DOB/account_status, `member_events` timeline, moderation extension + enforcement, deletion + anonymization, `get_member_profile` + "why can I see this?" | Member visibility matrix |
| 2.3D (036) | Emergency Command Center + `emergency_audio_sessions` (state/audit, customer-visible indicator) | Emergency test suite |
| 2.3E (037) | Regional offers + offer reviews + workflow | Offer workflow tests |
| 2.3F (038) | Birthday/anniversary engines + `member_rewards` + retention engine | Engine idempotency tests |
| 2.3G | Final audit + gate report + docs | Commit + push |

Each phase stops at its gate (no code before approval; no 2.4).

---

## 32. Explicit Decisions Required from Owner

1. **Approve the supervision + region-scope dual model** (`admin_management` tree for management/approvals; `admin_region_assignments` for visibility/routing). Owner = implicit root, no row.
2. **Approve permission model:** computed defaults + `admin_permission_grants` (no RBAC engine), final penalty/approval mapping left config-driven.
3. **Approve `users` additions:** `date_of_birth` + `account_status` (guarded, server-only writes).
4. **Approve soft-delete + anonymize** for account deletion (audit preserved, no hard destroy).
5. **Approve emergency audio foundation-only** in 2.3 (sessions+permissions+audit+customer-visible state; **no transport choice, no recording**); WebRTC/Twilio decision deferred to a dedicated audio review.
6. **Approve `member_events` as a separate customer-readable timeline** (vs reusing admin-only `activity_logs`).
7. **Approve new tables** `regional_offers`+`offer_reviews` (distinct from merchant `offers`), `approval_requests` (generic Approval Center), `member_rewards`, `chat_escalations`, `emergency_audio_sessions`.
8. **Approve RLS fixes in 033:** `activity_logs` INSERT→service_role, `driver_locations` read→participant+admin, `sos_alerts` admin SELECT.
9. **Approve routing order** region-scoped → parent-region → global → owner (deterministic; live = owner fallback).
10. **Confirm no admin seeding** — owner `8a23b719-…` remains the only admin-tier account.

---

## Source of Truth

- Live evidence this session (Management API `bttnlkmwhorjamzemwda`): §1 inventories, policy quals (§1.5), realtime publication (§1.3), RPC list (§1.4), constraints (sanctions/sos/users CHECKs).
- Repo: `supabase/migrations/012,014,015,016,018,019,020,026,029,030,031,032` · `docs/HANDOFF/25,26,27,28,29,30,31,32` · `lib/features/{support_chat,complaints,notifications,regions,sanctions,safety,location_tracking,admin,admin_web}` · `lib/core/auth/admin_access.dart` · `lib/services/push_notification/**`.
- No live claims beyond what was actually executed this session (per directive).
