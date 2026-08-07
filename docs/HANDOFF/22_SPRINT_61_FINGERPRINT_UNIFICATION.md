# Sprint 61 — Fingerprint Auto-Login Unification on the DB-Backed Store (Session 23)

## Goal

The login-page fingerprint button did not auto-login ("زر البصمة لا يسجل الدخول تلقائياً") even though the device sensor is healthy. Root cause: the DB-backed biometric system from Session 22 (`BiometricAuthStore` + `users.is_biometric_enabled`) was used by enrollment and startup auto-login, but the **login-page button, saved-account chip badges, and the Settings toggle still read the legacy ADR-041/043 path** (`SavedAccountsStore.biometric_password_<email>` + `SavedAccount.hasBiometric`). A user enrolled through the new dialog had their credentials written only to `BiometricAuthStore`; the button then reported `noBiometricAccountSaved`. Additionally, on Android 16 (API 36), `local_auth_android` 1.0.56 threw `PlatformException(channel-error)` during `authenticate()`, causing the enrollment prompt to fail with "تعذر تفعيل تسجيل الدخول بالبصمة". This session unifies every fingerprint entry point on the new store + DB flag, and upgrades `local_auth` to 3.0.0 for Android 16 compatibility.

## 1. What changed

| Item | Change |
|------|--------|
| **Root cause** | Two parallel biometric systems held different data. Enrollment wrote `auth_biometric_<userId>` (new store); the login button read `biometric_password_<email>` (legacy store). The button could never see a newly enrolled user |
| **Login button fix** | `login_page.dart` `_authenticateWithBiometric` now reads `biometricAuthStoreProvider.activeCredentials()` (the single active biometric user), authenticates with the real sensor (`biometricOnly` + `stickyAuth`), fills email/password, and calls `signIn`. Deleted: the email-keyed `biometricPassword` lookup and the `_promptEnableFingerprint` password re-entry dialog |
| **Legacy UI removed** | The `_enableBiometric` checkbox on the login form and the per-chip fingerprint badge on `_SavedAccountChip` are gone. `_BiometricButton` always shows the `fingerprintLogin` label (no saved-email caption). Enrollment is exclusively the post-password-login dialog |
| **Model** | `SavedAccount.hasBiometric` removed (`lib/features/auth/domain/saved_account.dart`); Freezed/json regenerated. The saved-account list is again pure email/displayName prefill |
| **Store** | `SavedAccountsStore` reduced to SharedPreferences only: dropped `FlutterSecureStorage`, `setBiometric`, `biometricPassword`, `biometricAccount`, and the `biometric_password_<email>` keys. Constructor now takes only `SharedPreferencesService` |
| **Settings toggle** | `fingerprint_login_page.dart`: `_loadStatus` reads `user.isBiometricEnabled` (DB — source of truth) instead of scanning accounts; toggle-on → `saveCredentials(userId, …)` if absent + `updateBiometricEnabled(true)`; toggle-off → `clearActive()` + `updateBiometricEnabled(false)` |
| **Enrollment prompt** | Unchanged behavior (post-login dialog → new store + `updateBiometricEnabled(true)`); the now-dead `skipEnrollmentPrompt` plumbing removed |
| **local_auth upgrade** | `local_auth` ^2.3.0 → ^3.0.0 (breaking: `PlatformException` → `LocalAuthException`, `AuthenticationOptions` → named params `persistAcrossBackgrounding`/`biometricOnly`). Fixes `PlatformException(channel-error)` on Android 16 (API 36) where `local_auth_android` 1.0.56 failed to establish the Pigeon channel for `BiometricPrompt`. Removed unused `import 'package:flutter/services.dart'` from `login_page.dart` and `splash_page.dart` |

## 2. Device sensor re-check

`dumpsys fingerprint` on DNP NX9 now reports a **healthy** sensor: `Fps state: 0`, 4 enrolled prints, no lockouts, and recent events like `authEndedFor(…, requestId=128, wasSuccessful=true)`. The earlier "state 4 (bad)" blocker is resolved — the end-to-end auto-login gesture can now be verified on the device.

## 3. Quality gates

- `flutter analyze` — **0 errors / 0 warnings** from touched files (514 pre-existing info lints, baseline unchanged)
- `flutter test` — **594/594 passing** (net −5: saved-account store/model biometric tests removed; settings page tests rewritten with mocked `authRepositoryProvider`/`userRepositoryProvider`)
- Debug builds pass; release APK rebuilt + reinstalled on DNP NX9 for the on-device fingerprint verification

## Tests rewritten

- `test/data/datasources/local/saved_accounts_store_test.dart` — trimmed to non-biometric scope (5 tests)
- `test/features/auth/domain/saved_account_test.dart` — `hasBiometric` assertions removed
- `test/features/settings/presentation/pages/privacy/fingerprint_login_page_test.dart` — now drives `BiometricAuthStore` (real store over `FlutterSecureStorage.setMockInitialValues`) + DB flag via mocked repositories

## Remaining

- Users enrolled under the legacy pre-ADR-044 path must re-enroll once via the post-login dialog (old `biometric_password_<email>` entries are no longer read) — no migration added, acceptable pre-release.
- Village-chain end-to-end at a real open-sky village coordinate on-device still pending (app-restricted Google key).
