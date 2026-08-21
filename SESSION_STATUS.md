# SESSION_STATUS.md

> **Last updated:** 2026-08-21 Session 68 — **SPRINT 96: BIOMETRIC LOGIN FIX + MASS ARABIC ENCODING REPAIR** — Two root causes fixed and verified live on device (DNP NX9). (1) Fingerprint login failed in both apps with `LocalAuthException(uiUnavailable, The current Activity must be a FragmentActivity)` because `MainActivity` extended `FlutterActivity` → switched to `FlutterFragmentActivity` (shared, both flavors); stale `FlutterSecureStorage.xml` (old debug-signing keystore) deleted and recreated. Verified: admin login-page prompt → scan → `authenticate result: true` → dashboard. Customer app verified with splash auto-login (fingerprint prompt at startup) + login-page fingerprint button; layout changed per user: guest button removed, register link moved up, fingerprint button below it. (2) User reported "اللغه العربى وحاجات كتير باظت" — root cause: sprint-91 monorepo restructure commit re-saved ~350 files with UTF-8-BOM and mojibake (Arabic UTF-8 bytes decoded as Windows-1252 then re-encoded as UTF-8; e.g. `Ø§Ù„Ù‚Ø±ÙŠØ¨Ø©` instead of القريبة). Fixed programmatically: 396 lines across 53 files (lib + supabase migrations + tests + ROADMAP.md) recovered via Windows-1252→UTF-8 round-trip (zero lossy chars — verified hex-perfect); 13 legit Latin-1 lines (—, °) skipped; 352 BOMs stripped. Verified live: customer home page tabs (القريبة/موصى لك/الأشهر), admin dashboard (مركز القيادة, إجمالي المستخدمين, المتاجر النشطة, التوثيقات المعلقة) all correct Arabic.

---

## Current Task — SPRINT 96 COMPLETED: BIOMETRIC LOGIN + ENCODING REPAIR (Session 68)

**Status:** DONE + committed + pushed. Both APKs rebuilt and installed; Arabic verified on device; DIAG logs removed.

### Biometric (fingerprint) login — root cause + fix

1. `android/app/src/main/kotlin/com/delwaqty/app/MainActivity.kt`: `FlutterActivity` → **`FlutterFragmentActivity`** (local_auth 3.x requirement; shared by admin + customer flavors; merged manifests verified: `USE_BIOMETRIC`, `USE_FINGERPRINT`, `.MainActivity`).
2. Stale secure-storage creds (`FlutterSecureStorage.xml` encrypted with pre-debug-signing keystore) unreadable → deleted on device → recreated at next login (entries readable; DIAG `store index read raw=["8a23b719-…"]` OK).
3. Verified admin: fingerprint button (creds saved) → system prompt → scan → `authenticate result: true` → dashboard. Customer: splash auto-login prompts at startup when logged out with creds; `_tryBiometricAutoLogin` in `splash_page.dart`; on exception → `biometricAuthStore.clearAll()` (wipes creds — retest after re-login).
4. Login page layout (user's final choice): guest button ("المتابعة كضيف") **removed**, register link ("ليس لديك حساب؟/إنشاء حساب") moved up, fingerprint button below it (icon + "تسجيل الدخول بالبصمة", disabled while loading). Rebuilt + verified on device.
5. DIAG debugPrints removed from `splash_page.dart` + `biometric_auth_store.dart` (incl. `flutter/foundation.dart` import).

### Arabic corruption — root cause + fix

- Root cause: sprint-91 restructure tool re-wrote files with wrong encoding (Windows-1252 misread of UTF-8 + BOMs). Old 11:16 AM APK was built pre-corruption → clean; new builds → mojibake. Committed at `cfa3ef0` (sprint 91), present in HEAD.
- Fix: batch script — per line with U+0080–U+00FF: encode Windows-1252 → decode UTF-8 (reversible; **0 lossy lines** found); skip lines whose round-trip keeps Latin-1 (legit —, °: 13 lines); write back preserving BOM-status/line endings; then strip BOMs (352 files). Final scan: **0 remaining fixable lines**.
- Scope: 396 fixed lines / 53 files — biggest: `home_page.dart` 50 (incl. `_labels` القريبة/موصى لك/الأشهر at :481), `admin_repository.dart` 25 (incl. `'currency': 'ج.م'`), `search_page.dart` 24, `service_booking_page.dart` 21, `platform_intelligence_providers.dart` 17, SQL migrations (031–040…), tests, ROADMAP.md. `app_ar.arb` was already clean.
- Verified on device (byte-level Arabic word search in uiautomator dumps): customer home (القريبة, موصى لك, الأشهر, مرحباً, مخبوزات, 🥖💐🧺 emojis), admin dashboard (مركز القيادة, بحث, المناطق, كافة المحافظات, اليوم/هذا الأسبوع, إجمالي المستخدمين, المتاجر النشطة, السائقون المتصلون, التوثيقات المعلقة, العمليات, إجمالي الطلبات, الرحلات النشطة, الشكاوى المعلقة, العقوبات النشطة, الأعضاء, الطلبات, المركز المالي, إجراءات).

### Notes / gotchas

- `adb shell cat file > local` writes UTF-16 via PowerShell redirection → use `adb pull` for byte-exact dumps (uiautomator text lives in `content-desc`, Flutter semantics).
- `adb install -r` silently no-ops on identical versionCode → uninstall+install for guaranteed update.
- Truecaller CallUIActivity can steal foreground → check `dumpsys activity activities | grep topResumedActivity` first.
- Admin login creds (user-provided): `said.3pkarino@gmail.com` / `Ed@20266`. Owner: `owner@delwaqty.com`. Live DB has 4 real users (owner, said.astora, cyfyfuf, e2etest user).
- PowerShell console can't display Arabic → verify via hex/byte patterns (`\uXXXX` regex) instead.

### Files modified (this session)
- `lib/data/datasources/local/biometric_auth_store.dart` — DIAG removed
- `lib/features/customer/splash/presentation/pages/splash_page.dart` — DIAG removed
- 53 files encoding-repaired + 352 BOMs stripped (lib/, supabase/migrations, test/, ROADMAP.md)
- `SESSION_STATUS.md` — this update

### Device Lock / App Lock feature (in progress — SESSION 68)

New user request: re-verify with ALL device credentials (PIN/pattern/password + face + fingerprint) on every **cold start**, dedicated App Lock screen, both apps, per saved account.

**Implemented:** `device_lock_provider.dart` (cold-start `init()` sets `unlocked=false` when `hasAnyCredentials()`), `device_unlock_page.dart` (lists saved accounts, `local_auth.authenticate(biometricOnly:false)` → sign-in via stored creds → `markUnlocked()`), lock gate in `app_router.dart` + `admin_router.dart` `redirect`, `/device-unlock` route, `splash_page.dart` auto-biometric removed (router enforces lock), `login_page.dart` `markUnlocked()` on sign-in, `biometric_auth_store.activeUserId()`, 8 l10n keys (deviceUnlock*).

**Audit (read-only sub-agent) + fixes applied:**
- **C1 (CRITICAL):** lock gate redirected *all* non-`/device-unlock` routes incl. `/login` → "Use another account" + password escape hatch dead → permanent lockout. Fixed: exempt `isAuthRoute` (login/register/forgot-password) in both routers.
- **M1:** `clearForUser` wiped creds on *any* `AuthError` (incl. network). Fixed: only on credential error ("invalid login credentials").
- **M2:** zero-account trap resolved by C1 (now `/login` reachable).
- **M3:** cold-start bypass window before `init()` — low impact (splash delay); accepted.
- **m1:** removed redundant `isAdmin ? Color : Color` ternary.
- **m3:** correct unlock destination via `user.isAdmin` (added `admin_access.dart` import for the `isAdmin` extension getter).
- **m4:** `init()` now explicitly sets `DeviceLockState(unlocked:false, hasDeviceAccount:hasCreds)`.
- Verified: all 8 l10n keys valid in both arb files; `refreshListenable` bump mechanism correct; backgrounding does NOT re-lock (spec).

**Build:** both APKs rebuild clean (`--flavor customer` + `--flavor admin`). `flutter analyze` still blocked (Dev Mode off). On-device unlock needs physical credential (PIN/face/fingerprint) — not simulatable via adb; UI login seeding blocked by adb `input text` dropping `@`/digits.

### Files modified (device lock)
- `lib/features/_shared/device_lock/device_lock_provider.dart`
- `lib/features/_shared/device_lock/presentation/device_unlock_page.dart`
- `lib/core/router/app_router.dart`, `lib/core/router/admin_router.dart`
- `lib/features/customer/splash/presentation/pages/splash_page.dart`
- `lib/features/_shared/auth/presentation/pages/login_page.dart`
- `lib/data/datasources/local/biometric_auth_store.dart`
- `lib/customer/app.dart`, `lib/admin/app.dart`
- `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`

### SPRINT 97 (partial): BUTTON ↔ RPC AUDIT — results

Read-only cross-check of all 93 `rpc(...)` calls in `lib/` against `CREATE FUNCTION` in `supabase/migrations/*.sql` (sub-agent "Manios"). **Every called RPC name resolves to a migration function — no missing/typo'd names.** Param-level findings:

**Fixed (verified against SQL signatures, both APKs rebuild clean):**
- `issue_sanction` @ `member_drawer.dart:1748` passed `p_user_id` → wrong (no overload). Changed to `p_member_id` (matches 035 `issue_sanction(p_member_id, ...)`). The other 2 call sites already used `p_member_id`.
- `get_member_timeline` @ `supabase_member_data_source.dart:63` passed `p_cursor` → wrong. Changed to `p_before` (matches 035 `get_member_timeline(p_member_id, p_before, p_limit)`).
- `member_ops_list` @ `supabase_member_data_source.dart:95,100` passed `p_service_type` (nonexistent) and `p_cursor_created_at` (nonexistent) → wrong. Changed to `p_service_category` and `p_cursor` (matches 049 `member_ops_list(..., p_service_category, ..., p_cursor, p_cursor_id, ...)`).

**FALSE POSITIVES (do NOT change — verified overloads in `057_owner_delete_missing_admin_rpcs.sql`):**
- `assign_admin_role` @ `admin_hierarchy_page.dart:295,367` uses `p_email`/`p_role` → matches 057 overload `assign_admin_role(p_email text, p_role text, p_reason)` (034 uuid overload also exists; PostgREST resolves by param types).
- `assign_admin_region` @ `admin_hierarchy_page.dart:427` uses `p_email`/`p_region` → matches 057 overload `assign_admin_region(p_email text, p_region text, p_scope)` (resolves region by name).

**Remaining (NOT done this pass — needs careful, separate refactor + live-DB verification; flagged as tech debt, not a runtime crash):**
- `admin_repository.dart` legacy `admin_users` table direct access (lines 549 select, 581 insert, 607 update, 634 delete). Table still exists with RLS so it currently works, but modern stack uses `users`/`admin_management` + RPCs (`get_all_admins`, `create_admin_account`, `assign_admin_role`, `deactivate_admin`, `owner_delete_member`). `deleteUser` raw delete (634) bypasses SECURITY DEFINER — should route through a proper admin-lifecycle RPC. **Deferred:** blind refactor risks breaking the admin panel (field-shape mismatches, no `analyze`/`test` available here). Requires dedicated pass mapping return shapes + verifying RLS.
- ~60 transport/delivery/ride/safety/platform-intelligence/notification RPCs confirmed present in migrations but their individual `params:` keys were not diffed line-by-line — recommend a scripted RPC-signature linter as follow-up.

### admin_users legacy refactor — RETAINED as explicit technical debt (evidence-based, NO code change)

Per sprint-97 rules 3/8/9, the four `admin_repository.dart` operations on the legacy `admin_users` table were investigated against the actual schema + RPCs. **None has a complete, behavior-preserving, verified mapping** → all four retained unchanged; documented here; no second admin-management system created; no schema modified; no duplicate RPCs.

**Evidence (source of truth):**
- `016_fix_rls_policies.sql:14` — `admin_users.id` is a **separate generated UUID (not `users.id`)**.
- `031_admin_hierarchy_region_assignments.sql:32-47` (ADR-055) — adds `user_id` FK `admin_users→users(id)`; `:141` — `admin_users (F1, dormant metadata — still readable by admins)`.
- `034:670` `create_admin_account(p_user_id uuid, p_supervisor_id, p_region_id, p_scope)` — promotes an **existing `users.id`** only; no create-from-email.
- `034:725` `deactivate_admin(p_admin_id uuid, p_reason)` — soft deactivate.
- `057:252` `get_admin_profile(p_email)` → returns `email, role, is_owner, region_name, total_earnings` (**no full_name / status / last_login**).
- `057:305` `get_all_admins()` → returns `email, role, region_name, is_active, supervisor_email, created_at` (**no full_name / status / last_login**).
- `058:27-122` `owner_delete_member(p_member_id uuid, p_reason)` — **owner-only**; deletes `users`+`auth.users` + cleans `admin_management`/drivers/etc.; does **NOT** delete the `admin_users` row (would orphan it).

**Field mapping (OLD → NEW):**
| OLD `admin_users` field | NEW source/RPC field | Status |
|---|---|---|
| `id` (separate UUID) | `admin_users.user_id` → `users.id` (FK, 031) | no 1:1 direct key |
| `full_name` | `users.full_name` — **not returned by any admin RPC** | ❌ no mapping |
| `email` | `get_all_admins().email` | ✅ available |
| `role` | `get_all_admins().role` | ✅ available |
| `status` (active/suspended/pending) | modern = `admin_management.is_active` (bool); no status enum / no suspend RPC | ❌ no mapping |
| `last_login` | **not returned by any admin RPC** | ❌ no mapping |
| `created_at` | `get_all_admins().created_at` | ✅ available |
| `region` | `get_all_admins().region_name` | ✅ available |

**Action mapping (OLD → NEW):**
| OLD action | NEW RPC | Verdict |
|---|---|---|
| `createUser` (insert new `admin_users` from email+name+role+status) | `create_admin_account` needs existing `users.id` | ❌ NO equivalent → RETAIN |
| `updateUser` (full_name,email,role,status) | `assign_admin_role`(role, needs users.id) + no RPC for admin full_name/status | ❌ INCOMPLETE → RETAIN |
| `deleteUser` (hard delete `admin_users` by `admin_users.id`) | `owner_delete_member(p_member_id=users.id)` | ❌ UNSAFE: owner-only (authz change), keys on `users.id` not `admin_users.id`, orphans `admin_users` row → RETAIN |
| `getUsers` (read) | `get_all_admins()` lacks full_name/status/last_login | ❌ INCOMPLETE → RETAIN |

**Recommended future migration (separate effort, needs product decision + likely new RPCs):** rebuild `admin_users_page` on `get_all_admins()` + extend admin RPCs to return `full_name`/`status`/`last_login` + add an admin-create-user RPC; or formally deprecate `admin_users` (dormant metadata) and stop reading it for the live admin list. Until then the legacy path is the only source of `name`/`status`/`last_login` for that screen.

### Build commands
```powershell
$env:PUB_CACHE = "E:\app\pub-cache"
flutter build apk --debug --flavor admin --target lib/admin/main.dart --dart-define-from-file=.env.dev
flutter build apk --debug --flavor customer --target lib/customer/main.dart --dart-define-from-file=.env.dev
adb -s A3SQUT5A28003808 install -r build\app\outputs\flutter-apk\app-admin-debug.apk
adb -s A3SQUT5A28003808 shell am start -n com.delwaqty.admin/com.delwaqty.app.MainActivity
```

### NEXT TASK — admin_users legacy refactor (careful, separate pass)

---

## Previous Tasks

- **SPRINT 95:** Deletion root-cause fix + missing RPCs + live fixes — 057, KPI, dead buttons, search route
- **SPRINT 94:** Admin features expansion (dark mode, owner delete, profile, hierarchy, pending deletions)
- **SPRINT 93:** Admin nav redesign
- **SPRINT 92:** Admin bottom nav redesign v1
- **SPRINT 91:** Monorepo restructure
- **SPRINT 90:** iPhone-style bottom nav, account deletion, driver doc upload
- **SPRINT 89:** Privacy persistence, service booking l10n, admin polish
- **SPRINT 88:** Critical fixes
- **SPRINT 87:** Admin standalone polish