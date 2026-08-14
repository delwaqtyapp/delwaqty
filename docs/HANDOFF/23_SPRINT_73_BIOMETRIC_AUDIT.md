# Sprint 73 — Biometric Login: Audit, Security Fix, and Packaging

**Date:** 2026-08-14
**Status:** Complete (audit + fix + gate passed)

---

## Summary

Biometric login is a fully-integrated feature across Delwaqty. This sprint audited the complete
flow (device → app → database), found and fixed one real security gap, verified the whole feature
set with the full gate, and prepared the production APK for installation.

## Feature inventory (verified working)

| Layer | Where | Status |
|-------|-------|--------|
| DB column `users.is_biometric_enabled` | `supabase/migrations/022_user_biometric_enabled.sql` (applied live) | Done |
| Encrypted credential store | `lib/data/datasources/local/biometric_auth_store.dart` | Done |
| Login-page fingerprint button + enrollment offer | `lib/features/auth/presentation/pages/login_page.dart` | Done |
| Settings page (toggle + password prompt + accounts) | `lib/features/settings/presentation/pages/privacy/fingerprint_login_page.dart` | Done |
| Splash auto-login with biometric | `lib/features/splash/presentation/pages/splash_page.dart` | Done |
| DB sync via `updateBiometricEnabled` | `lib/features/auth/presentation/auth_provider.dart` → `auth_repository_impl.dart` → `supabase_profile_data_source.dart` | Done |
| Android permissions | `android/app/src/main/AndroidManifest.xml` (`USE_BIOMETRIC`, `USE_FINGERPRINT`) | Done |
| Dependencies | `local_auth ^3.0.0`, `flutter_secure_storage ^11.0.0` | Done |
| Localization AR/EN | `lib/l10n/app_*.arb` | Done |
| Tests | `test/data/datasources/local/biometric_auth_store_test.dart`, `test/features/settings/presentation/pages/privacy/fingerprint_login_page_test.dart` | Done |

## Bug fixed (security)

**Change password did not invalidate biometric credentials.** After a password change the
encrypted credentials in secure storage kept the *old* password — biometric login would fail and a
stale secret would remain on-device.

**Fix** (`lib/features/settings/presentation/pages/privacy/change_password_page.dart`):
- Converted to `ConsumerStatefulWidget`
- Added `_invalidateBiometricLogin()` called after `auth.updateUser(...)`:
  - `biometricAuthStore.clearForUser(user.id)` — removes the stale encrypted credential
  - `updateBiometricEnabled(enabled: false)` — resets the DB flag

Effect: the user must re-enroll for biometric login after a password change. No orphaned secrets.

## Gate results

- `flutter analyze` → **0 errors**, 543 issues (24 warning + 519 info — unchanged baseline)
- `flutter test --no-pub --concurrency=2` → **594/594 passed** (exit 0)
- Note: on this PRoot host, full `flutter test` without `--concurrency` can exit 1 silently;
  `--concurrency=2` is the reliable invocation.

## Files touched

- `lib/features/settings/presentation/pages/privacy/change_password_page.dart` (fix)
- `SESSION_STATUS.md` (Session 40)

## Next steps

1. Build APK: `flutter build apk --release --dart-define-from-file=.env.dev`
2. Install on the phone (needs USB debugging / adb connected)
3. Commit + push this sprint
4. Revoke the Supabase PAT after the session
