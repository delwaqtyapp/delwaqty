# Sprint 61 — Precise Localized Location + Fingerprint Auto-Login (Session 21s)

## Goal

User request (Arabic): fix the location so it is **precise** instead of generic, and **localized** (Arabic with the Arabic UI, English with the English UI); and make the fingerprint button **log in automatically** by detecting the saved biometric account + its stored password without requiring the user to tap the saved-account chip first.

## 1. Location — precise + localized

| Item | Change |
|------|--------|
| **Root cause — generic address** | `_cleanArabicAddress` stripped **all digits**, destroying street numbers; the geocoders were always called without a language; and the address cache was language-agnostic, so a switch from Arabic to English kept showing the Arabic string |
| **Fix — precision** | Google Geocoding now parses `street_number` + `route` and builds a `"number route"` street part (digits preserved). Separators are locale-aware (`،` for `ar`, `,` for `en`). `_cleanAddress` no longer strips digits and only normalizes separators |
| **Fix — localization** | Google is called with `language=$language`, Photon with `lang=$language`, Nominatim with `accept-language=$language`. A new `_appLanguage()` reads `localeProvider`. Cache key is now `lat,lng@language` (`location_geocode_cache_v2`, TTL 24 h, cap 200) so each language resolves independently |
| **Fix — reactive language switch** | `UserLocationNotifier.build()` now `ref.watch(localeProvider)` — switching the UI language re-runs position + reverse geocoding immediately in the new language (previously the chip kept the old-language address forever) |
| **On-device result (Arabic)** | Home header now shows `Zafarana offices، عتاقة، محافظة السويس، مصر` — governorate added (was `…، عتاقة، مصر`). The coordinate is inside a building where Google only returns premise-level components, so no street number is available from any provider at that point |
| **On-device result (English)** | Bug reproduced before the fix (Arabic string kept after switching UI to English), then fixed via the `ref.watch(localeProvider)` re-trigger |

## 2. Fingerprint — auto-login without selecting the account

| Item | Change |
|------|--------|
| **Root cause** | `_authenticateWithBiometric` required a non-empty email; with none selected it showed "Enter your email first". It never looked up which saved account has fingerprint enabled |
| **Fix — store** | `SavedAccountsStore.biometricAccount()` returns the first saved account with `hasBiometric == true` (new method, covered by 3 new unit tests) |
| **Fix — login page** | `_authenticateWithBiometric` now, when no email is selected, loads `biometricAccount()`; if found it uses that email + its Keystore-stored password and signs in automatically. Falls back to the enable-dialog for accounts with no stored password. New l10n keys: `noBiometricAccountSaved`, `biometricNotEnrolled` (en + ar) |

## 3. Quality gates

- `flutter analyze` — 0 errors, 0 warnings from touched files (repo-wide info lints pre-existing)
- `flutter test` — **577/577 passing** (was 575 → +2 from `biometricAccount` tests; 3 tests added, net count aligns)
- Debug APK built (`--dart-define-from-file=.env.dev`) + installed on DNP NX9; app launches clean

## Remaining (blockers, not code)

- **On-device fingerprint success path** cannot be exercised on DNP NX9: `dumpsys biometric` reports sensor state 4 (bad) despite 4 enrolled fingerprints, so a real scan always fails with a `PlatformException`. The auto-detection + password retrieval logic is unit-tested; the auth gesture needs a healthy device.
- **Street number at the test coordinate**: Google returns premise-only components inside the building; a number would appear at street-level coordinates. Data limitation, not app logic.

## Files touched

- `lib/features/location/presentation/providers/location_provider.dart`
- `lib/data/datasources/local/saved_accounts_store.dart`
- `lib/features/auth/presentation/pages/login_page.dart`
- `lib/l10n/app_en.arb`, `app_ar.arb`, `app_localizations*.dart`
- `test/data/datasources/local/saved_accounts_store_test.dart`
- Included: `lib/features/settings/presentation/pages/privacy_security_page.dart`, `lib/features/settings/presentation/pages/privacy/fingerprint_login_page.dart`, `test/features/settings/` (fingerprint Settings toggle from the previous uncommitted batch, part of the fingerprint milestone)
