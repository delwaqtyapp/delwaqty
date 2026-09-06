# SPRINT 147 — Riverpod 3 + Freezed 4 + Lints 6 Major Upgrade

**Date:** 2026-09-06
**Status:** COMPLETE — committed `1f80550` (sprint 147), pushed to `origin/master`
**Gates:** `flutter analyze` 0 errors / 0 warnings (216 infos) · `flutter test` 918/918

---

## Summary

Major-version upgrade of the state-management + codegen + lint stack, applied source-first across the whole monorepo, then regenerated all outputs and re-verified end-to-end.

| Package | Before | After |
|---|---|---|
| flutter_riverpod | ^2.5.1 | **3.4.3** |
| freezed | ^2.5.2 | **4.0.1** |
| freezed_annotation | ^2.4.1 | **3.1.0** |
| json_annotation | ^4.9.0 | **4.12.0** |
| json_serializable | ^6.8.0 | **6.14.1** |
| flutter_lints | ^3.0.0 | **6.0.0** |
| build_runner | ^2.4.9 | >=2.15.3 <2.16.0 |
| riverpod_lint | — | **3.1.9** (analysis_server_plugin) |
| flutter_gen_runner | — | **5.15.0** (+ top-level `flutter_gen`) |

## What changed (by category)

### Source migration (93 files)
- **92 freezed classes** → `abstract class X with _$X` (Freezed 4 generated mixins have abstract getters, no bodies). `sealed class Failure` left intact.
- **22 `.valueOrNull` → `.value`** across 15 files (getter removed in Riverpod 3).
- **12 files** gained `import 'package:flutter_riverpod/legacy.dart';` (StateNotifier/StateProvider/StateController/ChangeNotifierProvider + families).
- **7 module files** gained `import 'package:flutter_riverpod/misc.dart';` (Override/ProviderBase/Family/Refreshable).
- **`AutoDisposeFamilyAsyncNotifier` removed in Riverpod 3** → migrated:
  - `RestaurantMenuNotifier` (restaurant_menu_page.dart) → `AsyncNotifier<MenuState>` + `merchantId` constructor arg; provider `AsyncNotifierProvider.autoDispose.family<RestaurantMenuNotifier, MenuState, String>((id) => RestaurantMenuNotifier(id))`.
  - `RestaurantReviewsNotifier` (restaurant_reviews_page.dart) → same pattern.
- **`whenOrNull` on AuthState** requires the direct `auth/domain/auth_state.dart` import (extension scope) → added to `change_password_page.dart` + `fingerprint_login_page.dart`.
- **Test file** `admin_region_scope_page_test.dart` → `Override` now via `flutter_riverpod/misc.dart`.

### Warning cleanup (21)
Unused imports (app_constants ×3, order.dart, dart:math, flutter_riverpod), unused locals (×6), `unawaited_return_in_try_block` (×4, added `await`), one unnecessary `!`, one unused `_geocodingApiUrl` const.

### Config / metadata
- `analysis_options.yaml`: `plugins:` is a **map** (`riverpod_lint: 3.1.9`), not a list; analyzer excludes added (build/android/ios/web/windows/macos/linux + generated).
- `pubspec.yaml`: top-level `flutter_gen` section (line_length 80, `integrations.lottie: true`).
- Regenerated `pubspec.lock` + `.dart_tool/package_config.json` → flutter_riverpod-3.4.3, riverpod-3.4.3, freezed-4.0.1, riverpod_lint-3.1.9.
- build_runner 2.15.3: `--delete-conflicting-outputs` flag removed (ignored with warning).

## Important operational notes for future sessions

1. **`.dart_tool` regeneration is mandatory** after any pubspec edit: delete `.dart_tool`, `flutter pub get`, `build_runner build`. Otherwise `package_config` silently resolves old 2.x packages and analysis yields hundreds of false `uri_does_not_exist` / `redirect_to_non_class` errors.
2. **Intermittent external reverts (witnessed this sprint).** An unknown process reverted the working tree repeatedly: a `git reset` (reflog 12:26), batch file rewrites at 14:51, and deletion of all `*.freezed.dart`/`*.g.dart` + reversion of `pubspec.*` at ~15:19; `AdobeCollabSync` process start time correlates with the first reset. **Mitigations that worked:** apply edits in one fast batch, verify immediately, commit as soon as the gate passes. **If the tree looks reverted:** `git reset --hard 1f80550` (or `git stash`) — do NOT redo the patch work from scratch.
3. `flutter analyze` prints 216 infos from the new lints (riverpod_lint + flutter_lints 6). Build gate treats infos as non-blocking per current scripting.

## Verification

- `flutter pub get` ✓
- `flutter pub run build_runner build` ✓ (163 outputs, 58s)
- `flutter analyze` → **0 errors, 0 warnings**, 216 infos ✓
- `flutter test` → **918/918 passed** ✓
- `git log` → `1f80550 sprint 147: upgrade riverpod 3.4.3 + freezed 4.0.1 + lints 6 (0 errors, tests pass)`; `HEAD == origin/master` ✓

## Not done / backlog

- 216 info-level lints (style/plugin) — candidate for a polish sprint; not blocking per gate.
- Android APK OOM at dexing (`org.gradle.jvmargs=-Xmx6G`) — independent dev-ops backlog item; unchanged.
- Device smoke-test of the four apps with the migrated stack (`flutter run --dart-define-from-file=.env.dev`) — deferred; compile + tests green.