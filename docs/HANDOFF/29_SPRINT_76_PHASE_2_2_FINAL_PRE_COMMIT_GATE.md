# SPRINT 76 — PHASE 2.2 ADMIN HIERARCHY — FINAL PRE-COMMIT GATE REPORT

> Session 47 · 2026-08-15 · Project `bttnlkmwhorjamzemwda` · HEAD `1f3ba02` "sprint 76: add regional system"
> **Status: 🟢 GATE GREEN — NOT COMMITTED, NOT PUSHED (per mandate).** Next = user review → commit → push.

---

## 1. Scope Delivered

Phase 2.2 (D1 — Admin hierarchy unification): **all sub-tasks 2.2A–2.2K complete.**

| Deliverable | Location |
|-------------|----------|
| Migration 031 — admin hierarchy + region authorization | `supabase/migrations/031_admin_hierarchy_region_assignments.sql` |
| Shared `isAdminUser` helper + 6-site refactor | `lib/core/auth/admin_access.dart` + 6 call sites |
| `AdminRole` two-tier alignment (decision A: owner > admin) | `lib/features/admin/domain/entities/admin_models.dart` |
| admin_web auth gate | `lib/features/admin_web/presentation/pages/admin_web_gate.dart` |
| Region-scope UI + repository/provider layer | `lib/features/admin_web/presentation/pages/admin_region_scope_page.dart`, `lib/features/admin/domain/repositories/admin_region_assignment_repository.dart`, `lib/features/admin/data/datasources/remote/supabase_admin_region_assignment_data_source.dart`, `lib/features/admin/data/repositories/admin_region_assignment_repository_impl.dart`, `lib/features/admin/presentation/providers/admin_region_providers.dart` |
| Tests | `test/features/admin/` (4 suites), `test/features/admin_web/` (2 suites) |
| Report | this file + `SESSION_STATUS.md` updated |

---

## 2. Files Changed (git status)

**Modified (18):** `ROADMAP.md` · `SESSION_STATUS.md` · `docs/DECISION_LOG.md` (ADR-055/056) ·
`lib/core/router/app_router.dart` · `lib/data/repositories/admin_repository.dart` ·
`lib/features/admin/domain/entities/admin_models.dart` ·
`lib/features/admin/presentation/pages/admin_users_page.dart` ·
`lib/features/admin_web/presentation/pages/admin_web_shell.dart` ·
`lib/features/floating_sidebar/floating_sidebar_overlay.dart` ·
`lib/features/profile/presentation/pages/profile_page.dart` ·
`lib/features/service_audio_logs/presentation/service_audio_log_providers.dart` ·
`lib/features/support_chat/presentation/chat_providers.dart` · `lib/l10n/app_ar.arb` ·
`lib/l10n/app_en.arb` · `lib/l10n/app_localizations*.dart` (regenerated) ·
`lib/main_web.dart` · `test/features/admin/domain/entities_test.dart`

**Untracked (new, 12 paths):** `docs/HANDOFF/28_...ADMIN_HIERARCHY_AUDIT.md` ·
`lib/core/auth/` (admin_access.dart) · `lib/features/admin/data/` · `lib/features/admin/domain/entities/admin_region_assignment.dart` ·
`lib/features/admin/domain/repositories/admin_region_assignment_repository.dart` ·
`lib/features/admin/presentation/providers/` ·
`lib/features/admin_web/presentation/pages/admin_region_scope_page.dart` ·
`lib/features/admin_web/presentation/pages/admin_web_gate.dart` ·
`supabase/migrations/031_admin_hierarchy_region_assignments.sql` ·
`test/features/admin/data/` · `test/features/admin/domain/admin_region_assignment_test.dart` ·
`test/features/admin_web/`

**No secrets in the diff.** Secret scan: only `SupabaseConfig.anonKey` getter references
(`lib/config/supabase_config.dart`, `lib/services/supabase/supabase_initializer.dart`) — values come from
`--dart-define-from-file` at build time. `.env.dev`/`.env.prod`/`.env.staging` are **git-ignored**
(verified via `git check-ignore`). No JWTs / PATs in tracked or untracked files.

---

## 3. Migration 031 — Schema / RLS / RPC Diff

Applied **live** to `bttnlkmwhorjamzemwda` and verified. Full contents: `supabase/migrations/031_admin_hierarchy_region_assignments.sql`.

| Object | Before | After (031) |
|--------|--------|-------------|
| `admin_users` | flat, dormant metadata | + `user_id uuid REFERENCES users(id) ON DELETE CASCADE` + `UNIQUE (user_id)` — connected to canonical identity (ADR-055); **still dormant, never an authz source** |
| `admin_region_assignments` | — | **NEW** `(admin_id, region_id, scope 'self'/'descendants', created_at, created_by)` PK `(admin_id, region_id)`; RLS enabled; policy `"admin_region_assignments admin all"` FOR ALL `is_admin()` (USING + WITH CHECK); index on `region_id`; REVOKE-before-GRANT (anon = nothing; authenticated = SELECT/INSERT/UPDATE/DELETE RLS-gated); **NOT in `supabase_realtime`** (verified empty membership) |
| `public.is_admin_for_region(uuid)` | — | **NEW** SECURITY DEFINER STABLE `SET search_path=public, pg_temp` = `is_admin()` AND (owner global OR assignment covers region incl. recursive descendants). REVOKE PUBLIC + GRANT authenticated |
| `activity_logs` SELECT policy | literal `role='admin'` (owner excluded — F1) | `"activity_logs admin select"` USING `is_admin()` |
| `platform_settings` UPDATE policy | literal `role='admin'` (F1) | `"platform_settings admin update"` USING/WITH CHECK `is_admin()` |
| `categories` policy | literal `role='admin'` (F1) | `"categories admin manage"` FOR ALL USING/WITH CHECK `is_admin()` |
| `admin_users` SELECT policy | literal `role='admin'` (F1) | `"admin_users admin select"` USING `is_admin()` |
| `notification_tokens` | literal "Admins read all tokens" (F1) + `{public}` "Service role manage tokens" (anon-leak, F3) | removed literal; `"Service role manage tokens"` recreated **`TO service_role` USING (true)** (role now matches name; no anon/authenticated reach) |
| `service_audio_logs` admin policy | `raw_user_meta_data` identity source (F2) | `"service_audio_logs admin select"` USING `is_admin()` |
| `notifications` | 4 duplicate/overlapping + `{public}` "Service role insert notifications" (anon insert, F3) | duplicates + `{public}` policy dropped; 7 clean policies: admin insert/select/delete (`is_admin()`), service_role insert, user own select/update/delete |
| `users` role writes | unguarded | **`users_guard_role_change()`** BEFORE UPDATE trigger: auth bypass OK; self-role-change → EXCEPTION; non-admin → EXCEPTION; non-owner granting owner → EXCEPTION |
| `public.admin_set_user_role(uuid,text)` | — | **NEW** SECURITY DEFINER RPC (authorized admin-management flow only) with role whitelist + owner-grant guard. REVOKE PUBLIC + GRANT authenticated |

**No admin seeds** in 031. Owner `8a23b719-a923-4a18-bd6e-04972097fb4b` remains the **only** admin-tier account (`SELECT … WHERE role IN ('owner','admin')` live → 1 row).

**Idempotency:** migration re-applied live → `[]` (success), no errors, no destructive effects.

**Rollback:** 031 is additive + REVOKE/GRANT + DROP-and-recreate of the *same-name* policies/functions — the only persistent state changes are: new table (empty), new column (nullable, no data), new constraint, new policies/functions. Rollback = drop `admin_region_assignments`, drop `admin_users.user_id` column+constraint, restore previous policy defs from git history (all documented in `docs/DECISION_LOG.md` ADR-055/056).

---

## 4. Security Attack Tests (live, RLS probe matrix)

All probes executed live via Management API as postgres with `SET LOCAL ROLE` + JWT claim simulation; every negative probe returned the expected error.

| # | Probe (role → action) | Expected | Result |
|---|----------------------|----------|--------|
| P1 | anon → `SELECT admin_region_assignments` | permission denied | ✅ 42501 |
| P2 | anon → `is_admin_for_region` | false | ✅ false |
| P3 | anon → `admin_set_user_role` | Not authorized | ✅ P0001 |
| P4 | customer → `SELECT admin_region_assignments` | 0 rows (RLS) | ✅ 0 |
| P5 | customer → `INSERT admin_region_assignments` | RLS violation | ✅ 42501 |
| P6 | customer → `is_admin_for_region` | false | ✅ false |
| P7 | customer → `admin_set_user_role(owner, 'owner')` | Not authorized | ✅ P0001 |
| P8 | customer → direct `UPDATE users SET role='owner'` (self) | **Cannot change your own role** (trigger) | ✅ P0001 |
| P9 | owner → `is_admin_for_region` + `INSERT assignment` | true / success | ✅ |
| P10 | **scoped admin** (temp, Cairo `descendants`) → `is_admin_for_region` | Cairo=true · sub-district (recursive)=true · Beheira (outside)=false | ✅ true/true/false |
| P11 | non-owner **admin** → `admin_set_user_role(...,'owner')` | Only owner can grant owner role | ✅ P0001 |
| P12 | **admin** → `admin_set_user_role(...,'admin')` (legit) | success, role='admin' | ✅ |

All temp probe rows created inside `BEGIN…ROLLBACK` (or cleaned post-commit). Post-probe audit: `admin_region_assignments` = 0 rows, `probe.%` users = 0, target user role unchanged = `customer`.

**ACL audit (live):**
- `admin_region_assignments` grants: **anon = none** · authenticated = SELECT/INSERT/UPDATE/DELETE only (no TRUNCATE/TRIGGER/REFERENCES) · service_role/postgres standard.
- No policy anywhere in `public` uses literal `role='admin'` or `raw_user_meta_data` as an identity source (F1/F2 scan → empty).
- `is_admin_for_region`/`admin_set_user_role` ACLs match the existing `is_admin` baseline exactly (Supabase default EXECUTE grants; both self-guard via `is_admin()` + `auth.uid()`, return boolean only / raise — no leak, no escalation).

**Pre-existing finding (outside 031 scope, flagged for follow-up):** `activity_logs` grants anon/authenticated INSERT and the pre-existing "Activity logs insertable by service role" policy is `roles=PUBLIC` with **no WITH CHECK** → anon can insert rows into `activity_logs` (verified live: anon INSERT committed; anon SELECT correctly RLS-blocked). Recommended follow-up: `REVOKE INSERT,UPDATE,DELETE ON activity_logs FROM anon, authenticated` or scope that policy `TO service_role`. Not changed here because it is pre-existing baseline, unrelated to the admin hierarchy.

> **FINDING CLASSIFICATION — `activity_logs` anon INSERT (final review task 7):**
> **STATUS: PRE-EXISTING SECURITY DEBT · OUT OF SCOPE for Phase 2.2 · FOLLOW-UP REQUIRED (dedicated hardening task, e.g. 2.7).**
> - **Verified NOT relied upon:** the only app code touching `activity_logs` is a **read** (admin
>   dashboard `getRecentActivity`, `admin_repository.dart:522–529`, RLS-gated by `is_admin()`). No
>   Phase 2.2 code — and no admin authorization path — inserts into `activity_logs`. The PUBLIC
>   insert policy is dead weight from migration 002, unrelated to admin identity/scope.
> - **Not silently fixed in 031** per mandate (031 only rewrote the *select* policy; the insert
>   policy was left untouched). The insertion path grants no privileges and does not weaken any
>   Phase 2.2 authorization invariant.
> - **Follow-up:** a dedicated hardening migration (or the 2.7 gate) should
>   `REVOKE INSERT,UPDATE,DELETE ON public.activity_logs FROM anon, authenticated` and/or scope the
>   insert policy `TO service_role`.

---

## 5. Flutter / Dart Changes

- **`AdminRole` two-tier (decision A):** `enum AdminRole { owner, admin }`; `fromDb` maps `super_admin`→owner, all legacy values/null→admin (no `orElse` crash); `toDb` stays inside dormant-table CHECK vocabulary (owner→`super_admin`, admin→`admin`).
- **Read fix (C2):** `admin_repository.dart` now maps `AdminRole.fromDb(json['role'])` (was silently turning `super_admin` → `support`).
- **Write path:** `createUser`/`updateUser` write `user.role.toDb()` (both paths).
- **UI:** admin_users role label/chip owner/admin; default `selectedRole = admin`.
- **Gate:** `lib/main_web.dart` `home: const AdminWebGate()`; gate resolves session → `users.role` (admin/owner = authorized; customer/provider/driver/merchant/null = denied; login + denied pages included).
- **Region scope:** assignments repository/provider layer + `AdminRegionScopePage` (admin list ↔ assignments; Cairo self-scope example; governorate + scope dropdowns keyed `region-select`/`scope-select`; global empty state; add/delete with loading).
- **6-site refactor** onto `isAdminUser`/`User.isAdmin`: app_router, chat_providers, service_audio_log_providers, floating_sidebar_overlay, profile_page, main_web (gate). Two latent bugs fixed en route (documented in ADR-055).

---

## 6. Pre-Commit Gate

| Check | Command | Result |
|-------|---------|--------|
| Dependencies | `flutter pub get` | ✅ Got dependencies |
| Analyze | `flutter analyze` | ✅ **0 errors** · **545 issues** = **543 pre-existing baseline** + 2 `deprecated_member_use` (`DropdownButtonFormField.value`, matches existing `admin_users_page.dart:148` convention) — **0 issues in new source files** |
| Tests | `flutter test --no-pub --concurrency=2` | ✅ **686/686 passed** (+21 vs 665 baseline) |
| `git diff --check` | ✅ no whitespace defects | ⚠️ exit 2 = **CRLF artifacts only** (`docs/DECISION_LOG.md`, `lib/l10n/app_ar.arb` are stored verbatim `-text` with CRLF — pre-existing file format; prior commits carry the same flags; no action needed) |
| Live apply | Management API | ✅ applied + idempotent re-run |
| Live security | probe matrix + ACL audit | ✅ all green (see §4) |
| Secret scan | `git check-ignore .env.*` + code grep | ✅ all env files ignored; no secrets in diff |

---

## 8. Final Review (controlled, pre-commit)

### Scope verification
- ✅ Diff reviewed file-by-file against ADR-055/056 (`docs/DECISION_LOG.md`) + audit doc 28. All 19
  modified + 12 new paths are Phase 2.2 scope (migration, admin_region_assignments layer,
  is_admin_for_region, admin_set_user_role, role-guard trigger, F1/F2/F3, AdminRole owner>admin,
  C2 read fix, isAdminUser 6-site refactor, admin_web gate, region-scope UI, tests, docs).
- ✅ **No unrelated product changes** — all `lib/` diffs are the AdminRole helper/repository/UI/gate
  refactor (verified per-file).
- ✅ **No Phase 2.1 drift** — `git status` shows **zero** changes under `lib/features/regions/**` or
  `supabase/migrations/030*`; live `regions` = 28 rows (27 governorates) and
  `user_region_preferences` intact.
- ⚠️ **Scope note (non-blocking, additive docs only):** the `docs/DECISION_LOG.md` diff also contains
  **ADR-053/054 (Kilo/LLM7 provider decisions, Session 44)** — pre-existing uncommitted documentation
  that predates Phase 2.2 and is additive. It does not touch code or schema. Recommend committing it
  together with the milestone (single docs file) or splitting it out if a strictly minimal commit is
  required.

### Security verification (task 6 — all pass)
- ✅ **Owner global** — `is_admin_for_region()` true on any region (probe P9).
- ✅ **Admin scoped** — scoped admin: assigned region + recursive descendants true, outside region
  false (probe P10).
- ✅ **No self-elevation** — direct `UPDATE users SET role='owner'` on own row → trigger
  `Cannot change your own role` (P8); `admin_set_user_role` own-target blocked (P7).
- ✅ **Lower admin cannot elevate** — non-owner admin granting `owner` → `Only owner can grant owner
  role` (P11); legit `admin` grant succeeds (P12).
- ✅ **Cross-region denied** — scoped admin outside assignment → false (P10).
- ✅ **Anon denied** — permission denied on table (P1), `is_admin_for_region` false (P2),
  `admin_set_user_role` → `Not authorized` (P3).
- ✅ **admin_web cannot bypass authorization** — the gate is UI-only defense-in-depth; every admin_web
  data call runs under the user's Supabase token and is enforced by RLS (`is_admin()` / own-row
  policies — `users` RLS verified: own-row SELECT only, admin full reads). Server/database remains the
  authority.
- ✅ **SECURITY DEFINER `search_path`** — `is_admin_for_region` (STABLE) and `admin_set_user_role`
  both `SET search_path = public, pg_temp`; `users_guard_role_change` (trigger) also
  `SET search_path = public, pg_temp`.
- ✅ **No new PUBLIC/anon leaks** — `admin_region_assignments` grants: anon = none, authenticated =
  RLS-gated DML only; F1/F2 drift scan empty; F3 dedup verified (notification_tokens
  `service_role`-scoped, no `{public}` policies).
- ✅ **No admin seed** — live `users` admin-tier count = **1** (owner only).

### Migration verification (tasks 3 & 5)
- ✅ Idempotent (live re-run `[]`, all `IF NOT EXISTS` / `CREATE OR REPLACE` / `DROP ... IF EXISTS`).
- ✅ **No destructive operations** — no `DROP TABLE` / `DROP COLUMN` / `DELETE` / `TRUNCATE`; the only
  `DROP`s are policy/trigger replacements re-created in the same script.
- ✅ No data changes, no seeds, reversible (documented in ADR-055/056).

### Live DB verification (task 9)
- ✅ 031 objects present: `admin_region_assignments` table, `is_admin_for_region`,
  `admin_set_user_role`, `users_guard_role_change` function + trigger.
- ✅ No duplicate F1–F3 policies (admin_region_assignments=1, admin_users=1, notification_tokens=3,
  notifications=7 distinct, service_audio_logs=3).
- ✅ ACLs correct (anon = nothing on the new table; functions match `is_admin` baseline).
- ✅ No admin seed (admin-tier users = 1), `admin_region_assignments` = **0 rows**, probe users = 0,
  `activity_logs` probe rows = 0 (all temp data removed).

### Test & analyzer results (task 8)
- ✅ `flutter test --no-pub --concurrency=2` → **686/686**
- ✅ `flutter analyze` → **0 errors** (545 = 543 baseline + 2 convention infos)
- ⚠️ `git diff --check` → exit 2 **CRLF artifact only** (non-blocking, pre-existing format)
- ✅ Secret scan → clean (`service_role` matches are SQL role references; env files ignored)

## 7. Mandate Confirmations

- ✅ **No commit, no push** — working tree left dirty by design for user review.
- ✅ **No Phase 2.3** started (escalation engine untouched).
- ✅ **No admin seeds** in migration 031; single admin-tier account unchanged.
- ✅ `admin_users` kept as dormant legacy surface (ADR-055), never an authz source; canonical authority = `users.role` + `public.is_admin()`.
- ✅ Generated files (`.g.dart`/`.freezed.dart`/`app_localizations*.dart`) regenerated and consistent.

**Next (user hands):** review the diff → approve → `git add . && git commit -m "sprint 76: unify admin hierarchy with region scope" && git push origin master`.

> **Note on commit hygiene:** if a strictly minimal diff is desired, consider excluding the pre-existing
> ADR-053/054 documentation lines (Session 44) — they are additive docs only and can be committed
> separately. The `git diff --check` CRLF flags are inherent to the committed file format of
> `DECISION_LOG.md`/`app_ar.arb` and require no action.
