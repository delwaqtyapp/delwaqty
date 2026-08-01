# Sprint 57 Report — Location Reliability & Pending Feature Sync

**Date:** 2026-08-01
**Sprint:** 57
**Status:** Complete ✅
**Flutter SDK:** 3.44.6 (Dart 3.12.2)

---

## Goal

Fix the "الموقع غير متاح" bug (the app always showed location-unavailable even though the phone has real, fresh fixes) and commit the accumulated feature work from prior sessions (admin push notifications, username/profile, home polish) that had never been pushed.

## Root Cause

Sprint 21d's anti-stale fix was **over-corrected**. It required `satellitesUsedInFix > 0` (GNSS-only) plus ≤ 2 min freshness for EVERY accepted fix. On the DNP NX9:

- Network/fused fixes always carry `satellitesUsedInFix = 0` → rejected.
- The last real GPS fix was ~35 min old (`hAcc=40.2`, `satellites=6`) → older than 2 min → rejected.
- `dumpsys location` re-analysis proved `et=` is **elapsed-since-boot**, not fix age — the network/fused last-fixes were actually **~1 min old (FRESH)**.

Result: the Home header showed `الموقع غير متاح` forever instead of the user's real address.

## Deliverables

| # | Area | Change |
|---|------|--------|
| 1 | Freshness tiers | `_maxFixAge` = 2 min (live stream fixes); new `_maxLastKnownAge` = **10 min** (last-known usability). The 9-day replay protection is preserved — anything > 10 min old is still refused. |
| 2 | `_isUsableLastKnown` | New: accepts last-known ≤ 10 min old (−30 s skew). GNSS-verified positions always pass; **non-GNSS (network/fused) pass only if `0 ≤ accuracy ≤ 500 m`** → the fresh 100 m fused/network fix is now used instead of `الموقع غير متاح`. |
| 3 | `_acquirePreciseFix` | Fresh stream samples no longer require GNSS verification to accumulate as `best`; GNSS verification is required **only** for the ≤ target-meter (1 m) early-lock shortcut. `waitSeconds` = 45 only when deep AND no usable last-known, else 12 → deep lock no longer hangs. |
| 4 | `_bestAvailablePosition` | Returns fresh GNSS ≤ 1 m last-known immediately; quick mode returns a usable last-known without opening a stream; otherwise stream acquisition with usable-last-known fallback. |
| 5 | Tests | `location_provider_test.dart` grew 10 → **14 tests**: satellite-less network/fused stream sample accepted as fallback; fresh non-GNSS last-known accepted in quick mode; > 500 m non-GNSS last-known rejected; GNSS last-known up to 10 min old accepted; non-GNSS last-known older than 10 min rejected. |
| 6 | Bundled pending work | Admin **Push Notifications** page + `push_notification_service.dart` + Firebase Messaging background handler + `flutter_local_notifications`; **username** profile field + migration `017_add_username.sql` + image_picker avatar; Home unread-notifications badge + "اطلب طلبك مباشرة" CTA; floating sidebar restyle; `refreshQuick()` on Home header. |

## Files Touched

- `lib/features/location/presentation/providers/location_provider.dart` — freshness tiers, usable last-known, relaxed stream acquisition
- `test/features/location/presentation/providers/location_provider_test.dart` — 14 tests
- `lib/features/delivery/presentation/pages/direct_delivery_page.dart` — deep-lock location fill + accuracy snackbar + shopping list
- `lib/features/ride_booking/ride_booking_screen.dart` — deep-lock location fill
- `lib/features/home/presentation/pages/home_page.dart` — `refreshQuick()`, unread badge, direct-order CTA
- `lib/features/admin/presentation/pages/admin_push_notifications_page.dart` — **new**
- `lib/features/admin/admin_module.dart`, `admin_dashboard_page.dart` — push-notifications route + quick action
- `lib/services/push_notification/push_notification_service.dart` — FCM init, token, local notifications
- `lib/main.dart`, `lib/app/app.dart` — messaging background handler + service init
- `lib/data/models/user_model.dart` + freezed/g, `lib/domain/entities/user.dart` + freezed/g — `username`
- `lib/features/profile/presentation/pages/profile_page.dart` — username + avatar (image_picker)
- `lib/shared/widgets/primary_header_actions.dart` — **new**
- `lib/features/floating_sidebar/*` — restyle
- `lib/l10n/*` — location/profile/push keys
- `supabase/migrations/017_add_username.sql` — **new**
- `pubspec.yaml`/`pubspec.lock`, platform plugin registrants
- `SESSION_STATUS.md`, `docs/DECISION_LOG.md` (ADR-036)

## Quality Gates

| Check | Result |
|-------|--------|
| `flutter analyze` | 0 errors |
| `flutter test` | 531/531 passing |
| APK build | `app-debug.apk` rebuilt (debug, `.env.dev`) |
| Device install | Installed on DNP NX9 (`A3SQUT5A28003808`) |
| Device verification | Home header shows `شاليهات مارفيل، بلو باي اسيا، السويس، مصر` (NOT `الموقع غير متاح`); deep-lock `حدد موقعي` fills the deliver-to field with the same address |

## Decisions & Follow-ups

- **Decision:** the anti-stale property is "never show a location older than a bounded window", not "only show GNSS positions". The 10 min / 500 m bounds preserve the anti-replay guarantee while admitting the device's real fresh fixes. GNSS verification still gates the 1 m precision lock. See `docs/DECISION_LOG.md` ADR-036.
- `Follow-up (reality):` the ≤ 1 m deep-lock still requires **open sky** (live GNSS). Indoors (`avgBasebandCn0=18.7 dB-Hz`) it degrades to best fresh sample / usable last-known with an accuracy snackbar instead of nothing. Verify a true 1 m fix by stepping outside.
- `Follow-up (external):` Google Geocoding + Places still `REQUEST_DENIED` — enable/authorize the key in Google Cloud Console for Uber-grade POI names.
- `Follow-up (release):` `flutter build apk --release` when ready to ship.

**Commits:**
- `fe71dca` — sprint 57: fix over-strict location gate, accept fresh network fixes
- `2b52fbc` — sprint 57: add admin push notifications, username, home polish
- Pushed to `origin/master` (`d444fd6..2b52fbc`).
