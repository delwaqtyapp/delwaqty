# Sprint 76 — Phase 2.2 Architecture + Audit Gate (Admin Hierarchy Unification, D1)

> **Date:** 2026-08-15 — **Type:** Audit + Design Gate (no migrations, no product code, no commit)
> **Baseline:** `1f3ba02` sprint 76 "add regional system" (Phase 2.1 shipped + pushed). Migration 030
> live, 663/663 tests, analyze 0 errors.
> **Authorities:** `PROJECT_CONSTITUTION.md` > `AGENTS.md` > this gate. Precedents:
> `docs/HANDOFF/25_SPRINT_76_PHASE2_ARCHITECTURE_AUDIT.md` (D1 defined) and
> `docs/HANDOFF/26_SPRINT_76_PHASE2_DESIGN_DECISIONS.md` (D1 resolved → ADR-049).

---

## 1. Verdict (read this first)

| | |
|---|---|
| **🟢 READY TO PROCEED TO PHASE 2.2 IMPLEMENTATION** | Current-state audit complete; D1 re-verified **live**; hierarchy/permission/region-authz/RLS/schema designs produced; Phase 2.3 contract specified. |
| **⛔ STOP gate** | Design deliverables only. **No migration 031 written. No code. No commit/push. Live DB untouched (read-only audit).** Awaiting user approval of the design before Phase 2.2 implementation. |

**What changed vs the plan in docs 25/26:** the design was narrowed by evidence — `admin_profiles`
(flagged "e.g." in ADR-049) is **deferred (YAGNI)**; the two-tier `owner > admin` hierarchy uses
`users.role` directly; the single new table is `admin_region_assignments`. The audit also uncovered
**6 RLS drift defects** (literal `role='admin'` + a `raw_user_meta_data` identity source) that must be
fixed in migration 031 — see §5.

---

## 2. Evidence Table (live + repo, this session)

Legend: ✅ VERIFIED · 🟡 PARTIALLY VERIFIED · ⚠ NOT VERIFIED · ❌ MISSING · 🏗 PROPOSED

### 2.1 Identity & authorization (D1)

| # | Claim | Status | Evidence |
|---|-------|--------|----------|
| E1 | `users.role` CHECK includes `'admin','owner'` live | ✅ | Live CHECK: `('customer','merchant','driver','admin','owner','provider','delivery')` |
| E2 | `public.is_admin()` (016) = `users.role IN ('admin','owner')` and is the canonical authority | ✅ | Live prosrc: `SELECT EXISTS(... WHERE id = auth.uid() AND role IN ('admin','owner'))`, `search_path=public, pg_temp` |
| E3 | `is_admin()` is the de-facto policy authority across the schema | ✅ | **~28 policies / 13 tables** call `is_admin()`: chat_rooms, chat_messages, complaints, sanctions, location_updates, notifications, notification_tokens, service_bookings, service_categories, service_providers, regions, user_region_preferences, users (see §3.3) |
| E4 | `admin_users` is legacy: separate UUIDs, no `user_id` FK, zero rows, no gate | ✅ | Live: 0 rows; columns `id/full_name/email/role/status/last_login/created_at`; role CHECK `('super_admin','admin','moderator','support','finance')`; only function referencing it = legacy `is_admin(uuid)` (005); **no live policy references it for authz** |
| E5 | 016 canonical vs 005 `admin_users` conflict — resolved in favor of 016 | ✅ (D1 RE-VERIFIED) | ADR-049; live: no gate reads `admin_users`; all modern policies use `is_admin()` |
| E6 | Live admin population | ✅ | `users` = 5 rows (3 customer, 1 provider, **1 owner** `8a23b719-…`, **0 admin**); `admin_users` = 0 |
| E7 | Client admin gate uses `users.role` string | ✅ | `app_router.dart:55` `role == 'admin' || role == 'owner'` (6 literal sites, §4.1) |

### 2.2 RLS drift & integrity (NEW findings)

| # | Finding | Status | Evidence |
|---|---------|--------|----------|
| F1 | **5 policies use literal `users.role = 'admin'` → silently EXCLUDE `owner`** | ✅ VERIFIED (defect) | activity_logs SELECT · platform_settings UPDATE · categories ALL · admin_users SELECT · notification_tokens SELECT "Admins read all tokens" — live quals `users.role = 'admin'::text` |
| F2 | **Third identity source**: service_audio_logs admin policy reads `auth.users.raw_user_meta_data->>'role'` | ✅ VERIFIED (defect) | Live qual: `raw_user_meta_data ->> 'role' = ANY (ARRAY['admin','owner'])` — not `public.users.role`, not `is_admin()` |
| F3 | Duplicate/redundant policies (drift debt, additive, not a security hole) | ✅ VERIFIED | `notifications`: 2× SELECT (is_admin + literal), 3× INSERT (admins + 2× service_role), 2× UPDATE (users), 2× DELETE (users); `notification_tokens`: 2× SELECT + 2× user ALL |
| F4 | `service_audio_logs` "admin all logs r" also duplicates 029's own grants (audit trail) | 🟡 | Policy + role grants both present; harmless |
| F5 | `admin_users` RLS "viewable by admins only" uses literal `role='admin'` (excludes owner) | ✅ | Live qual confirmed |

### 2.3 Client surface (Flutter)

| # | Finding | Status | Evidence |
|---|---------|--------|----------|
| C1 | No shared Dart `is_admin` helper — 6 literal-string gates | ✅ | `app_router.dart:55` · `chat_providers.dart:24` · `service_audio_log_providers.dart:23` · `floating_sidebar_overlay.dart:121,123` · `profile_page.dart:36` |
| C2 | `AdminRole` Dart enum misaligned with SQL CHECK | ✅ | Dart `{superAdmin, admin, moderator, support}` vs SQL `{super_admin, admin, moderator, support, finance}` — `superAdmin`≠`super_admin`, `finance` missing; mapped by `.name` in `admin_repository.dart:562-565` (would silently map `super_admin`→`support`) |
| C3 | `admin_users` CRUD exists in `AdminRepository` (`:549,584,610,637`) + admin_users_page, but table is 0 rows / no gate | ✅ | Read-only effectively; dormant management surface |
| C4 | **`admin_web` (web entrypoint) has NO auth/role gate** | ✅ VERIFIED (security gap) | `lib/main_web.dart:7-27` → `AdminWebShell` rendered unconditionally; pages hit tables directly with anon key (`admin_web/users_page.dart:26`, `admin_verifications_page.dart:27-31` direct `.update()`) |
| C5 | Chat: no `assigned_admin` anywhere (client or SQL) | ✅ | 0 hits repo-wide; admins see all rooms via unfiltered `getAllRooms` (`supabase_chat_data_source.dart:19-25`); client rooms list only the client (`client_support_page.dart:100`) — enforcement is RLS-only |
| C6 | Complaints: `'escalated'` is a UI status string only | ✅ | No `escalated_at`/queue/notify; `admin_complaints_page.dart:84,154,251` |
| C7 | Notifications list is RLS-dependent (no `user_id` filter client-side) | ✅ | `supabase_notification_data_source.dart:45` |
| C8 | Admin broadcast RPC correctly gated by `is_admin()` server-side | ✅ | `019:29-31` SECURITY DEFINER + `is_admin()` guard; call site `admin_push_notifications_page.dart:98-108` reachable only via `/admin` route gate |

### 2.4 Scale, realtime, operations

| # | Item | Status | Evidence |
|---|------|--------|----------|
| S1 | Live scale (rows) | ✅ | chat_rooms=1 · chat_messages=3 · complaints=0 · notifications=0 · notification_tokens=13 · admin_users=0 · users=5 · activity_logs=0 · regions=28 |
| S2 | Realtime publications | ✅ | `supabase_realtime`: chat_rooms, chat_messages, complaints, notifications, sanctions, location_updates, + ride/safety/delivery tables. regions NOT published (correct) |
| S3 | No escalation events table / no region scoping anywhere | ✅ (❌ MISSING by design) | planned 2.2/2.3/2.5 |

---

## 3. Live Policy Surface (full quals captured this session)

### 3.1 `is_admin()`-gated tables (canonical, 13 tables)

`chat_rooms` (select/insert/update/delete), `chat_messages` (4), `complaints` (4), `sanctions` (4),
`location_updates` (select/delete), `notifications` (select/insert/delete), `notification_tokens`
(select), `service_bookings` (ALL), `service_categories` (ALL), `service_providers` (ALL),
`regions` (ALL "regions admin write"), `user_region_preferences` (SELECT "admin select"),
`users` (`users_select_admin`, `users_update_admin`).

### 3.2 Admin-access without `is_admin()` (the F1/F2 drift)

| Table | Policy | Live qual |
|-------|--------|-----------|
| `activity_logs` | "viewable by admins only" | `users.role = 'admin'` |
| `platform_settings` | "Settings updatable by admins" | `users.role = 'admin'` |
| `categories` | "Admins can manage categories" | `users.role = 'admin'` |
| `admin_users` | "viewable by admins only" | `users.role = 'admin'` |
| `notification_tokens` | "Admins read all tokens" | `users.role = 'admin'` |
| `service_audio_logs` | "admin all logs r" | `auth.users.raw_user_meta_data->>'role'` |

### 3.3 Consequences of F1/F2 (why it matters)

- `owner` (the only admin-tier user live today) **cannot** read `activity_logs`, update
  `platform_settings`, manage `categories`, read `admin_users`, or read all `notification_tokens`,
  and **cannot** read `service_audio_logs` unless `raw_user_meta_data.role` happens to be set.
- The Flutter `AdminSettingsPage` (`admin_settings_page.dart:35-43`) reads `platform_settings` — the
  owner currently gets empty/error results there.
- **Fix:** migrate all 6 to `public.is_admin()` in migration 031 (§8).

---

## 4. Design (Phase 2.2 target — pending approval)

### 4.1 Canonical admin identity (D1, re-verified)

**Decision (confirmed):** `users.role IN ('admin','owner')` + `public.is_admin()` (016) remain the
**only** authorization authority. `admin_users` = **dormant legacy metadata** (rule 12.1: keep,
never gate). No new identity table.

Flutter-side: introduce a single shared helper `bool isAdminUser(User u)` (or a `User.isAdmin`
extension) and refactor all 6 literal gates (§4.4). This mirrors SQL `is_admin()`.

### 4.2 Hierarchy model (NEW — ADR-055)

- **Two tiers, derived from `users.role`:** `owner` (rank 100) > `admin` (rank 90). Flat today; no
  `users` table change, no new role values.
- **Global vs region-scoped:** an `admin` **with no `admin_region_assignments` rows = global scope**
  (sees everything, like owner). With rows = scoped to those regions **and their descendants**
  (reuses the 2.1 hierarchy).
- **Escalation parent walk (2.5 contract):** scoped admin → regional parent admin → nearest ancestor
  admin → global admin/owner. Global cannot escalate above itself.
- **`admin_profiles` DEFERRED (YAGNI):** with 0 admins live and owner→admin the only tier, a
  per-admin profile table adds no capability. Revisit in 2.5 if granular permission levels become
  real requirements (the Dart `AdminPermission`/`PermissionLevel` enums are aspirational today).

### 4.3 Permission model

- **2.2 keeps parity:** `is_admin()` grants the same surface to admin and owner (unchanged from
  today). **No per-action permission split in 2.2.**
- Region scoping is the only differentiation: `is_admin_for_region(region_id)` (new SECURITY
  DEFINER helper, 016 pattern) = `is_admin()` AND (owner OR assignment-covers-region-or-ancestor).
- Server-side remains authoritative; router/providers only control UI visibility (unchanged).

### 4.4 Flutter changes (design, not yet implemented)

1. **Shared helper:** `lib/core/auth/admin_access.dart` (or extension on `User`) — single source for
   `isAdmin`; refactor the 6 sites (`app_router.dart:55`, `chat_providers.dart:24`,
   `service_audio_log_providers.dart:23`, `floating_sidebar_overlay.dart:121,123`,
   `profile_page.dart:36`).
2. **`admin_web` auth gate (security fix, HIGH):** wrap `AdminWebShell` in an auth+`isAdmin` gate
   (`main_web.dart`); route to login/home otherwise. Server RLS still protects data; this closes the
   UI exposure.
3. **`AdminRole` alignment:** reconcile Dart enum with SQL CHECK (`super_admin` vs `superAdmin`,
   add `finance`) — or explicitly classify `admin_users` as dormant and remove its CRUD UI. **User
   decision (see Gate question).**
4. **Admin region scoping UI (2.3-ready):** `AdminRegionAssignment` management surface + region
   filter on admin complaint/chat lists (additive).
5. `AdminRepository.admin_users` CRUD: leave untouched until (3) resolves (dormant, non-breaking).

### 4.5 Schema — migration `031_admin_hierarchy_region_assignments.sql` (spec, NOT written)

```sql
-- 1) Connect, not fork (per ADR-049 §migration-impact): link legacy metadata to canonical identity.
ALTER TABLE public.admin_users
  ADD COLUMN user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  ADD CONSTRAINT admin_users_user_id_key UNIQUE (user_id);

-- 2) Region scope for admins (owner = implicit global, no rows needed).
CREATE TABLE public.admin_region_assignments (
  admin_id   uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  region_id  uuid NOT NULL REFERENCES public.regions(id) ON DELETE CASCADE,
  scope      text NOT NULL DEFAULT 'descendants'
             CHECK (scope IN ('self','descendants')),
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES public.users(id),
  PRIMARY KEY (admin_id, region_id)
);

-- 3) SECURITY DEFINER helper (016 pattern: search_path + REVOKE + GRANT).
CREATE OR REPLACE FUNCTION public.is_admin_for_region(p_region_id uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public, pg_temp AS $$
  SELECT public.is_admin()
    AND (EXISTS (SELECT 1 FROM public.users
                  WHERE id = auth.uid() AND role = 'owner')
      OR  EXISTS (SELECT 1 FROM public.admin_region_assignments a
                  WHERE a.admin_id = auth.uid()
                    AND (a.scope = 'self' AND a.region_id = p_region_id
                      OR a.scope = 'descendants'
                         AND p_region_id IN (SELECT r.id FROM public.regions r
                                             WHERE r.parent_region_id = a.region_id))));
$$;
```

RLS + grants (revoke-before-grant, per the 030 lesson):
- `admin_region_assignments` RLS: all 4 ops `USING is_admin() WITH CHECK is_admin()`; anon revoked;
  `authenticated` DML via RLS.
- Fix F1/F2: rewrite the 6 drifted policies to `is_admin()`; drop duplicate policies on
  `notifications` / `notification_tokens` (keep `is_admin()` variants).
- Indexes: `admin_region_assignments(region_id)`, `(admin_id)` (PK covers). Realtime: **not** published.

> Note: the descendant check uses the `regions.parent_region_id` self-FK from 030 — this works for
> the governorate→… hierarchy. If Phase 2.3 routing needs recursive ancestor walks for arbitrary
> depth, use a recursive CTE helper instead (documented then, not now — evidence-first).

---

## 5. Phase 2.3 Contract (what the next gate must design/implement)

Resolves **D3 (chat backend)** and routes on the 2.2 admin model. From docs 25/26 §8 sequence:
`031_admin_hierarchy_region_assignments` → `032_support_conversations_priority`.

| Item | Contract |
|------|----------|
| **D3 decision** | **EXTEND `chat_rooms`** (additive) — never replace the 016 RLS/`participant_ids` model. |
| New columns (032) | `priority text CHECK('low','medium','high','urgent') DEFAULT 'low'` · `region_id uuid FK regions(id)` · `assigned_admin_id uuid FK users(id)` · `status text CHECK('open','assigned','escalated','closed') DEFAULT 'open'` · `escalated_at timestamptz` · `escalated_from_admin_id uuid FK users(id)` |
| RPCs (016 pattern) | `assign_support_chat(p_room_id, p_admin_id)` · `escalate_support_chat(p_room_id, p_reason)` — SECURITY DEFINER, `is_admin()` guarded, server-validated |
| Routing algorithm (server-side) | customer `user_region_preferences` → `admin_region_assignments` → parent walk → global → owner. Customers never choose admins and cannot set priority |
| Realtime | chat_rooms/chat_messages already in `supabase_realtime` — reuse; add `chat_rooms` row update broadcasts for assignment/escalation |
| Notifications (034) | conversation deep-links `/admin/support-chat/room/:roomId`; escalation/assignment push via existing `notifications` + `admin_broadcast_notification` pattern |
| Flutter (2.3) | realtime subscription on rooms; priority/emergency UI; admin assignment/escalation actions in `admin_support_chat_page.dart`; region filter |
| Escalation engine (2.5) | `escalation_events` table + engine RPCs; complaints `escalated` status wired to real assignment (not just a string) |

---

## 6. Migration Strategy (031 — apply pattern)

1. **Pre-apply gate (in the 2.2 implementation session):** `flutter analyze` + `flutter test` green;
   live read-only confirm baseline (this doc §2).
2. **Write 031** with the 016 pattern for the new function + revoke-before-grant (030 lesson: Supabase
   `ALTER DEFAULT PRIVILEGES` auto-grants ALL to anon — must be revoked on the new table).
3. **Apply** via Management API `bttnlkmwhorjamzemwda`; **verify live** (schema + ACL + functional RLS
   probes incl. owner-vs-admin-vs-anon, region-scope matrix) before touching Flutter.
4. **Flutter** changes per §4.4 (shared helper refactor first — pure refactor, run gate; then the
   admin_web gate + region UI).
5. Gate: `flutter pub get && flutter analyze && flutter test`; commit `sprint N: ...`; push.

---

## 7. Test Plan (Phase 2.2)

- **Unit (Dart):** `isAdminUser` helper across all 6 call sites; `AdminRole` mapping alignment.
- **RLS integration (SQL probes live):** owner full-surface (incl. previously-drifted tables) ·
  global admin full-surface · scoped admin sees own region + descendants only · scoped admin blocked
  on other regions · anon blocked everywhere on `admin_region_assignments` · `is_admin_for_region`
  matrix (owner=all, global admin=all, scoped=self/descendant/outside, non-admin=blocked).
- **Dart integration:** admin_web gate (unauthenticated → login, non-admin → blocked);
  `AdminRepository` region assignment CRUD.
- **Regression:** 663/663 existing tests stay green; regions tests untouched.

---

## 8. Roadmap (updates ROADMAP.md, rule 4)

| Phase | Scope | Status |
|-------|-------|--------|
| 2.0 | Architecture audit | ✅ (doc 25) |
| 2.1 | Regions (030) | ✅ shipped `1f3ba02`, live-verified (doc 27) |
| **2.2** | **Admin hierarchy + region authz + RLS standardization (031)** | 🏗 **DESIGNED — this gate; awaiting approval** |
| 2.3 | Chat priority/region/assignment backend (032) + realtime | 🏗 contract (§5) |
| 2.4 | Notifications: admin send path + conversation deep-links (034) | 🏗 pending |
| 2.5 | Escalation engine (`escalation_events` + RPCs) | 🏗 pending |
| 2.6 | Realtime hardening | 🏗 pending |
| 2.7 | Security hardening pass (029 RPC search_path audit, 016 pattern) | 🏗 pending |

---

## 9. Risk Register

| # | Risk | Sev | Mitigation |
|---|------|-----|-----------|
| R1 | `admin_users` duality persists (two role vocabularies) | Med | Classified dormant; ADR-055; AdminRole alignment = user decision (Gate Q1) |
| R2 | F1 literal-`role='admin'` policies already exclude owner on 6 tables | **High** | Fixed in 031 (rewrite to `is_admin()`); owner currently affected live |
| R3 | `admin_web` unauthenticated UI (anon key) | **High** | Client gate in 2.2; server RLS remains the safety net |
| R4 | Duplicate policies (notifications/notification_tokens) | Low | Deduped in 031; additive-only, no revocation of coverage |
| R5 | `raw_user_meta_data` identity source out-of-sync with `users.role` | Med | F2 fixed in 031; single source = `is_admin()` |
| R6 | Escalation/priority client manipulation | Med | Server-side RPCs only (2.3); customers can't set priority |
| R7 | New table default-privilege leak (TRUNCATE to anon) | High | Revoke-before-grant in 031 (030 lesson) |

---

## 10. Deliverables produced this gate

- **This doc** (audit + design + contract + migration strategy + test plan + roadmap + risks).
- `docs/DECISION_LOG.md`: **ADR-055** (admin hierarchy model) + **ADR-056** (RLS standardization on
  `is_admin()` — F1/F2 fixes). D1 itself already resolved (ADR-049), re-verified here live.
- `SESSION_STATUS.md`, `ROADMAP.md` updated.
- **NOT produced** (by design): migration 031, product code, tests, commit/push. Live DB read-only.

## 11. Gate Questions for the user

1. **AdminRole / `admin_users` disposition** (ADR-055): (a) align Dart enum + keep dormant CRUD UI,
   or (b) remove the `admin_users` management surface from Flutter entirely (SQL table stays,
   dormant) — recommended (a) for 2.2, revisit in 2.5.
2. **Approve Phase 2.2 implementation** on this design (migration 031 + shared `isAdminUser` helper
   + admin_web gate + region-scope UI), then a fresh gate before commit.
3. Confirm **owner remains the only admin-tier account** and no additional admins should be seeded in 031.

---

## 12. Source of Truth

- Live evidence: Management API queries on `bttnlkmwhorjamzemwda` (PAT `~/.supabase/access-token`,
  never committed). All claims in §2/§3 captured this session.
- Repo: `supabase/migrations/001,002,005,016,019,020,028,029,030`; `docs/HANDOFF/25,26,27`;
  `lib/core/router/app_router.dart`, `lib/features/{admin,admin_web,support_chat,complaints,notifications,regions}`,
  `lib/data/repositories/admin_repository.dart`, `lib/main_web.dart`.
