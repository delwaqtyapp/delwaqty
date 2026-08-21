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

### NEXT TASK — SPRINT 97: BUTTON ↔ RPC AUDIT

Full audit of every admin button against the actual DB RPCs ("ندقق في ربط كل زر ودوال الداتا بيز"). Scope:

- Enumerate all `client.rpc('...')` calls in `lib/` and cross-check against migrations + live DB
- Enumerate direct `.from('table').insert/update/delete` calls that RLS may block
- Fix `admin_repository.dart` legacy `admin_users` table usage (should be users/admin_management)
- Fix `AdminService.deleteUser` → route through `owner_delete_member`
- Verify `issue_sanction` param names in member drawer (035 signature)
- Environment note: `flutter analyze`/`flutter run` fail with "Building with plugins requires symlink support" (Windows Developer Mode off, not elevated). Build + `adb install` + `am start` + uiautomator/REST testing works.

### Build commands
```powershell
$env:PUB_CACHE = "E:\app\pub-cache"
flutter build apk --debug --flavor admin --target lib/admin/main.dart --dart-define-from-file=.env.dev
flutter build apk --debug --flavor customer --target lib/customer/main.dart --dart-define-from-file=.env.dev
adb -s A3SQUT5A28003808 install -r build\app\outputs\flutter-apk\app-admin-debug.apk
adb -s A3SQUT5A28003808 shell am start -n com.delwaqty.admin/com.delwaqty.app.MainActivity
```

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