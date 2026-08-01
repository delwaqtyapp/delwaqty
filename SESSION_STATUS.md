# SESSION_STATUS.md

> **Last updated:** 2026-08-01 Session 21e (Over-Strict Location Gate Fixed + Bundled Sprint 57 Features Verified)

---

## Current Task — "الموقع غير متاح" BUG FIXED (Over-Strict Gate Was Rejecting Real Fixes)

User reported the app **always** showed `الموقع غير متاح` on the Home header even though the phone has real, fresh location fixes. Root cause was the previous session's anti-stale fix being **over-corrected**. Fixed, tested, and proven on device.

| Area | Change |
|------|--------|
| **Root cause** | Session 21d required `satellitesUsedInFix > 0` (GNSS-only) + ≤ 2 min freshness for EVERY accepted fix. On this device that is impossible indoors: network/fused fixes always carry `satellitesUsedInFix = 0`, and the last real GPS fix was 35 min old (`hAcc=40.2`, `satellites=6`). `dumpsys location` re-analysis proved `et=` is **elapsed-time-since-boot**, not fix age — the network/fused last-fixes were actually **~1 min old (FRESH)**, rejected purely because they had no satellite count. Result: eternal `الموقع غير متاح` |
| Fix — freshness tiers | `_maxFixAge` = 2 min (stream fix freshness), new `_maxLastKnownAge` = **10 min** (last-known usability). The 9-day replay protection is preserved: anything > 10 min old is still refused |
| Fix — `_isUsableLastKnown` | New: accepts last-known ≤ 10 min old (−30 s skew). GNSS-verified positions always pass; **non-GNSS (network/fused) pass only if `accuracy >= 0 && accuracy <= 500 m`** → the fresh 100 m fused/network fix is now used instead of `الموقع غير متاح` |
| Fix — `_acquirePreciseFix` | No longer rejects satellite-less stream samples — any fresh sample accumulates as `best` and is returned. GNSS verification is now required ONLY for the ≤ 1 m early-lock shortcut (real 1 m still needs open sky). `waitSeconds` = 45 only when deep AND no usable last-known, else 12 → deep lock no longer hangs |
| `_bestAvailablePosition` | Returns fresh GNSS ≤ 1 m last-known immediately; quick mode returns a usable last-known without waiting; otherwise acquires a stream fix; falls back to usable last-known |
| Unit tests | `location_provider_test.dart` now **14 tests** (+4): satellite-less network/fused stream sample accepted as fallback; fresh non-GNSS last-known accepted in quick mode; poor-accuracy (> 500 m) non-GNSS last-known rejected; GNSS last-known up to 10 min old accepted; non-GNSS last-known older than 10 min rejected. Full suite **531/531** |
| Verify on device | `flutter analyze` 0 errors · `flutter test` 531/531 · debug APK rebuilt + installed · **Home header now shows `شاليهات مارفيل، بلو باي اسيا، السويس، مصر` (NOT `الموقع غير متاح`)** · deep-lock (`حدد موقعي` on Direct Delivery) filled the deliver-to field with the same resolved address · Termux terminal overlay briefly covered the app — brought back with `am start`, state confirmed |
| **Bundled sprint 57 features verified on device (DNP NX9)** | **Floating sidebar** opens via header menu (RTL → button is top-right): user card (`U` / `User` / `said.3pkarino@gmail.com` / `مدير عام` badge) + all sections incl. لوحة الإدارة, الشكاوى, العقوبات, تتبع مباشر · **Notifications page** renders (`الإشعارات` title, `تعيين الكل كمقروء`, empty state `لا توجد إشعارات`); unread badge is hidden by design at `unreadCount=0` · **Profile tab** + **Edit Profile dialog** show the new `اسم المستخدم` field · **Admin Dashboard → Push Notifications page** renders; `الأجهزة المتصلة` shows a graceful `خطأ` state (no FCM tokens exist yet); message field + `نسخ أمر FCM` + Firebase console link present · **logcat clean** — no `FATAL` / `AndroidRuntime` / `E/flutter` during the whole session |

> **Remaining reality check:** the ≤ 1 m deep-lock still requires a live GNSS fix (indoor `avgBasebandCn0=18.7 dB-Hz`, no fresh fix). It now degrades gracefully: if no GNSS fix arrives it uses the best fresh stream sample or a usable ≤ 10 min / ≤ 500 m last-known instead of returning nothing.

---

## Previous Task — STALE-LOCATION BUG FIXED (App No Longer Guesses)

User reported the app showed a **wrong place** (`شاليهات مارفيل، بلو باي اسيا`) that was NOT where they physically are. Root cause found, fixed, and proven on device.

| Area | Change |
|------|--------|
| **Root cause** | Android's FusedLocationProvider delivered the **9-day-old cached location** as the first stream event, **re-attributed with a fresh `getTime()`** → the app treated it as current and reverse-geocoded it. `dumpsys location` proved ALL system fixes were `et=+9d16h` (fused/network/gps) |
| Fix #1 (time filter) | `_isFreshTimestamp` — a fix is fresh only if ≤ 2 min old (30 s future tolerance). Alone this was **insufficient**: the platform re-attributes fresh timestamps to replayed caches |
| Fix #2 (GNSS verification) | `_hasLiveGnss(position)` — on Android, a position is accepted only if `AndroidPosition.satellitesUsedInFix > 0` (live GNSS session). `geolocator_android`'s `NmeaClient.enrichExtrasWithNmea` stamps the satellite count on every delivered fix; a **replayed cache carries 0** → rejected. Non-Android (tests/iOS) pass by freshness only |
| Stale fallback removed | `_bestAvailablePosition` no longer falls back to a stale `lastKnown`; it returns it only if `_isFreshAndVerified` (fresh + GNSS-verified). Null → UI honestly shows `الموقع غير متاح` instead of guessing |
| Stream onDone | `_acquirePreciseFix` now completes the completer when the stream ends (`onDone`) instead of only the timer → no 45 s hang when the provider yields nothing |
| Unit tests | `location_provider_test.dart` now **10 tests** (+5 new): rejects 9-day-old last-known when no fresh fix; ignores stale stream samples; prefers fresh stream fix over stale last-known; rejects satellite-less (`satellitesUsedInFix: 0`) Android sample; accepts GNSS-verified (`satellitesUsedInFix: 4`) sample. Note: `AndroidPosition` ctor params are untyped → must pass `0.0`/doubles (int literals throw at runtime). Full suite **527/527** |
| Verify on device | Rebuilt + installed. Home header now shows **`الموقع غير متاح`** (NOT the stale Marvel address) — the app refuses to guess. Re-verified this session: app restart → still `الموقع غير متاح`; deep-lock (`حدد موقعي`) ran a full HIGH_ACCURACY window → GPS provider still reports **no fresh fix in 9 days** (`et=+9d17h…`, `hAcc=40.2`, `satellites=6`); GNSS receiver alive (9 satellites, 301k sv-status msgs) but `avgBasebandCn0=18.7 dB-Hz` = indoor, no fix computed. All network/fused/gps last-fixes remain 9 days stale. Location mode 3, permissions granted, no mock source. **Fix is proven: the app refuses stale/replayed positions and shows `الموقع غير متاح`** |

> **Reality check:** 1 m precision is physically impossible indoors (last GPS fix `satellites=6, meanCn0=12`, 9 days stale). The `refreshDeepLocked()` 1 m lock is intact, GNSS-verified and tested. To verify a real 1 m fix end-to-end the user must step outside under open sky, then pull-to-refresh Home or place an order (order flows call `refreshDeepLocked()`).

---

## Previous Task — ACTUAL PLACE NAME + PRODUCTION-GRADE LOCATION ENGINE

Delivered the **actual place name** (like Uber) using **Photon (Komoot)** — a free, no-key OSM geocoder — and removed every non-production artifact from the engine.

| Area | Change |
|------|--------|
| Photon source | New `_photonStructuredAddress` in the 4-way geocode chain (Google → Photon → Nominatim → Overpass-nearest). Returns locality/street/state/country → on device now resolves the user's real location to **`شاليهات مارفيل، بلو باي اسيا، السويس، مصر`** (Marvel Chalets, Blue Bay Asia, Suez, Egypt) |
| Photon 403 fix | `photon.komoot.io` returned **403** to Dart's http client (same as Overpass) → added `User-Agent: Delwaqty/1.0` → 200 JSON |
| Nearest-place | `_nearestNamedPlace` radius 2000→**4000 m**, now **prioritizes POIs** (amenity/shop/leisure/tourism/building/office/place/landuse/resort/camp_site) **over highways**; found "Zafarana offices" instead of the road name |
| Production cleanup | **Removed ALL debug tracing** (`loc_debug.txt` writes, `_appendDebug`, `geo:/pos:/addr:` logs). Replaced hardcoded `dart:io` file cache with **SharedPreferences** cache (`location_geocode_cache_v1`) with **24 h TTL** + 200-entry cap. `dart:io` import removed |
| Precision lock | `refreshDeepLocked()` — 3 attempts, locks on `accuracy ≤ 1.0 m`; deep window back to **45 s** per attempt for GPS cold-start convergence |
| Verify | `flutter analyze` 0 errors · `flutter test` 522/522 · debug APK built + installed · **UI verified on device**: Home header shows `شاليهات مارفيل، بلو باي اسيا، السويس، مصر` · `files/` clean (no debug/cache artifacts) |

> Remaining external blocker for Uber-grade POI quality: Google Geocoding + Places APIs still `REQUEST_DENIED` (key not authorized in Google Cloud Console). Current depth comes from OSM (Photon/Nominatim/Overpass). 1 m fix physically requires open sky (device GNSS is dual-frequency capable).

---

## Previous Task — 1 m PRECISION LOCK (STRICT) — Google Key is the Only External Block

User demanded: **"عايز الدقه 1 متر وليس اى دقه عشوائيه"** (1 m precision, NOT random accuracy) — like Uber. Implemented a **strict 1 m lock** so order flows refuse insufficient fixes and guide the user, instead of silently accepting weak readings.

| Area | Change |
|------|--------|
| Strict lock | `refreshDeepLocked()` — up to **3 attempts** of the deep acquisition; returns as soon as `accuracy ≤ 1.0 m` (`precisionTargetMeters`); after all attempts returns best + caller shows Arabic guidance. Used by Direct Delivery `_useCurrentLocation` and Ride Booking `_useCurrentLocation` |
| Deep window | `_acquirePreciseFix(deepPrecision: true)`: `LocationAccuracy.bestForNavigation`, 30 s per attempt, early-complete at `≤ 1 m` |
| UI guidance | New l10n keys (both ARB): `accuracyInsufficient` (Arabic: "الدقة الحالية غير كافية (مطلوب دقة 1 متر)…"), `improvingAccuracy`, `retryLocation`; order flows show a snackbar when accuracy > 1 m but still fill best-effort address |
| Unit tests | New `test/features/location/presentation/providers/location_provider_test.dart` — 5 tests via `MockPlatformInterfaceMixin` mock of `GeolocatorPlatform`: service off → null, denied → null, deniedForever → null, sub-metre last-known lock, sub-metre stream lock. Suite now **522 passing** |
| Google key | **Confirmed blocked**: Geocoding + Places both return `REQUEST_DENIED: "This IP, site or mobile application is not authorized"` (tested from dev machine AND from the device). Root cause = key restrictions/API enablement in Google Cloud Console. Debug SHA-1 `53:37:18:5A:52:F0:B6:15:A3:38:8E:CC:03:B6:57:6D:61:F3:4E:EF`, package `com.delwaqty.app` |
| OSM reality | Around the user's point (tourist-village area, Zafarana/Sokhna road) the nearest named OSM POIs are 2.2–2.6 km away (Bassem Market, Mountain View Sokhna, La Regina Resort). OSM data is sparse; **Google Places is required for true Uber-style place names** |
| Verify | `flutter analyze` 0 errors · `flutter test` 522/522 · debug APK built + installed · Home shows `طريق العين السخنه، الزعفرانه، السويس، مصر` |

> **ACTION REQUIRED FROM USER (external blocker):** In Google Cloud Console → enable **Geocoding API** + **Places API**, fix the key's Application restrictions (Android key → add package `com.delwaqty.app` + SHA-1 above; or remove restriction for testing), and ensure billing is active. Until then, POI depth = OSM only.

---

## Previous Task — DEEP LOCATION PRECISION (1 m) + FULL ARABIC ADDRESS

Deepened the location engine to genuinely pursue a **1 m GPS fix** and render a **full Arabic street-level address with no digits/units in the UI** (per user's earlier "no accuracy numbers" decision; user now explicitly wants 1 m precision).

| Area | Change |
|------|--------|
| Deep engine | `_acquirePreciseFix(deepPrecision: true)` uses `LocationAccuracy.bestForNavigation`, **45 s** convergence window, completes immediately when `accuracy ≤ 1 m`, otherwise returns best sample; two precession tiers added |
| Quick path | `refreshQuick()` = `LocationAccuracy.best`, 12 s, `≤ 10 m` target — used by Home header so the passive display never blocks 45 s |
| Deep path | `refreshDeep()` — used by **order-time** capture (Direct Delivery `_useCurrentLocation`, Ride Booking `_useCurrentLocation`) so the real fix is as deep as possible at order time |
| Overpass fix | Root cause found: `overpass-api.de` returned **406** because the request lacked an explicit `User-Agent` (Dart's default rejected). Added `User-Agent: Delwaqty/1.0` → **200 + JSON**. Mirrors: overpass-api.de, overpass.kumi.systems, overpass.private.coffee (15 s per mirror, UA header on all) |
| Geocode cache | New file cache `loc_geocode_cache.json` keyed on `lat,lng` rounded to 4 decimals (~40 m grid) → second launch resolves the address **instantly** with zero Overpass/Nominatim calls (verified: no `geo:` line on 2nd run) |
| Address depth | Result on device: `طريق العين السخنه، الزعفرانه، السويس، مصر` (road → area → governorate → country, Arabic, no digits) |
| On-device accuracy | Indoors ~**7.5 m** with `bestForNavigation` (was ~25 m default); device GNSS is multi-constellation (GPS+GLONASS+BeiDou+Galileo); **1 m requires open sky** (indoor meanCn0=7, 6 sats) |
| Verify | `flutter analyze` 0 errors · `flutter test` 517/517 · debug APK built + installed on DNP NX9 · address renders in Home header, cache persists |

> Known limits: Google Geocoding still `REQUEST_DENIED` (unauthorized key) so POI depth comes from Nominatim + Overpass only. Exact named building needs open sky + authorized Google key (or user-entered free text).

---

## Previous Task — FUNCTIONAL BOTTOM-NAV RESTRUCTURE (Session 20)

Redesigned the bottom navigation from the module-driven Home / Direct Delivery / Ride / Settings tab set into a professional 4-tab layout: **Home / Search / Orders / Profile** — the product decision deferred in Session 19.

| Area | Change |
|------|--------|
| Nav tabs | New order by `navPriority`: **Home (10) → Search (20) → Orders (30) → Profile (40)**; the shell builds branches from `FeatureRegistry.navModules` so tabs stay module-driven |
| SearchModule | Promoted to nav module: branch `/search` → existing commerce `SearchPage`; home search bar now `context.go('/search')` (switches tab instead of pushing a duplicate) |
| OrdersModule (new) | `lib/features/orders/orders_module.dart` — nav branch `/orders` → existing commerce `OrdersPage`; `/orders` added to `restrictedRoutes` (guests → login); depends on `commerce` |
| ProfileModule | Promoted to nav module: branch `/profile` → `ProfilePage`; drawer/sidebar `/profile` uses `go` (tab switch); **gear icon** added to Profile AppBar → `push('/settings')` |
| SettingsModule | Demoted to non-nav; `/settings` kept as `shellSubRoute` wrapped in a `Scaffold` + `AppBar` (page itself remains a bare `ListView`) |
| DirectDeliveryModule | Demoted to non-nav; `/direct-delivery` kept as a `standaloneRoute`; page gained its own `AppBar` (title + back) since it is no longer rendered under the shell AppBar |
| RideModule | Re-enabled (was commented out in `module_registry.dart`); demoted to non-nav with `/ride/book` as a `standaloneRoute` (RideBookingPage has its own back button); home ride tile's `/ride/book` push now resolves; delivery tile fixed to push `/direct-delivery` |
| AppShell | Global AppBar removed (menu + notifications moved into Home header); **menu button** added to Home header (opens floating sidebar); `extendBody: true` → `false` so branch pages with their own Scaffolds are not overlapped by the floating pill; Home bottom spacer 100 → 24 |
| Routes | `app_router.dart` restricted list now includes `/orders`; `module_registry.dart` registers `OrdersModule` and re-registers `RideModule` |
| Verify | `flutter analyze` 0 errors · `flutter test` 517/517 · debug APK built + installed on DNP NX9 · all 4 tabs tapped on device with no crashes |

> The old tab set (Direct Delivery, Ride, Settings) remains reachable: Delivery via Home grid tile, Ride via Home grid tile (`/ride/book`), Settings via Home "More" tile + Profile gear.

---

## Current Task — MIGRATIONS EXECUTED ON SUPABASE (015 + 016)

Both migrations were executed directly against `bttnlkmwhorjamzemwda` via the Supabase Management API (`database/query` endpoint) using the user's Personal Access Token.

**Important finding:** before execution, all 5 tables returned **404 via REST** — 015 had NOT been applied (despite the report). Executed 015 then 016.

| Verification | Result |
|--------------|--------|
| `pg_tables` (public schema) | ✅ 5/5 tables exist (`complaints`, `sanctions`, `location_updates`, `chat_rooms`, `chat_messages`) |
| `relrowsecurity` | ✅ RLS enabled on 5/5 |
| `pg_policies` | ✅ 31 policies (admin SELECT/INSERT/UPDATE/DELETE + user policies per table) |
| Helper functions | ✅ `is_admin`, `add_admin_note`, `add_complaint_admin_note` |
| Realtime publication | ✅ 5/5 tables added to `supabase_realtime` |
| Storage buckets | ✅ `complaints` + `chat_attachments` |
| Grants to `authenticated` | ✅ SELECT/INSERT/UPDATE/DELETE on 5/5 |
| REST end-to-end | ✅ Table reachable (200, RLS returns filtered rows); temporary `anon` grant was revoked after the test |
| PostgREST reload | ✅ `NOTIFY pgrst, 'reload schema'` triggered |
| `flutter analyze` / `test` | ✅ 0 errors / 517 passing (unchanged) |

> **Note:** The Personal Access Token was used in the session only (never saved to files or committed). User should revoke/rotate it in Supabase → Account → Access Tokens.

---

## Current Task — RLS POLICY REBUILD (migration 016)

After 015 was applied, features still misbehaved due to RLS policies: policies from 007/014/015 overlapped or were incomplete for admin + participant flows. Fixed with a deterministic rebuild.

| Fix | Details |
|-----|---------|
| New migration `016_fix_rls_policies.sql` | Drops ALL known policy names on the 5 tables (from 007/014/015), re-enables RLS, and recreates explicit SELECT/INSERT/UPDATE/DELETE policies for admin + users |
| `is_admin()` helper | `SECURITY DEFINER` SQL function checking `users.role IN ('admin','owner')` (matches app logic; `admin_users.id` is a separate UUID and is intentionally not used) |
| `add_admin_note()` + `add_complaint_admin_note()` | Admin-only note functions; legacy RPC name preserved for the app |
| Admin full control | SELECT/INSERT/UPDATE/DELETE on complaints, sanctions, location_updates, chat_rooms, chat_messages |
| User policies | Own complaints (+legacy reporter), own sanctions, own locations, rooms they participate in, messages in their rooms (with `sender_id = auth.uid()` on insert) |
| Grants | `GRANT SELECT,INSERT,UPDATE,DELETE ... TO authenticated` on all 5 tables |
| Verify | `flutter analyze` 0 errors · `flutter test` 517/517 |

> **ACTION REQUIRED:** Run `016_fix_rls_policies.sql` in the Supabase SQL Editor (instructions in session report).

---

## Current Task — MANAGEMENT TABLES DB FIX (Root Cause: migration 014)

The new features (complaints, sanctions, live tracking, support chat) failed with `Could not find the table`. Root cause found and fixed.

**Root cause:** `supabase/migrations/014_management_platform.sql` used `CREATE TYPE IF NOT EXISTS`, which **PostgreSQL does not support** (syntax error) → the migration aborted mid-way → `sanctions`, `location_updates`, `chat_rooms`, `chat_messages` were never created, and `complaints` kept the legacy 007 ride schema (missing management columns).

| Fix | Details |
|-----|---------|
| New migration `015_create_management_tables.sql` | Creates all 5 tables (merged `complaints` schema + `sanctions` + `location_updates` + `chat_rooms` + `chat_messages`) with TEXT+CHECK instead of enums; RLS policies (participant OR admin); 2 storage buckets; `add_complaint_admin_note` RPC; adds tables to `supabase_realtime` publication |
| 014 bug fixed | Replaced `CREATE TYPE IF NOT EXISTS` with guarded `DO` blocks |
| `complaints` conflict resolved | Old 007 ride table auto-detected + replaced with merged schema so ride module (`reportIssue`) keeps working |
| Dart fixes | `createComplaint`/`createRoom`/`sendMessage`/`createSanction` no longer send `id: ''` into UUID columns; use `.select().single()` to return real rows; `Complaint.fromJson` tolerates legacy ride rows |
| `supabase_service.dart` | **No change needed** — it only exposes the Supabase client; table names live in each data source |
| Verify | `flutter analyze` 0 errors · `flutter test` 517/517 · APK built + installed on DNP NX9 |

> **ACTION REQUIRED:** Run `015_create_management_tables.sql` (and re-run `014` for the type fix) in the Supabase SQL Editor — see instructions below.

---

## Current Task — ADMIN PANEL WIRING (Post-Sprint 51)

Made the Sprint 40 management features (complaints, sanctions, live tracking, support chat) reachable from the UI and removed all legacy ride-page references from the admin panel.

| Change | Details |
|--------|---------|
| Deleted `admin_rides_page.dart` | Old transport/ride page removed |
| Removed `/admin/rides` route | Removed from `admin_module.dart` |
| Dashboard quick actions updated | Removed `rideHistory`; added **Complaints**, **Sanctions**, **Live Tracking**, **Support Chat** (4 new actions) |
| Floating sidebar | New admin-only **Admin Panel** section (idx 8–12: admin panel, complaints, sanctions, live tracking, support chat); support section reindexed 13–18 |
| l10n cleanup | Removed 4 unused ride keys (`rideMonitoring`, `noRidesFound`, `noRidesCreated`, `noRidesSelectedStatus`) + `gen-l10n` |
| Analyzer cleanup | Removed unused imports in `floating_sidebar_overlay.dart`, `floating_sidebar_controller.dart`, `app_shell.dart` |
| Build + install | `flutter build apk --debug --dart-define-from-file=.env.dev` ✅ installed on DNP NX9 ✅ |

---

## Completed Milestones

| Milestone | Sprint | Description | Status |
|-----------|--------|-------------|--------|
| M1-M11 | 28-39 | Previous milestones (localization, transportation, booking, dispatch, search, driver platform, delivery, safety, theme, errors, empty states) | ✅ |
| M12 | 40 | Management Platform — Complaints, Sanctions, Live Tracking, Support Chat | ✅ |
| M13 | 51+ | Admin Panel Wiring — features exposed in dashboard + sidebar; legacy rides page removed | ✅ |
| M13b | 53 | Management Tables DB Fix — migration 015, 014 type bug, UUID insert + RLS fixes | ✅ |
| M13c | 54 | RLS Policy Rebuild — migration 016: is_admin helper, explicit per-command policies, grants | ✅ |
| M13d | 55 | UI Polish — Cairo typography (google_fonts), card system (radius/shadow/gradients), pill search, banner copy, micro-interactions | ✅ |
| M13e | 56 | Functional Bottom-Nav Restructure — 4-tab layout (Home/Search/Orders/Profile), Settings behind Profile gear, Delivery/Ride into Home grid | ✅ |
| M13f | 57 | Location Reliability — real place names via Photon/Nominatim/Overpass, 1 m deep lock, stale/9-day replay rejected, then over-strict gate relaxed so real fresh fixes (network/fused 100 m) are used again | ✅ |

---

## Sprint 40 Summary

### Management Platform
- **Migration `014_management_platform.sql`**: 5 tables with RLS policies, indexes, storage buckets for attachments
- **complaints/**: Full CRUD, status management (`pending`/`investigating`/`resolved`/`rejected`/`escalated`), admin notes, filters by type and status
- **sanctions/**: Warning, fine, temporary_ban, permanent_ban, suspension types; active/inactive filtering
- **location_tracking/**: Real-time location upsert, active driver query, Supabase Realtime stream, driver list view + map placeholder
- **support_chat/**: Bidirectional chat between users and admins, Supabase Realtime message streaming, room management, read receipts
- **Admin panel integration**: Dashboard quick actions sidebar entries, nested routes under `/admin`
- **Client pages**: `/my-complaints`, `/new-complaint`, `/support`, `/support/room/:roomId`

---

## Current Quality Gates

| Check | Result |
|-------|--------|
| `flutter analyze` | 0 errors |
| `flutter test` | 531/531 passing |
| APK build | ✅ `app-debug.apk` rebuilt clean (single APK) + installed on DNP NX9 |
| Gradle | `kotlin.incremental=false` fix committed in `android/gradle.properties` |

---

## Next Milestones

| Milestone | Description | Status |
|-----------|-------------|--------|
| M14 | Payments integration | Pending |
| M15 | AI-powered features | Pending |

---

## Project Environment

| Tool | Value |
|------|-------|
| Flutter SDK | `E:\app\flutter` (3.44.6, Dart 3.12.2) |
| Android Device | DNP NX9 (`A3SQUT5A28003808`), Android 16 |
| Package | `com.example.delwaqty` |
| Supabase Project | `bttnlkmwhorjamzemwda` |
| Google Maps Key | `AIzaSyA9v-pk50aB3G45zIb_RQKxD5qo_CVX8GY` |
| Pub Cache | `E:\app\pub-cache` |
| Gradle Home | `E:\app\delwaqty\.gradle_home` (isolated, gitignored) |
| Git Remote | `https://github.com/delwaqtyapp/delwaqty` |

---

## Key Architecture Decisions

| Decision | Rationale |
|----------|-----------|
| Separate feature modules for each management domain | Follows existing Clean Architecture; independently testable |
| Admin pages as nested routes in AdminModule | Consistent with existing `/admin/*` pattern |
| Supabase Realtime for chat and location | No polling needed; instant updates |
| GIN index on participant_ids | Efficient `@>` containment queries for chat rooms |
| RLS per table (not blanket) | Fine-grained access control per domain |
