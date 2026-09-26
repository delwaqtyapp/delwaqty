# Project Status — Handoff

> Updated 2026-09-26 · Round 57 · Sprint 197 · Pushed

## Current milestone (sprint 197): APK ≤ 70MB — MET
Customer debug APK: **220.6MB → 60.4MB slim** (arm64-only, Vulkan layer off, WebP assets, zipalign-padding repack). See ADR-109.

### How to build the slim APK now
```bash
./build.sh                        # debug customer → slims in place (SKIP_SLIM=true bypasses)
scripts/publish_ota.sh            # all 4 flavors arm64-only + slim each, then GitHub release
```

### Important codegen warning (ADR-109)
`dart run build_runner build` regenerates UNTRACKED `.g.dart` files as camelCase,
breaking the repo's snake_case API-row contract. After any codegen run, ALWAYS run:
```bash
flutter test test/features/home_services/snake_case_api_entities_test.dart
```
and if `service_category.g.dart` / `service_booking.g.dart` fail, reconstruct them
to snake_case matching the committed `service_provider.g.dart` (tolerant `?? ''`, unknown `category_type`→`other`).

## Sprint history (recent)
- **197**: APK size 220→60MB (arm64-only, VkLayer off, WebP, slim repack) + OTA progress% + About «البحث عن تحديث». ADR-109.
- **196**: OTA in-app self-update for all 4 apps. ADR-108.
- **195**: live chat-close propagation + actionable incoming calls. ADR-107.
- **194**: chat permissions panel, incoming-call notification, admin delete/close. ADR-106.
