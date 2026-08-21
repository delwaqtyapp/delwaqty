# Delwaqty - Known Issues

**Generated:** 2026-07-16

---

## Critical

### 1. Database Tables Not Created
- **Issue:** SQL migration has not been executed against Supabase
- **Impact:** All Supabase-backed features return 404
- **Fix:** Run `supabase/migrations/001_initial_schema.sql` in Supabase Dashboard SQL Editor
- **URL:** https://supabase.com/dashboard/project/bttnlkmwhorjamzemwda/sql/new

### 2. Database IPv6-Only
- **Issue:** `db.bttnlkmwhorjamzemwda.supabase.co` resolves to IPv6 only
- **Impact:** Cannot connect from PRoot/Termux environments (no IPv6 kernel support)
- **Fix:** This is a Supabase infrastructure limitation for this project
- **Workaround:** Use Supabase Dashboard or environments with IPv6 support

## High

### 3. All Repositories Are Mock
- **Issue:** Every repository uses mock/in-memory data
- **Impact:** No persistent data between app restarts
- **Fix:** Replace mock repos with Supabase-backed implementations (Sprint 12)

### 4. Firebase Not Configured
- **Issue:** No `google-services.json` or Firebase project
- **Impact:** No push notifications, no analytics, no crash reporting
- **Fix:** Create Firebase project, add `google-services.json` to `android/app/`

### 5. Google Maps Not Functional
- **Issue:** No API key configured
- **Impact:** Map views, delivery tracking, geofencing all non-functional
- **Fix:** Get API key from Google Cloud Console, add to `.env.dev`

## Medium

### 6. Assets Directory Empty
- **Issue:** `assets/fonts/`, `assets/icons/`, `assets/images/` all empty
- **Impact:** App uses Material Design defaults only
- **Fix:** Add custom assets and update `pubspec.yaml` assets section

### 7. Admin RLS Policies Too Permissive
- **Issue:** Most admin policies use `USING (true)`
- **Impact:** Any authenticated user can read/write admin data
- **Fix:** Restrict to admin role using `auth.jwt() ->> 'role' = 'admin'`

### 8. No Real Authentication Flow
- **Issue:** Auth screens exist but don't connect to Supabase Auth
- **Impact:** Cannot register or login real users
- **Fix:** Wire auth pages to `AuthService` with Supabase Auth

### 9. `admin_users` legacy table retained (technical debt)
- **Issue:** `admin_repository.dart` `getUsers/createUser/updateUser/deleteUser` still read/write the legacy `admin_users` table. The modern admin stack uses `users`/`admin_management` + RPCs (`get_all_admins`, `create_admin_account`, `assign_admin_role`, `deactivate_admin`, `owner_delete_member`). `admin_users` is "dormant metadata" (`031:141`) with a separate UUID PK (`016:14`) linked to `users.id` via `user_id` FK (ADR-055). No complete, behavior-preserving mapping exists for any of the 4 ops (missing `full_name`/`status`/`last_login` in admin RPCs; `create_admin_account` only promotes an existing `users.id`; `owner_delete_member` is owner-only, keys on `users.id`, and orphans the `admin_users` row).
- **Impact:** Parallel admin store; the admin-users screen cannot be cleanly migrated without new RPCs / UI changes.
- **Fix:** Deliberately retained (sprint 97, rules 3/8/9). Future: rebuild the screen on `get_all_admins()` + extend admin RPCs to return `full_name`/`status`/`last_login` + add an admin-create-user RPC, or formally deprecate `admin_users`. See `SESSION_STATUS.md` (SPRINT 97) for the full mapping table.

## Low

### 162 Info-Level Lint Warnings
- **Issue:** Style suggestions from `flutter analyze`
- **Impact:** No functional impact
- **Fix:** Address over time (require_trailing_commas, prefer_single_quotes, etc.)
