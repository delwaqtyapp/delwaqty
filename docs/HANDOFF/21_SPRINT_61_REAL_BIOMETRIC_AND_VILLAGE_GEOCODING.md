# Sprint 61 — Real Biometric Login (DB-backed) + Village-Centric Arabic Geocoding (Session 22)

## Goal

1. **Refine Arabic reverse geocoding** so villages and tourist areas render the hierarchical **Markaz → village** chain (e.g. `مركز السويس - قرية الزعفرانة`) instead of a flat road-only string, while staying localized on language switch.
2. **Replace the fingerprint "auto-detect" with a real, database-linked biometric system**: a `users.is_biometric_enabled` column, an enable-after-password-login prompt, per-user encrypted credentials in secure storage (`auth_biometric_<userId>`), and biometric auto-login at app start.

## 1. Geocoding — village-centric hierarchy chain

| Item | Change |
|------|--------|
| **Root cause** | `_googleStructuredAddress` / `_nominatimStructuredAddress` flattened components into a fixed column set, so a village like Zafarana rendered only as `Zafarana offices، عتاقة، محافظة السويس، مصر` — no Markaz (administrative district) and no village locality appeared |
| **Fix — Google chain** | Extracted static `@visibleForTesting composeGoogleAddress`: walks `administrative_area_level_2 → level_3 → sublocality_level_3 → level_2 → level_1 → neighborhood`, joined by `' - '` (Arabic `'، '`, English `', '`), dedup across the chain and within a single component chain |
| **Fix — Nominatim chain** | Static `composeNominatimAddress` hierarchy: `county, municipality, city, town, village, hamlet, city_district, suburb, quarter, neighbourhood, residential`; named-place keys (amenity/shop/tourism/leisure/office/craft/building/man_made/house_name) are exempt from the chain when they contain digits (a POI with a street number is kept in the street slot); region = state/region; country deduped |
| **Static helpers** | `_typesContain` made static; `composeGoogleAddress`/`composeNominatimAddress` exposed for testing |
| **Tests** | 11 new tests in `location_provider_test.dart` (Google: AR hierarchy chain `Zafarana offices، مركز السويس - قرية الزعفرانة، محافظة السويس، مصر`, EN chain, cross-field dedup, within-chain collapse, street number + route, empty → null, hasNamed false; Nominatim: county+village, city+suburb, named-place prefix, dedup, empty → null). All 29 location tests pass |
| **On-device note** | Device coordinate (29.2001, 32.6303) sits inside a building; Google returns only premise-level components there, so the chip output is unchanged (`Zafarana offices، عتاقة، محافظة السويس، مصر`) — the hierarchy chain shows at open-sky village coordinates. Live Nominatim probes at Zafarana (29.1119, 32.6592) returned only road/state/country — OSM is sparse for Egyptian villages, Google is the real hierarchy source |

## 2. Biometric — real DB-linked system

| Item | Change |
|------|--------|
| **Migration `022_user_biometric_enabled.sql`** | `ALTER TABLE users ADD COLUMN IF NOT EXISTS is_biometric_enabled BOOLEAN NOT NULL DEFAULT false;` |
| **Model** | `@Default(false) bool isBiometricEnabled` added to `User` + `UserModel`; `fromSupabase` maps `is_biometric_enabled` (missing → false); `toSupabaseMap`/`toUpdateMap` now export `'is_biometric_enabled'`. Freezed/json regenerated |
| **Backend chain** | `AuthRepository.updateBiometricEnabled({required String userId, required bool enabled})` → `AuthRepositoryImpl` via `_profileDataSource.updateProfile` → `updateBiometricEnabledUseCase` + provider in `auth_usecases.dart` → `AuthStateNotifier.updateBiometricEnabled` (guards `AuthAuthenticated`, re-fetches the user, re-applies `_resolveAuthenticated`) |
| **Secure store** | New `lib/data/datasources/local/biometric_auth_store.dart`: per-user JSON credentials (`BiometricCredentials{email, password}`) in `flutter_secure_storage` under `auth_biometric_<userId>`; single active-user key `auth_biometric_active_user`; `saveCredentials`/`credentialsFor`/`activeCredentials`/`clearActive`; corrupt payload → null. Provider `biometricAuthStoreProvider` |
| **Enrollment prompt** | `login_page.dart`: after a successful password login, if biometrics are available and the user has not enabled them, an AlertDialog asks `هل ترغب في تفعيل الدخول بالبصمة للمرة القادمة؟`; confirm → `LocalAuthentication().authenticate` (biometricOnly + stickyAuth, localized `biometricReason`) → `biometricAuthStore.saveCredentials(userId, email, password)` + `updateBiometricEnabled(true)` + `fingerprintEnabled` snackbar; `PlatformException` → `biometricEnableFailed` snackbar. Dialog is suppressed when a biometric auto-login just completed (`_pendingEnableBiometric`). New l10n keys (en+ar): `enableBiometricPromptTitle`, `enableBiometricPromptMessage`, `enableBiometricConfirm`, `enableBiometricLater`, `biometricEnableFailed` |
| **Auto-login at start** | `splash_page.dart` `_navigate()` is async: when `authState is! AuthAuthenticated` it calls `_tryBiometricAutoLogin()` — reads `activeCredentials()`, shows the local biometric prompt, then `signIn(email, password)`. `AuthError`/`AuthUnauthenticated`/general failure → `clearActive()`; `PlatformException` (no print / canceled) falls through to `/login` |
| **Tests** | New `biometric_auth_store_test.dart` (8 tests via `FlutterSecureStorage.setMockInitialValues`); `user_model_test.dart` updated (fromSupabase true/missing-default, toEntity passes the flag, toSupabaseMap exports `'is_biometric_enabled': false`) |
| **Release signing note** | `android/keystore/release.jks` **exists** but `KEYSTORE_PASSWORD` is not set → `flutter build apk --release` fails with `KeytoolException: keystore password was incorrect`. Per pre-approved fallback the **debug APK** was built and installed (works 100% for testing); a signed release build needs the keystore password from the user |

## 3. Quality gates

- `flutter analyze` — 0 errors, 0 warnings from touched files (repo-wide info lints pre-existing)
- `flutter test` — **599/599 passing** (was 577 → +22 net new)
- Debug APK built (`--dart-define-from-file=.env.dev`) + installed on DNP NX9; app launches clean, session restored, home header renders `Zafarana offices، عتاقة، محافظة السويس، مصر`, logcat clean (no exceptions)

## Remaining (blockers, not code)

- **On-device biometric success path** is unverifiable on DNP NX9: the sensor reports state 4 (bad), so a real scan throws `PlatformException`. All pre-scan logic (store, enable chain, auto-login gating) is unit-tested.
- **Release signing**: `KEYSTORE_PASSWORD` env is required to sign a release APK (the keystore file exists). Debug signing is the tested fallback.
- **Village-chain end-to-end** needs a Google Geocoding call at a real open-sky village coordinate on-device (the app-restricted key cannot be exercised from the shell).

## Follow-up: Migration 022 applied live (2026-08-08)

`ALTER TABLE users ADD COLUMN IF NOT EXISTS is_biometric_enabled BOOLEAN NOT NULL DEFAULT false;` was executed against `bttnlkmwhorjamzemwda` through the Supabase Management API using the user-supplied PAT. Verified in `information_schema.columns`: `is_biometric_enabled boolean NOT NULL default=false`. The PAT should be revoked after use per project policy.

## Files touched

- `lib/features/location/presentation/providers/location_provider.dart` (+ tests `location_provider_test.dart`)
- `supabase/migrations/022_user_biometric_enabled.sql`
- `lib/domain/entities/user.dart`, `lib/data/models/user_model.dart` (+ regenerated `*.freezed.dart`/`*.g.dart`)
- `lib/data/datasources/local/biometric_auth_store.dart` (+ `test/data/datasources/local/biometric_auth_store_test.dart`)
- `lib/domain/repositories/auth_repository.dart`, `lib/data/repositories/auth_repository_impl.dart`, `lib/domain/usecases/auth/auth_usecases.dart`
- `lib/features/auth/presentation/auth_provider.dart`, `lib/features/auth/presentation/pages/login_page.dart`, `lib/features/splash/presentation/pages/splash_page.dart`
- `lib/l10n/app_en.arb`, `app_ar.arb`, `app_localizations*.dart`
- `test/data/models/user_model_test.dart`
