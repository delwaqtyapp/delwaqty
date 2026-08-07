# Sprint 60 (follow-up) — Login UX: Fingerprint + Saved Accounts + Social Removal

**Date:** 2026-08-07 · **Branch:** master (uncommitted) · **Session:** 21q

## Feature

The login screen's fingerprint button now actually works, social login (Google/Apple/Facebook) is removed for now, the "save account" checkbox persists accounts correctly, and the login page shows a horizontal Saved Accounts section for fast re-login. Biometric passwords are stored only in Keystore/Keychain; the account list is lightweight JSON in SharedPreferences.

## Root causes fixed

| Symptom | Root cause |
|---------|-----------|
| Fingerprint button did nothing | `AndroidManifest.xml` was missing `USE_BIOMETRIC`/`USE_FINGERPRINT`; old flow stored email/password in **plaintext SharedPreferences** under `biometricEnabled/biometricEmail/biometricPassword` and required a password re-entry bypass — never a biometric-only `LocalAuthentication` call |
| Save-account checkbox did nothing persistent | No storage layer; `signOut` wiped the biometric prefs so anything saved never survived |
| Social buttons shown but broken | No OAuth providers configured; `signInWithGoogle/Apple/Facebook` were decoration |
| No saved-account UI | Nothing existed to enumerate previously saved accounts |

## What shipped this session

### Secure storage layer
- **`SavedAccount`** Freezed model (`lib/features/auth/domain/saved_account.dart`): `email`, `displayName`, `hasBiometric`, normalized `key` getter (`trim().toLowerCase()`); generated `.freezed.dart`/`.g.dart` are gitignored build artifacts.
- **`SavedAccountsStore`** (`lib/data/datasources/local/saved_accounts_store.dart`, provider `savedAccountsStoreProvider`): account list persisted as JSON under `StorageKeys.savedAccounts` (SharedPreferences), biometric password written to **Keystore/Keychain** via `flutter_secure_storage` under `biometric_password_<email>`. Emails normalized at the boundary (`saveAccount`/`removeAccount`/`setBiometric`). Store tests exposed + fixed two real bugs: `loadAccounts` returned an unmodifiable `const []` (crash on first save) and comparison keys were never normalized.
- `StorageKeys`: old plaintext `biometricEnabled/biometricEmail/biometricPassword` deleted, replaced with single `savedAccounts`.

### Login page (`login_page.dart`)
- Social buttons removed.
- Checkbox row: "حفظ الحساب" (save account) + optional "تفعيل البصمة" (enable fingerprint, only when `canCheckBiometrics` and save-account checked). On `authenticated`, `_handlePostLoginSave()` persists the account (+ sets biometric) before navigating home.
- Saved Accounts section: horizontal chips — avatar initial, fingerprint badge (one-tap biometric sign-in) when `hasBiometric`, remove × with confirm dialog (removes account + its secure password). Tapping a chip fills the email field, selects the text, focuses the password field.
- Fingerprint button: `LocalAuthentication.authenticate` with `biometricOnly` + `stickyAuth`, then reads the secure password and calls `signIn`; shown only when the filled email has `hasBiometric` AND biometrics are available; `mounted` guards on all async gaps.

### Auth provider (`auth_provider.dart`)
- `signInWithGoogle/signInWithApple/signInWithFacebook` getters + methods removed.
- `signOut` no longer wipes biometric/saved-account storage — saved accounts survive logout by design (that is what makes quick re-login useful).

### Dependencies / platform
- `flutter_secure_storage: ^11.0.0` — the only line whose Windows package uses `win32 ^6` (compatible with `geolocator ^14`); v10 uses `win32 ^5` (conflict). v11's AAR requires Android API 37.
- **`compileSdk` 36 → 37** in `android/app/build.gradle.kts` (android-37 platform already installed in the local SDK).
- `AndroidManifest.xml`: added `USE_BIOMETRIC` + `USE_FINGERPRINT`.
- Plugin registrants regenerated for linux/macos/windows (flutter_secure_storage platform packages).

### l10n
New keys (en + ar): `saveAccount`, `savedAccounts`, `savedAccountsHint`, `removeAccount`, `removeSavedAccountConfirm` (placeholder `{email}`), `accountSaved`, `accountRemoved`; regenerated.

## Quality Gates

- `flutter analyze` — **0 errors, 0 warnings from touched files** (remaining warnings/infos are pre-existing in untouched modules).
- `flutter test` — **567/567 passing** (was 556 → +11: `saved_account_test.dart` ×4, `saved_accounts_store_test.dart` ×7).
- Debug APK built (`compileSdk 37`) + installed on DNP NX9; app launches clean (no FATAL, no ConfigValidator crash).

## Files Changed

- New: `lib/data/datasources/local/saved_accounts_store.dart`, `lib/features/auth/domain/saved_account.dart`, `test/data/datasources/local/saved_accounts_store_test.dart`, `test/features/auth/domain/saved_account_test.dart`.
- Edited: `lib/features/auth/presentation/pages/login_page.dart` (rewrite), `lib/features/auth/presentation/auth_provider.dart` (social removal, signOut storage decoupling), `lib/core/constants/storage_keys.dart`, `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts` (compileSdk 37), `pubspec.yaml` + `pubspec.lock`, `lib/l10n/app_en.arb` + `app_ar.arb` + generated localizations.
- Docs: `SESSION_STATUS.md` (21q), `ROADMAP.md`, `docs/DECISION_LOG.md` (ADR-041).

## Next

1. **On-device check** (needs the user): enroll a fingerprint on DNP NX9, log in with save-account + enable-fingerprint, then verify the fingerprint quick-login and saved-account chips behave as expected.
2. **Sprint 60 E2E still pending**: register → confirm-email-link → pending → admin approve → home (user taps the confirmation link; free-tier mailer 2/hr).
3. **Security:** revoke the Supabase Personal Access Token used in the Sprint 60 session.
4. Commit + push this milestone (`sprint 60: ...`).
