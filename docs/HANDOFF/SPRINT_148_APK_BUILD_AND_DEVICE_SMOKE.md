# SPRINT 148 — APK Build Verification + Device Smoke Test (post-upgrade)

**Date:** 2026-09-06
**Status:** COMPLETE — committed `f49f87d` + build/device verification, pushed to `origin/master`
**Gates:** `flutter analyze` 0 errors / 0 warnings / **0 infos** · `flutter test` 918/918 · debug + release APK built · device smoke passed

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

## Files / artefacts
- `docs/HANDOFF/SPRINT_148_APK_BUILD_AND_DEVICE_SMOKE.md` — this report.
- `SESSION_STATUS.md` — milestone updated.
- `ROADMAP.md` — Lints row updated to 0/0/0 + device-build verification.
- APKs: `build/app/outputs/flutter-apk/app-customer-debug.apk`, `app-customer-release.apk`.

## Not done / backlog
- Signed **release** keystore flow — needs `KEYSTORE_PASSWORD` / `KEY_ALIAS` / `KEY_PASSWORD` from the user (current GPG debug-signed).
- Duplicate push-permission request race in `push_notification_service.dart` (pre-existing; non-fatal).