# SPRINT 98 — Modern Admin Management Center (Audit)

> Evidence-based audit performed against the actual SQL migrations and Flutter
> source. Every signature below was read from `supabase/migrations/*.sql`, not
> inferred. No missing columns or function behaviour were guessed.

## 1. Actual Schema (canonical identity = `users.id`)

| Table | Key columns (evidence) | Notes |
|---|---|---|
| `users` | `id uuid PK`, `email`, `full_name`, `role` (`owner`/`admin`/...), `created_at`, `user_type` | Canonical identity. **No `last_login` column exists.** |
| `admin_management` | `admin_id uuid FK users(id) ON DELETE CASCADE`, `supervisor_id uuid FK users(id)`, `is_active bool DEFAULT true`, `created_by`, `created_at`, `updated_at` | Supervision tree. `admin_id <> supervisor_id` CHECK. Depth derived via recursive CTE, never stored. |
| `admin_region_assignments` | `admin_id`, `region_id`, `scope` (`self`/`descendants`), `created_by` | A region can be assigned multiple times per admin (PK = (admin_id, region_id)). |
| `admin_permission_grants` | `admin_id`, `permission text`, `granted_by`, `granted_at` | Explicit deviations only; defaults computed by `has_permission()`. |
| `approval_requests` | (existing) | Admin create/role/region/supervisor/deactivate types exist. |
| `activity_logs` | `id uuid`, `user_id text`, `action text`, `resource text`, `resource_id text`, `details jsonb`, `timestamp timestamptz` | The ONLY admin-scoped audit source. RLS: admins only (service_role insert). |
| `member_events` | `user_id`, `event_type`, `title`, `payload` | **Member-scoped** — NOT used for admin history. |

`admin_users` table: **DORMANT**. `016:14` (separate generated UUID, not `users.id`),
`031:7-9`/ADR-055 (`user_id` FK added, "legacy metadata stays dormant; never an
authz source"), `031:141` (dormant, SELECT-only RLS). Not touched by this sprint.

## 2. Actual RPC Signatures

### Lifecycle (034, SECURITY DEFINER, auth.uid() = caller)
- `create_admin_account(p_user_id uuid, p_supervisor_id uuid, p_region_id uuid, p_scope text)` → promotes an **existing `users.id`** only.
- `assign_admin_role(p_admin_id uuid, p_new_role text, p_reason text)` → uuid overload (full role vocab).
- `assign_admin_region(p_admin_id uuid, p_region_id uuid, p_scope text)` → uuid overload (region **by id**).
- `change_admin_supervisor(p_admin_id uuid, p_new_supervisor_id uuid, p_reason text)`.
- `deactivate_admin(p_admin_id uuid, p_reason text)`.
- `grant_admin_permission(p_admin_id uuid, p_permission text)`.
- `revoke_admin_permission(p_admin_id uuid, p_permission text)`.

### Email overloads (057) — IMPORTANT CONTRACT NUANCES
- `assign_admin_role(p_email text, p_role text, p_reason text)` — role restricted to
  `('admin','country_admin','governorate_admin','center_admin','village_admin')`;
  the `*_admin` roles map to DB `'admin'`. `owner`/`customer` → "Invalid role".
- `assign_admin_region(p_email text, p_region text, p_scope text)` — `p_region` is
  resolved **by region NAME** (`name_ar`/`name_en` ILIKE), **NOT by id**.

**Decision:** the Flutter UI uses the id-based **uuid overloads** (034) because the
UI needs the full role vocabulary (`owner`) and region selection by id. The email
overloads are retained for other surfaces but are not used by the new center.

### Read RPCs (this sprint extended)
- `get_all_admins()` — **extended** (backward compatible) to also return
  `id, full_name, region_id, scope, supervisor_id` (kept: email, role, region_name,
  is_active, supervisor_email, created_at).
- `get_admin_profile(p_email)` — **extended** to also return
  `id, full_name, is_active, region_id, supervisor_id, supervisor_email` (kept:
  email, role, is_owner, region_name, total_earnings).
- `get_admin_permissions(p_admin_id uuid)` — **new**. Returns `{authorized, grants[], effective[]}`.
- `get_admin_audit_history(p_admin_id uuid)` — **new**. Scoped `activity_logs` rows.
- `reactivate_admin(p_admin_id uuid, p_reason text)` — **new** (inverse of deactivate).

## 3. Authorization Model
- `has_permission(p_permission, p_region_id, p_target_admin_id)` — central engine.
  Owner = global; else active-admin + default matrix + explicit grants; region gate
  when `p_region_id` set; target-admin gate (`is_supervisor_of`) for `ADMIN_*` actions.
- `is_supervisor_of(p_supervisor, p_subordinate)` — owner OR recursive chain; excludes self.
- `_is_owner_uid`, `_is_active_admin_uid`, `_region_in_scope` — helpers.
- Grant rules (`grant_admin_permission`): no self-grant; grantor must hold the
  permission (or be owner); target must be active admin under grantor's branch.
- All new RPCs enforce: owner OR target-self OR `is_supervisor_of(actor, target)`;
  region containment where relevant.

## 4. Hierarchy Model
- `admin_management` supervision tree. Owner = implicit root (no row).
- Invariants in executors: no self-parent, no cycles (`is_supervisor_of(new_supervisor, target)` rejected), region containment of new supervisor, no escal/self-grant.

## 5. Region Model
- `admin_region_assignments` + `scope` (`self`/`descendants`).
- `_region_in_scope`: owner = all; admin with **no** assignments = global = all;
  otherwise must cover region via self/descendants recursive walk.

## 6. Permission Model
- Vocabulary in `_valid_permission` (24 codes).
- `admin_permission_grants` stores deviations; `has_permission` computes effective set.
- `get_admin_permissions` returns explicit `grants` + computed `effective` (owner = all; active admin = default matrix + grants; inactive = grants only).

## 7. Audit Model
- `write_audit(action, resource, resource_id, details)` → `activity_logs`.
- Admin lifecycle executors already write `ADMIN_CREATED`, `ADMIN_ROLE_CHANGED`,
  `ADMIN_REGION_CHANGED`, `ADMIN_SUPERVISOR_CHANGED`, `ADMIN_DEACTIVATED`,
  `ADMIN_PERMISSION_GRANTED/REVOKED`.
- `get_admin_audit_history` reads `activity_logs` filtered to the target admin
  (resource_id = target, or user_id = target). **No new audit system created.**

## 8. Legacy `admin_users` Dependency Map
- **SQL**: table defined in 001/002, hardened in 005, FK added in 016/031. DORMANT.
- **Dart (DEAD CODE, no UI consumer)**:
  - `lib/data/repositories/admin_repository.dart:547-634` — `getUsers/createUser/updateUser/deleteUser` (hit `admin_users`).
  - `lib/services/admin/admin_service.dart:36-77` — wrappers.
  - `lib/services/admin/admin_providers.dart:35` — `adminUsersProvider` (no remaining UI reference).
  - `lib/features/admin/domain/repositories/admin_repository.dart:16-19` — interface declarations.
- **Test**: `test/features/admin/domain/entities_test.dart:23` references the legacy
  `AdminRole` CHECK vocabulary (unrelated to the table; kept).
- **Verdict**: ZERO active Admin Management UI dependency on `admin_users`. The
  table and dead Dart code remain DORMANT pending a future dedicated cleanup
  migration (per AGENTS rule 12.1 / SPRINT 98 PHASE 9).

## 9. Missing Backend Contracts (resolved this sprint)
| Gap | Resolution |
|---|---|
| `get_all_admins` lacked `id`/`full_name`/`region_id`/`supervisor_id`/`scope` | Extended (backward compatible) in `059`. |
| `get_admin_profile` lacked `id`/identity fields | Extended in `059`. |
| No permission-list RPC | Added `get_admin_permissions` (059). |
| No target-admin audit RPC | Added `get_admin_audit_history` (059). |
| No reactivation inverse | Added `reactivate_admin` + `_admin_exec_reactivate` (059). |
| `create_admin_account` promotes existing id only; no Auth identity creation from client | Added secure Edge Function `create-admin` (service_role boundary; Flutter never holds secret). |
| `last_login` | **NOT TRACKED** in DB. UI shows "Not tracked" — no fabricated value. |

## 10. Recommended Implementation (delivered)
- Backend: `supabase/migrations/059_admin_management_center_contract.sql` + `supabase/functions/create-admin/`.
- Flutter module: `lib/features/admin_management/` (domain/data/presentation), routes
  `/admin/admins` + `/admin/admins/:id`, sidebar + quick-action entry, Arabic-first l10n.
- All sensitive actions call authorized modern RPCs; UI shows server result only
  (no optimistic success). Reactivation authorization uses the **stored**
  `supervisor_id` (not only active-traversal) so a deactivated admin's legitimate
  reactivation by its supervisor remains possible.
