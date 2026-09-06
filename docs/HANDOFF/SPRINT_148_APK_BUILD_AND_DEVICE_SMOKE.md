# SPRINT 148 — APK Build Verification + Device Smoke Test (post-upgrade) + Release Signing

**Date:** 2026-09-06
**Status:** COMPLETE — commits `f49f87d` (docs), `bcb8fed` (handoff/roadmap), signing change (`sprint 148: add real release signing via key.properties`) pushed to `origin/master`
**Gates:** `flutter analyze` 0 errors / 0 warnings / **0 infos** · `flutter test` 918/918 · debug + release APK built · device smoke passed · **release APK signed with real `CN=Delwaqty` key**

---

## Summary

Closed out the two backlog items left from SPRINT 147: (1) reduced the 216 info-level lints to **zero**, and (2) verified the Android build pipeline end-to-end on the physical device (DNP NX9) after the Riverpod 3 / Freezed 4 / lints 6 stack upgrade.

## What changed (by category)

### Info-lint cleanup (216 → 0)
- **`dart fix --apply`** repaired **198 diagnostics in 68 files** automatically: `unnecessary_underscores` (116), `use_null_aware_elements` (37), `sort_constructors_first` (21), `avoid_redundant_argument_values` (13), `prefer_const_constructors` (5), `strict_top_level_inference` (4), plus dangling docs, unnecessary import/parenthesis, deprecated member use.
- **Manual fixes (18):**
  - `maps_service_impl.dart` — typed the `_calculateDistance` lat/lon parameters (`double`) → 4 `strict_top_level_inference`.
  - 14 `use_build_context_synchronously`:
    - `device_unlock_page.dart` — moved `AppLocalizations.of(context)` capture **before** the first `await`.
    - `admin_push_notifications_page.dart` (×2), `merchant_detail_page.dart`, `product_detail_bottom_sheet.dart` (×2) — `context.mounted` → State `mounted`.
    - `admin_profile_page.dart` (×3), `delivery_tracking_page.dart` (×2) — `mounted` → `context.mounted` (context is a **method parameter**, not State.context).
    - `checkout_page.dart` — added missing guard on the else-branch snackbar.
    - `admin_management_list_page.dart` — reused the dialog's `ctx` with `ctx.mounted` guard.
    - `location_sharing_page.dart` — added independent `if (mounted)` guard (compound `v && mounted` is not accepted).
- **Clean gate now:** 0 errors / 0 warnings / **0 infos**.

### Build pipeline verification
- **Debug APK:** `flutter build apk --debug --flavor customer --target lib/customer/main.dart --dart-define-from-file=.env.dev` → built in **48.4s**, installed on DNP NX9 (`A3SQUT5A28003808`).
- **Release APK:** same command with `--release` → built in **63.6s**, **66.2 MB**, no R8/dexing OOM. The historical dexing OOM backlog (`org.gradle.jvmargs=-Xmx6G`, `workers.max=2`) is **confirmed resolved**.
- Signature: **Android Debug cert** (expected — `KEYSTORE_PASSWORD` not set; `build.gradle.kts` falls back to debug signing, documented behaviour).
- `MAPS_API_KEY` env must be exported from `.env.dev` for the AndroidManifest placeholder (mirrors the runtime `GOOGLE_MAPS_API_KEY` dart-define).

### Device smoke test (DNP NX9 / Android 16 / arm64)
- App launched, process stable, **no FATAL / no Flutter exception**, splash → permission dialog → resumed activity.
- Logcat line of interest: `Auth event: AuthEventType.signedIn` — persisted session restored.
- Firebase Messaging background service started; Crashlytics/Analytics transport pushed successfully (Status 200) — network + Firebase init OK.
- **Minor pre-existing finding (not from this upgrade):** a duplicate Firebase messaging permission request race — `[firebase_messaging/unknown] A request for permissions is already running` logged from `push_notification_service.dart:192`. Non-fatal (fallback handled), but worth a follow-up to single-flight `requestPermission()`.
- One full `flutter test` run was killed externally mid-run at +753 (same external interference seen in earlier sprints); re-run passed **918/918**.

### Release signing (new — resolves the deferred item)
- App has **never been published to Google Play** (verified across all docs) → the old `release.jks` (2026-07-22, **password lost**, `Ed@20266` was tried and rejected by `keytool`) was replaced with a brand-new keystore — a fresh signing identity is safe pre-publication.
- **New keystore generated** with `keytool` (RSA 2048 / SHA256withRSA / validity 10,000 days → **2054**):
  - Alias `delwaqty`, DN `CN=Delwaqty, OU=Delwaqty, O=Delwaqty, L=Cairo, ST=Cairo, C=EG`
  - SHA-256 fingerprint `13:02:52:B0:CE:31:36:19:5D:1C:10:0C:72:9C:69:34:F1:FF:AF:8B:9F:04:DB:EF:05:97:DA:E6:8F:D2:64:ED`
  - Store/key password: the user's unified password (user-authorised) — stored ONLY in `android/key.properties` (**gitignored**, `**/key.properties` added), never committed.
- `android/app/build.gradle.kts` updated: loads `android/key.properties` first, falls back to `KEYSTORE_PASSWORD`/`KEY_ALIAS`/`KEY_PASSWORD` env; the `hasReleaseKey` gate now honours the properties file too. The old behaviour (silent debug-signing fallback) is kept only when neither source provides a password.
- Old keystore backed up outside the repo: `%TEMP%\opencode\release_old_20260722.jks` (unuseful — password unknown).
- **Verified end-to-end:** `apksigner verify --print-certs` → `Signer #1 certificate DN: CN=Delwaqty, ...`, SHA-256 digest matches the keystore. Signed release APK **installed on DNP NX9** (debug-signed copy uninstalled first — signature mismatch expected), app ran in foreground, no crash.
- Signing passwords / keystores are **never visible on Google Play**; only the certificate fingerprint is shown in Play Console's App signing section for the developer (end users see nothing). Play uses the key to accept updates (same app identity) and to prevent re-uploads by others.

## Files / artefacts
- `docs/HANDOFF/SPRINT_148_APK_BUILD_AND_DEVICE_SMOKE.md` — this report.
- `SESSION_STATUS.md` — milestone updated.
- `ROADMAP.md` — Lints row updated to 0/0/0 + device-build verification.
- APKs: `build/app/outputs/flutter-apk/app-customer-debug.apk`, `app-customer-release.apk`.

## Not done / backlog
- **Before first Play upload:** enable **Google Play App Signing** so Google hosts the key — then a lost local keystore no longer kills the app identity.
- Duplicate push-permission request race in `push_notification_service.dart` (pre-existing; non-fatal).