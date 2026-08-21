# SESSION_STATUS.md

> **Last updated:** 2026-08-21 Session 68 — **SPRINT 96: BIOMETRIC LOGIN FIX + MASS ARABIC ENCODING REPAIR** — Two root causes fixed and verified live on device (DNP NX9). (1) Fingerprint login failed in both apps with `LocalAuthException(uiUnavailable, The current Activity must be a FragmentActivity)` because `MainActivity` extended `FlutterActivity` → switched to `FlutterFragmentActivity` (shared, both flavors); stale `FlutterSecureStorage.xml` (old debug-signing keystore) deleted and recreated. Verified: admin login-page prompt → scan → `authenticate result: true` → dashboard. Customer app verified with splash auto-login (fingerprint prompt at startup) + login-page fingerprint button; layout changed per user: guest button removed, register link moved up, fingerprint button below it. (2) User reported "اللغه العربى وحاجات كتير باظت" — root cause: sprint-91 monorepo restructure commit re-saved ~350 files with UTF-8-BOM and mojibake (Arabic UTF-8 bytes decoded as Windows-1252 then re-encoded as UTF-8; e.g. `Ø§Ù„Ù‚Ø±ÙŠØ¨Ø©` instead of القريبة). Fixed programmatically: 396 lines across 53 files (lib + supabase migrations + tests + ROADMAP.md) recovered via Windows-1252→UTF-8 round-trip (zero lossy chars — verified hex-perfect); 13 legit Latin-1 lines (—, °) skipped; 352 BOMs stripped. Verified live: customer home page tabs (القريبة/موصى لك/الأشهر), admin dashboard (مركز القيادة, إجمالي المستخدمين, المتاجر النشطة, التوثيقات المعلقة) all correct Arabic.

---

## Current Task — SPRINT 101: INDEPENDENT DELWAQTY PROVIDER APP (extraction milestone 1) — IN PROGRESS

**Status: Real, independent Provider app created and building.** `lib/provider/{main,app,app_router,module_registry}.dart` + `provider` Android flavor (`com.delwaqty.provider`). Provider APK builds green; all four apps (Customer/Admin/Driver/Provider) build; **891/891 tests pass**; 0 analyze errors.

**What was done (Phases 1–5, 15, 29, 30, 31)**
- **Audit (1–4):** mapped provider supply-side code. Provider OPERATIONAL UI is concentrated in `lib/features/customer/merchant/**` (`MerchantModule`: `/merchant-dashboard` + orders/products/offers/branches/reservations/reviews) plus the orphaned delivery `MerchantOrdersPage`. `restaurant`/`commerce` modules are CUSTOMER BROWSING but their repos/entities are required by merchant pages (so their MODULES are registered). Home-services has no provider mgmt UI yet (repos exist). Wallet + ServiceAudioLogs reusable.
- **Provider app (5):** created `lib/provider/*` — `registerProviderModules()` registers Splash/Onboarding/Welcome/Auth/Regions/Complaints/Settings/Profile/Notifications/Safety/Rewards/Campaigns + Commerce/Restaurant/Merchant/DirectDelivery/Wallet/ServiceAudioLogs. `providerGoRouterProvider` redirects authed providers to `/merchant-dashboard`.
- **Flavor (15/28):** added `provider` product flavor (`com.delwaqty.provider`) + `com.delwaqty.provider` Firebase client in `google-services.json` (duplicated app client; runtime guarded by `FirebaseConfig.isConfigured`).
- **Four-app matrix (30) BUILD VERIFIED:** Customer ✅ Admin ✅ Driver ✅ Provider ✅ (`app-provider-debug.apk`).
- **Tests (29):** 891/891 pass. **Analyzer (31):** 0 errors.

**Known gaps (intentional, documented — not blockers for build):**
- `merchant_dashboard_page.dart` hardcodes merchant id stub (`'current-merchant-id'`) — needs real provider-id resolver (Phase 4). Pre-existing in Customer app too.
- `UserType.provider` not yet wired into a provider gate (Customer `profile_page` only checks `role=='merchant'`) — Provider app redirects all authed users to `/merchant-dashboard` for now.
- No provider-facing commission/earnings view exists (admin-only today) — Phase 15 gap.
- Notification deep-links default to customer routes — remap needed (Phase 18).
- Restaurant/home-service management UIs absent (repos exist) — build gaps.
- Code NOT yet physically moved to `lib/features/provider/**`; Provider app reuses existing `features/customer/*` supply modules (same pattern as Driver's initial delivery). Deep extraction + removal from Customer = Phases 25–33 (next milestone).

**Remaining (6–14, 16–28, 32–39):**
- Build real Provider nav shell (6), dashboard KPIs (7), orders/bookings/catalog/branches/availability/verification/documents/financial center (8–17), notifications/realtime (18–19), support/profile/settings (20–22), AR/EN (23), routing (24), then extraction safety (25), customer boundary (26), shared contract (27), firebase polish (28), provider tests (29 baseline done), four-app regression (34), APK sizes (35), security regression (36), dead-code (37), quality (38), commit (39).

---

## Current Task — SPRINT 100: INDEPENDENT DELWAQTY DRIVER APP — COMPLETED (committed eef96bd, pushed master)

**Status: Driver feature fully extracted into a REAL independent Flutter app.** `lib/driver/main.dart` + module/router/app + `driver` Android flavor (`com.delwaqty.driver`). Driver APK builds green; Customer + Admin still build; **891/891 tests pass**; 0 analyze errors.

**What was done (Phases 1–20)**
- **Audit (1–3):** mapped `lib/features/customer/driver/**` (28 files); classified DRIVER-ONLY vs SHARED delivery infra (dispatch cluster: `dispatch_repository`, `dispatch_repository_impl`, `supabase_dispatch_data_source`, `ride_offer`, `driver_stats`, `dispatch_providers` + `Ride` entity) which MUST stay shared.
- **Move (5–6):** moved 24 DRIVER-ONLY files to `lib/features/driver/` (driver_module + 5 pages + driver_profile/driver_delivery/vehicle/driver_document/wallet_detail/driver_performance entities + driver_repository + driver_repository_impl + 2 driver datasources). Rewrote only intra-moved imports (`features/customer/driver`→`features/driver`); shared dispatch imports kept pointing at `features/customer/driver`.
- **Driver app (4):** created `lib/driver/{main,app,app_router,module_registry}.dart`. `registerDriverModules()` registers Splash/Onboarding/Welcome/Auth/Regions/Complaints/Settings/Profile/Notifications/Safety/Driver. `driverGoRouterProvider` redirects authed users to `/driver`.
- **Flavor (15):** added `driver` product flavor (`com.delwaqty.driver`) in `android/app/build.gradle.kts`; added `com.delwaqty.driver` client to `android/app/google-services.json` (duplicated app client — Firebase runtime guarded by `FirebaseConfig.isConfigured`).
- **Phase 14 honored:** kept `DriverModule` in Customer during build/verify.
- **Phase 20 executed:** removed `DriverModule()` from `lib/customer/module_registry.dart` (and its now-unused import in `driver_delivery_hub_page.dart`). Customer no longer embeds driver UI; `/driver/*` now lives only in the Driver app. `driver_delivery_hub_page` pushes `/driver/delivery/*` (DeliveryModule routes) — unaffected.

**Verification**
- `flutter analyze`: 0 errors (23 warnings/info, pre-existing categories).
- `flutter test --concurrency=2`: 891/891 pass.
- `flutter build apk --debug --flavor driver --target lib/driver/main.dart --dart-define-from-file=.env.dev` → `app-driver-debug.apk` ✅
- `flutter build apk --debug --flavor customer ...` → `app-customer-debug.apk` ✅ (no regression)

**Remaining (21–26)**
- 17: device smoke on DNP NX9 (install driver APK; deep functional test needs live DB — blocked).
- 18: cross-feature regression scan — DONE (no stale `features/customer/driver/<moved>` refs).
- 19: duplicate-code audit — shared `features/customer/driver` cluster is intentional (shared delivery infra), not duplication.
- 21: internal-track publish — blocked (no signing keystore; debug only).
- 22–23: update architecture docs / module-registry docs to reflect driver separation.
- 24: commit + push (milestone) — pending user go-ahead (per rules, not auto-committed).
- 25: **Provider app extraction — now UNBLOCKED** (driver verified) but a separate large effort; recommended as its own planned pass.
- 26: final report.

---

## Current Task — MASTER RELEASE AUDIT (Session 69) — COMPLETED (findings above)

**Status:** Autonomous AUDIT → FIX → VERIFY loop running. Working from the provided MISSION 1–42 master task.

### Completed this session (committed + pushed)
- `b76a616` sprint 99: SQL security — new migration `060_security_hardening_delivery_platform.sql` adds `search_path = public, pg_temp` + restricts EXECUTE to authenticated/service_role on the 6 delivery RPCs from `011`; removes `anon` EXECUTE grant on all `platform_*` RPCs (`050`).
- `b76a616` sprint 99: Fixed commission display bug (700% due to `* 100` on integer-percent `commission_rate`) in `member_drawer.dart:1243` and `admin_transaction_ledger_page.dart:337`.
- `b76a616` sprint 99: Removed dead buttons — `merchant_detail_page` Call/Chat (no phone/chat backend) removed; Directions implemented via `url_launcher`; `member_drawer` document open button now launches the doc URL; `safety_settings_page` switches kept disabled-honest (no backend contract — documented as pending).
- `5c0f2d0` sprint 99: Localized Arabic-only hardcoded strings in `service_booking_page.dart` (bookingSubmitted/bookingErrorRetry) and `audio_recording_dialog.dart` (l10n.ok). Added 2 ARB keys.
- `094bc43` sprint 99: REMOVED active passenger ride functionality — deleted customer `ride`/`ride_booking` booking screens, driver ride hub/trip + offer/register sheets, admin `RideModel` analytics + `getRecentRides`; removed `/ride/*` and `/driver/rides`/`/driver/trip` routes, module registration, driver dashboard rides entry, and the `/ride/$id` notification deep link. PRESERVED shared delivery infrastructure (`Ride` entity, `ride_providers`, `dispatch_providers`, `dispatch_repository`, `supabase_dispatch_data_source`, `ride_repository`, `fare_quote`, `ride_map`) used by delivery.
- `64dfc2e` sprint 99: Localized ~28 hardcoded English strings across 14 files (driver onboarding, merchant reservations/dashboard/branches, search, admin sanctions/verifications/region_scope/categories/web_gate/hierarchy, pending verification, complaints). Added 25 ARB keys.
- `POST-REMOVAL CLEANUP` sprint 99: **Localization + terminology pass.** Purged **97 dead passenger l10n keys** (EN+AR) — all `ride*`/`trip*`/`taxi*`/`passenger*`/`fare*` that were genuinely unused (booking screens, ride types, ride status, fare breakdown, rate-passenger, etc.). **Kept + renamed 31 delivery-relevant terms** so delivery UX stays intact: `waitingForPassenger`→"Waiting for customer", `revenueRideGmv`→"Delivery GMV", `sosRideInfo`→"Delivery: …", `waitingForRides`→"Waiting for delivery requests", `minimumFareNotMet`→"Minimum delivery amount not met", `driverBefore/AfterTrip` + `before/during/afterTrip`(+Instructions) + `driverDuringTrip` repointed to delivery, `todayRides`/`completedTrips`/`kpiActiveRides`/`noActiveTrip`→delivery KPIs, `notifyOnRide`/`autoShareTrip`→delivery sharing, `tosSection5Body` rewritten to remove "Ride". Repointed admin ledger `'ride'` map value → `l10n.delivery` (backend `reference_type='ride'` unchanged). Removed `rideUpdates` notification toggle + `StorageKeys.rideUpdates`. Fixed `enterOtpToStart` passenger→customer wording (EN+AR). **Both APKs build clean.** Remaining `passenger`/`taxi` code references are intentional: shared `Ride` entity `RideType.taxi`/`passengerCapacity`, `rate_passenger` RPC (driver rates customer — backend identifier kept per rules), `vehicle_management_page` `case 'taxi'` vehicle category.
- `d6304fe` sprint 99: `061_security_hardening_privileged_helpers.sql` — `set_updated_at`/`deactivate_stale_tokens`/`get_unread_notification_count` `search_path`; 32 privileged internal helpers (`_admin_exec_*`,`_member_exec_*`,`_approval_apply`,`_is_owner_uid`,`_reward_*`, etc.) `REVOKE EXECUTE FROM PUBLIC,anon` + `GRANT service_role`. Pushed.
- `87c0655` sprint 99: `062_storage_ownership_hardening.sql` — dropped over-permissive `authenticated read from buckets`/`management buckets`; owner-scoped SELECT/INSERT for `complaints` + `chat_attachments` (`split_part(name,'/',1)::uuid`). `063_commission_account_overrides.sql` — `get_commission_rate(p_user_id)` + `set_commission_rate('account')`; commission precedence account>category>type>default; `platform_commission_for_reference` wired `v_member_id`. Pushed.
- `00e861b` sprint 99: `064_storage_docs_profiles_and_commission_region.sql` — `driver-documents` bucket + owner/admin policies (was MISSING entirely); `profiles` upload tightened to owner path (avatar-overwrite fix); per-account commission override region-scoped via `user_region_preferences`+`_region_in_scope`. Customer APK build green.

### Known open issues (audit findings, not yet fixed)
- LOCALIZATION (Mission 21): ✅ RESOLVED this pass — ~28 EN hardcoded strings localized (commit `64dfc2e`), Arabic-only fixed (`5c0f2d0`), and 97 dead passenger l10n keys purged + delivery terms renamed (POST-REMOVAL CLEANUP). `waitingForPassenger` retained (delivery tracking). Final re-sweep: only intentional `Ride`/`rate_passenger`/`case 'taxi'` references remain (see above).
- RIDE/PASSENGER CODE: ✅ REMOVED active passenger functionality (commit `094bc43`). **DORMANT DB OBJECTS (documented, do NOT drop):** historical passenger tables `ride_requests`, `trip_events`, `ride_ratings`, `ride_pricing` in `007_transportation_platform.sql` are dormant infrastructure (per AGENTS §12.1 — keep, do not delete). `Ride` entity + dispatch infra preserved (delivery uses them).
- SQL: ✅ Global SECURITY DEFINER audit done (212 fns). Confirmed `search_path` gap only on `set_updated_at()` (fixed in `061`); `deactivate_stale_tokens`/`get_unread_notification_count` re-asserted (live versions already covered by `041`). `061` also locks 32 privileged internal helpers (`_admin_exec_*`, `_member_exec_*`, `_approval_apply`, `_is_owner_uid`, `_reward_*` etc.) to `service_role` only via `REVOKE EXECUTE FROM PUBLIC, anon` (closes Postgres-default PUBLIC execution of escalation internals). `011`+`050`+`060` prior. **Not runtime-verified (no live DB) — `061` must be reviewed on staging before prod.**
- TERMINOLOGY (Mission 7): ✅ RESOLVED — Ride/Trip/Passenger/Taxi/Fare scan done; customer-facing labels repointed to delivery ("Delivery GMV", "Waiting for customer", "Today's Deliveries", etc.); backend identifiers (`reference_type='ride'`, `rate_passenger` RPC, `RideType.taxi`) intentionally retained.
- BUTTON/ROUTE/RPC/DB re-audit (Missions 10-12): ⚠️ PARTIAL — passenger routes/buttons/RPC refs removed (`094bc43`); core delivery RPCs verified present (sprint 97). `rate_passenger` dispatch method retained intentionally (driver→customer rating). Full passenger-RPC tombstone pass still recommended before next release.
- SECURITY/FINANCIAL regression (Missions 13-14): ✅ commission 700% bug fixed (`b76a616`); `060` SQL hardening. Deep re-audit pending live DB (env-limited).
- DEAD CODE cleanup (Mission 19): ✅ passenger l10n keys removed; `rideUpdates` toggle + storage key removed. `rate_passenger` dispatch method retained (functional, shared delivery infra — NOT dead).
- PASSENGER RPC TOMBSTONE (Phase A): 🟠 `estimate_fare`, `find_nearest_drivers`, `dispatch_ride` (taxi/passenger matching+fare) are **dead at app level** — `features/customer/ride` is NOT registered in `module_registry.dart`, so `supabase_ride_data_source.dart` is unreferenced dead code (not compiled). Documented DORMANT, not dropped. `register_ride_driver` (dispatch data source) suspect — no clear UI caller after `register_ride_driver_sheet` removed; DORMANT. All `ride_request`/`trip`/`passenger` RPCs used by delivery (`accept_ride_request`, `reject_ride_request`, `start_trip`, `complete_trip`, `cancel_ride_lifecycle`, `rate_passenger`) are SHARED DELIVERY — KEPT. Historical tables `ride_requests`/`trip_events`/`ride_ratings`/`ride_pricing` DORMANT (RLS on; `ride_ratings`+`ride_pricing` have `USING(true)` public read — low sensitivity).
- RLS AUDIT (Phase E): ✅ `platform_commissions`/`commission_rules` fully locked (REVOKE ALL). Owner-scoped `wallets`/`wallet_transactions`/`driver_documents`/`sos_alerts`/`chat_*`/`sanctions`/`complaints`/`campaigns`/`member_*` protected. ✅ `storage.objects` complaint + chat-attachment buckets now owner-scoped (`062`); `profiles` upload owner-scoped (`064-B`); `driver-documents` bucket + owner/admin policies added (`064-A`). 🟠 `drivers` active-location + `service_providers` profile+lat/long public when available (by design for dispatch/ discovery); `notification_tokens` admin-readable; `users` admin SELECT exposes verification docs (admin-only, acceptable). `driver_locations` read hardened in 033 (verify deployed).
- FINANCIAL DISPLAY (Phase I): ✅ No `* 100` on integer-percent bug remains; commission rendered `toStringAsFixed(0)%` everywhere; currency `*100` conversions are correct (cents).
- NOTIFICATION (Phase K): ✅ Clean — no passenger-only ride/trip topics or deep links; `rideUpdates` toggle already removed.

### Environment limits (documented honestly)
- `flutter analyze` / `flutter test` blocked (Windows Dev Mode off). Compile gate = `flutter build apk` (both flavors PASS).
- No live DB access → RPC/SQL runtime probes impossible (🟡/🔴).
- Physical-device verification limited (🔴) — fixes verified by compile only.

### Files modified (this session)
- `supabase/migrations/060_security_hardening_delivery_platform.sql` (new)
- `lib/features/admin/member_management/presentation/pages/member_drawer.dart`
- `lib/features/admin/presentation/pages/admin_transaction_ledger_page.dart`
- `lib/features/customer/safety/presentation/pages/safety_settings_page.dart`
- `lib/features/customer/commerce/presentation/pages/merchant_detail_page.dart`
- `lib/features/customer/home_services/presentation/pages/service_booking_page.dart`
- `lib/features/customer/service_audio_logs/presentation/pages/audio_recording_dialog.dart`
- `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` (+ regenerated l10n)

---

## Current Task — SPRINT 96 COMPLETED: BIOMETRIC LOGIN + ENCODING REPAIR (Session 68)

**Status:** DONE + committed + pushed. Both APKs rebuilt and installed; Arabic verified on device; DIAG logs removed.

### Biometric (fingerprint) login — root cause + fix

1. `android/app/src/main/kotlin/com/delwaqty/app/MainActivity.kt`: `FlutterActivity` → **`FlutterFragmentActivity`** (local_auth 3.x requirement; shared by admin + customer flavors; merged manifests verified: `USE_BIOMETRIC`, `USE_FINGERPRINT`, `.MainActivity`).
2. Stale secure-storage creds (`FlutterSecureStorage.xml` encrypted with pre-debug-signing keystore) unreadable → deleted on device → recreated at next login (entries readable; DIAG `store index read raw=["8a23b719-…"]` OK).
3. Verified admin: fingerprint button (creds saved) → system prompt → scan → `authenticate result: true` → dashboard. Customer: splash auto-login prompts at startup when logged out with creds; `_tryBiometricAutoLogin` in `splash_page.dart`; on exception → `biometricAuthStore.clearAll()` (wipes creds — retest after re-login).
4. Login page layout (user's final choice): guest button ("المتابعة كضيف") **removed**, register link ("ليس لديك حساب؟/إنشاء حساب") moved up, fingerprint button below it (icon + "تسجيل الدخول بالبصمة", disabled while loading). Rebuilt + verified on device.
5. DIAG debugPrints removed from `splash_page.dart` + `biometric_auth_store.dart` (incl. `flutter/foundation.dart` import).

### Arabic corruption — root cause + fix

- Root cause: sprint-91 restructure tool re-wrote files with wrong encoding (Windows-1252 misread of UTF-8 + BOMs). Old 11:16 AM APK was built pre-corruption → clean; new builds → mojibake. Committed at `cfa3ef0` (sprint 91), present in HEAD.
- Fix: batch script — per line with U+0080–U+00FF: encode Windows-1252 → decode UTF-8 (reversible; **0 lossy lines** found); skip lines whose round-trip keeps Latin-1 (legit —, °: 13 lines); write back preserving BOM-status/line endings; then strip BOMs (352 files). Final scan: **0 remaining fixable lines**.
- Scope: 396 fixed lines / 53 files — biggest: `home_page.dart` 50 (incl. `_labels` القريبة/موصى لك/الأشهر at :481), `admin_repository.dart` 25 (incl. `'currency': 'ج.م'`), `search_page.dart` 24, `service_booking_page.dart` 21, `platform_intelligence_providers.dart` 17, SQL migrations (031–040…), tests, ROADMAP.md. `app_ar.arb` was already clean.
- Verified on device (byte-level Arabic word search in uiautomator dumps): customer home (القريبة, موصى لك, الأشهر, مرحباً, مخبوزات, 🥖💐🧺 emojis), admin dashboard (مركز القيادة, بحث, المناطق, كافة المحافظات, اليوم/هذا الأسبوع, إجمالي المستخدمين, المتاجر النشطة, السائقون المتصلون, التوثيقات المعلقة, العمليات, إجمالي الطلبات, الرحلات النشطة, الشكاوى المعلقة, العقوبات النشطة, الأعضاء, الطلبات, المركز المالي, إجراءات).

### Notes / gotchas

- `adb shell cat file > local` writes UTF-16 via PowerShell redirection → use `adb pull` for byte-exact dumps (uiautomator text lives in `content-desc`, Flutter semantics).
- `adb install -r` silently no-ops on identical versionCode → uninstall+install for guaranteed update.
- Truecaller CallUIActivity can steal foreground → check `dumpsys activity activities | grep topResumedActivity` first.
- Admin login creds (user-provided): `said.3pkarino@gmail.com` / `Ed@20266`. Owner: `owner@delwaqty.com`. Live DB has 4 real users (owner, said.astora, cyfyfuf, e2etest user).
- PowerShell console can't display Arabic → verify via hex/byte patterns (`\uXXXX` regex) instead.

### Files modified (this session)
- `lib/data/datasources/local/biometric_auth_store.dart` — DIAG removed
- `lib/features/customer/splash/presentation/pages/splash_page.dart` — DIAG removed
- 53 files encoding-repaired + 352 BOMs stripped (lib/, supabase/migrations, test/, ROADMAP.md)
- `SESSION_STATUS.md` — this update

### Device Lock / App Lock feature (in progress — SESSION 68)

New user request: re-verify with ALL device credentials (PIN/pattern/password + face + fingerprint) on every **cold start**, dedicated App Lock screen, both apps, per saved account.

**Implemented:** `device_lock_provider.dart` (cold-start `init()` sets `unlocked=false` when `hasAnyCredentials()`), `device_unlock_page.dart` (lists saved accounts, `local_auth.authenticate(biometricOnly:false)` → sign-in via stored creds → `markUnlocked()`), lock gate in `app_router.dart` + `admin_router.dart` `redirect`, `/device-unlock` route, `splash_page.dart` auto-biometric removed (router enforces lock), `login_page.dart` `markUnlocked()` on sign-in, `biometric_auth_store.activeUserId()`, 8 l10n keys (deviceUnlock*).

**Audit (read-only sub-agent) + fixes applied:**
- **C1 (CRITICAL):** lock gate redirected *all* non-`/device-unlock` routes incl. `/login` → "Use another account" + password escape hatch dead → permanent lockout. Fixed: exempt `isAuthRoute` (login/register/forgot-password) in both routers.
- **M1:** `clearForUser` wiped creds on *any* `AuthError` (incl. network). Fixed: only on credential error ("invalid login credentials").
- **M2:** zero-account trap resolved by C1 (now `/login` reachable).
- **M3:** cold-start bypass window before `init()` — low impact (splash delay); accepted.
- **m1:** removed redundant `isAdmin ? Color : Color` ternary.
- **m3:** correct unlock destination via `user.isAdmin` (added `admin_access.dart` import for the `isAdmin` extension getter).
- **m4:** `init()` now explicitly sets `DeviceLockState(unlocked:false, hasDeviceAccount:hasCreds)`.
- Verified: all 8 l10n keys valid in both arb files; `refreshListenable` bump mechanism correct; backgrounding does NOT re-lock (spec).

**Build:** both APKs rebuild clean (`--flavor customer` + `--flavor admin`). `flutter analyze` still blocked (Dev Mode off). On-device unlock needs physical credential (PIN/face/fingerprint) — not simulatable via adb; UI login seeding blocked by adb `input text` dropping `@`/digits.

### Files modified (device lock)
- `lib/features/_shared/device_lock/device_lock_provider.dart`
- `lib/features/_shared/device_lock/presentation/device_unlock_page.dart`
- `lib/core/router/app_router.dart`, `lib/core/router/admin_router.dart`
- `lib/features/customer/splash/presentation/pages/splash_page.dart`
- `lib/features/_shared/auth/presentation/pages/login_page.dart`
- `lib/data/datasources/local/biometric_auth_store.dart`
- `lib/customer/app.dart`, `lib/admin/app.dart`
- `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`

### SPRINT 97 (partial): BUTTON ↔ RPC AUDIT — results

Read-only cross-check of all 93 `rpc(...)` calls in `lib/` against `CREATE FUNCTION` in `supabase/migrations/*.sql` (sub-agent "Manios"). **Every called RPC name resolves to a migration function — no missing/typo'd names.** Param-level findings:

**Fixed (verified against SQL signatures, both APKs rebuild clean):**
- `issue_sanction` @ `member_drawer.dart:1748` passed `p_user_id` → wrong (no overload). Changed to `p_member_id` (matches 035 `issue_sanction(p_member_id, ...)`). The other 2 call sites already used `p_member_id`.
- `get_member_timeline` @ `supabase_member_data_source.dart:63` passed `p_cursor` → wrong. Changed to `p_before` (matches 035 `get_member_timeline(p_member_id, p_before, p_limit)`).
- `member_ops_list` @ `supabase_member_data_source.dart:95,100` passed `p_service_type` (nonexistent) and `p_cursor_created_at` (nonexistent) → wrong. Changed to `p_service_category` and `p_cursor` (matches 049 `member_ops_list(..., p_service_category, ..., p_cursor, p_cursor_id, ...)`).

**FALSE POSITIVES (do NOT change — verified overloads in `057_owner_delete_missing_admin_rpcs.sql`):**
- `assign_admin_role` @ `admin_hierarchy_page.dart:295,367` uses `p_email`/`p_role` → matches 057 overload `assign_admin_role(p_email text, p_role text, p_reason)` (034 uuid overload also exists; PostgREST resolves by param types).
- `assign_admin_region` @ `admin_hierarchy_page.dart:427` uses `p_email`/`p_region` → matches 057 overload `assign_admin_region(p_email text, p_region text, p_scope)` (resolves region by name).

**Remaining (NOT done this pass — needs careful, separate refactor + live-DB verification; flagged as tech debt, not a runtime crash):**
- `admin_repository.dart` legacy `admin_users` table direct access (lines 549 select, 581 insert, 607 update, 634 delete). Table still exists with RLS so it currently works, but modern stack uses `users`/`admin_management` + RPCs (`get_all_admins`, `create_admin_account`, `assign_admin_role`, `deactivate_admin`, `owner_delete_member`). `deleteUser` raw delete (634) bypasses SECURITY DEFINER — should route through a proper admin-lifecycle RPC. **Deferred:** blind refactor risks breaking the admin panel (field-shape mismatches, no `analyze`/`test` available here). Requires dedicated pass mapping return shapes + verifying RLS.
- ~60 transport/delivery/ride/safety/platform-intelligence/notification RPCs confirmed present in migrations but their individual `params:` keys were not diffed line-by-line — recommend a scripted RPC-signature linter as follow-up.

### admin_users legacy refactor — RETAINED as explicit technical debt (evidence-based, NO code change)

Per sprint-97 rules 3/8/9, the four `admin_repository.dart` operations on the legacy `admin_users` table were investigated against the actual schema + RPCs. **None has a complete, behavior-preserving, verified mapping** → all four retained unchanged; documented here; no second admin-management system created; no schema modified; no duplicate RPCs.

**Evidence (source of truth):**
- `016_fix_rls_policies.sql:14` — `admin_users.id` is a **separate generated UUID (not `users.id`)**.
- `031_admin_hierarchy_region_assignments.sql:32-47` (ADR-055) — adds `user_id` FK `admin_users→users(id)`; `:141` — `admin_users (F1, dormant metadata — still readable by admins)`.
- `034:670` `create_admin_account(p_user_id uuid, p_supervisor_id, p_region_id, p_scope)` — promotes an **existing `users.id`** only; no create-from-email.
- `034:725` `deactivate_admin(p_admin_id uuid, p_reason)` — soft deactivate.
- `057:252` `get_admin_profile(p_email)` → returns `email, role, is_owner, region_name, total_earnings` (**no full_name / status / last_login**).
- `057:305` `get_all_admins()` → returns `email, role, region_name, is_active, supervisor_email, created_at` (**no full_name / status / last_login**).
- `058:27-122` `owner_delete_member(p_member_id uuid, p_reason)` — **owner-only**; deletes `users`+`auth.users` + cleans `admin_management`/drivers/etc.; does **NOT** delete the `admin_users` row (would orphan it).

**Field mapping (OLD → NEW):**
| OLD `admin_users` field | NEW source/RPC field | Status |
|---|---|---|
| `id` (separate UUID) | `admin_users.user_id` → `users.id` (FK, 031) | no 1:1 direct key |
| `full_name` | `users.full_name` — **not returned by any admin RPC** | ❌ no mapping |
| `email` | `get_all_admins().email` | ✅ available |
| `role` | `get_all_admins().role` | ✅ available |
| `status` (active/suspended/pending) | modern = `admin_management.is_active` (bool); no status enum / no suspend RPC | ❌ no mapping |
| `last_login` | **not returned by any admin RPC** | ❌ no mapping |
| `created_at` | `get_all_admins().created_at` | ✅ available |
| `region` | `get_all_admins().region_name` | ✅ available |

**Action mapping (OLD → NEW):**
| OLD action | NEW RPC | Verdict |
|---|---|---|
| `createUser` (insert new `admin_users` from email+name+role+status) | `create_admin_account` needs existing `users.id` | ❌ NO equivalent → RETAIN |
| `updateUser` (full_name,email,role,status) | `assign_admin_role`(role, needs users.id) + no RPC for admin full_name/status | ❌ INCOMPLETE → RETAIN |
| `deleteUser` (hard delete `admin_users` by `admin_users.id`) | `owner_delete_member(p_member_id=users.id)` | ❌ UNSAFE: owner-only (authz change), keys on `users.id` not `admin_users.id`, orphans `admin_users` row → RETAIN |
| `getUsers` (read) | `get_all_admins()` lacks full_name/status/last_login | ❌ INCOMPLETE → RETAIN |

**Recommended future migration (separate effort, needs product decision + likely new RPCs):** rebuild `admin_users_page` on `get_all_admins()` + extend admin RPCs to return `full_name`/`status`/`last_login` + add an admin-create-user RPC; or formally deprecate `admin_users` (dormant metadata) and stop reading it for the live admin list. Until then the legacy path is the only source of `name`/`status`/`last_login` for that screen.

### Build commands
```powershell
$env:PUB_CACHE = "E:\app\pub-cache"
flutter build apk --debug --flavor admin --target lib/admin/main.dart --dart-define-from-file=.env.dev
flutter build apk --debug --flavor customer --target lib/customer/main.dart --dart-define-from-file=.env.dev
adb -s A3SQUT5A28003808 install -r build\app\outputs\flutter-apk\app-admin-debug.apk
adb -s A3SQUT5A28003808 shell am start -n com.delwaqty.admin/com.delwaqty.app.MainActivity
```

### CURRENT TASK — SPRINT 98: MODERN ADMIN MANAGEMENT CENTER (in progress)

**Status:** Backend contract + Flutter module implemented; both APKs build; docs
written. **Not yet committed.** Live-DB / analyzer / physical-device verification
pending (environment-limited → 🟡).

**Delivered**
- SQL `059_admin_management_center_contract.sql`: extended `get_all_admins()` /
  `get_admin_profile(p_email)` (backward compatible, adds `id`/`full_name`/
  `region_id`/`scope`/`supervisor_id`); new `get_admin_permissions`,
  `get_admin_audit_history`, `reactivate_admin` (+`_admin_exec_reactivate`). All
  SECURITY DEFINER, authorized = owner OR target-self OR `is_supervisor_of`,
  region-contained.
- Edge Function `supabase/functions/create-admin/`: verifies caller JWT +
  `is_active_admin_uid`, creates Auth identity via service_role Admin API, promotes
  via `_admin_exec_create`. **service_role key never reaches Flutter.**
- Flutter module `lib/features/admin_management/` (domain/data/presentation);
  routes `/admin/admins` + `/admin/admins/:id`; sidebar + quick-action repointed.
- Legacy `admin_users_page` (mobile + web) **deleted**; table kept DORMANT.
- 73 Arabic+English l10n keys (independent admin locale). `last_login` documented
  as NOT TRACKED (UI shows "Not tracked", no fabrication).
- Build: admin + customer APK both succeeded.

**Open / blocked**
- 🟡 Live-DB verification of 059 + Edge Function (no DB access here).
- 🟡 `flutter analyze` / `flutter test` blocked (Windows Dev Mode off) — kernel
  compile of both APKs used as proxy.
- ⚪ Automated tests not authored (env can't run them).
- 🟡 Physical-device run not performed.
- 🟡 Dormant `admin_users` Dart dead code (`admin_repository`/`admin_service`/
  `adminUsersProvider`) pending dedicated cleanup.

**Files modified (this sprint)**
- `supabase/migrations/059_admin_management_center_contract.sql` (new)
- `supabase/functions/create-admin/index.ts` (new)
- `lib/features/admin_management/**` (new module)
- `lib/features/admin/admin_module.dart`, `admin_shell.dart`,
  `admin_web/.../admin_web_shell.dart`, `admin_quick_actions_page.dart`
- `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`
- deleted `admin_users_page.dart` (mobile + web)
- `docs/HANDOFF/SPRINT_98_ADMIN_MANAGEMENT_AUDIT.md` (new),
  `docs/HANDOFF/SPRINT_98_ADMIN_MANAGEMENT_FINAL.md` (new)

---

## Previous Tasks

- **SPRINT 95:** Deletion root-cause fix + missing RPCs + live fixes — 057, KPI, dead buttons, search route
- **SPRINT 94:** Admin features expansion (dark mode, owner delete, profile, hierarchy, pending deletions)
- **SPRINT 93:** Admin nav redesign
- **SPRINT 92:** Admin bottom nav redesign v1
- **SPRINT 91:** Monorepo restructure
- **SPRINT 90:** iPhone-style bottom nav, account deletion, driver doc upload
- **SPRINT 89:** Privacy persistence, service booking l10n, admin polish
- **SPRINT 88:** Critical fixes
- **SPRINT 87:** Admin standalone polish