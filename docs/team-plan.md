# Team Plan — Customer App Launch Audit + Fix

> **Date:** 2026-09-15
> **Scope:** Customer app (com.delwaqty.app) only
> **Gate:** flutter analyze 0/0/0 + flutter test all pass + APK builds

---

## ROUND 15 — Car Marketplace + All-Services booking-first (2026-09-19) ✅
> Committed `b4a6709` (sprint 154), pushed. Gate: analyze **0** / test **928/928** / APK built + installed both devices / migration 083 applied live / QA **APPROVE**.

- **Task A — All-Services reorder**: `/services` = booking services FIRST (`getCategories()`), commerce grid below.
- **Task B — Car marketplace**: `083_car_marketplace.sql` (car_products + RLS + delivery_car_requests extended w/ driver_price/commission 7%/total) applied live, 6 cars seeded. `CarProduct` entity (freezed + manual generated files). Repository: `getAvailableCarProducts`/`getCarProduct`/`createCarProduct`/`submitCarTripOrder` (7% precise 2-decimals, total derived from rounded commission). `CarMarketplacePage` + `CarTripOrderPage` (scheduled time + geo: map + price breakdown). Routes `/home-services/cars`, `/cars/sell`, `/cars/:carProductId/order`. All deliveryCar entries → marketplace.
- **Task C — register-as-product**: `CarSellerFormPage` (driver sets price) + route + AppBar action + 20 l10n keys (1997/1997). Auth-guarded (`is! AuthAuthenticated`).
- Notes: coder subagent model unavailable this round (minimax free) → tasks executed by orchestrator + coder2 (reverted its unintended `dart format` of 334 files via git checkout). build_runner impossible on device (snapshot Android vs Linux) → freezed/g hand-written & force-committed.

---

## Final Status
- `flutter analyze`: **No issues found!** (0 errors / 0 warnings / 0 infos)
- `flutter test`: **928/928 passed**
- APK build: `bash build.sh` → `releases/delwaqty_1.0.0+1_debug_20260915_231841.apk`; installed + launched on device 192.168.8.36:5555 (pid live, no FATAL, no config crash)

## Completed Fixes

### Payment (Paymob removed → Cash + InstaPay + Vodafone Cash) ✅
- Deleted `lib/services/payment/paymob_service.dart` + empty `payment/` dir; removed Paymob config from `app_config.dart`/`config_validator.dart` and `PAYMOB_*` from `.env.*`
- `checkout_page.dart`: `SegmentedButton` cash / instapay / vodafone_cash (default cash); `_placeOrder` creates the order directly, no iframe
- `wallet_topup_page.dart`: instapay (default) / vodafone_cash / cash

### Profile redesign (settings merged, gear removed) ✅
- `profile_page.dart`: AppBar without actions; Appearance (theme + language SegmentedButton), Account, Help & Legal sections; `settings_page.dart` deleted; `settings_module.dart` shell routes removed, standalone pages kept

### Audit bug fixes ✅
- `order_completed_page.dart`: `_shortOrderId()` helper (no crash on short ids); hardcoded "25 min" ETA row removed
- `order_tracking_page.dart`: status-derived card replaces fake ETA '25 min'; fake driver card ('Mohamed A.' / '••• 4521' / tel) replaced with honest "driver assigned pending" state; `url_launcher` import removed
- `direct_delivery_page.dart`: submit now geocodes drop-off (Google Places), inserts a real courier `rides` row (`service_type='courier'`, status `searching`), dispatches via `dispatch_delivery`, and navigates to `/delivery-tracking/:id`
- `delivery_module.dart`: registered `/delivery-tracking/:deliveryId`
- `safety_settings_page.dart`: switches persist via SharedPreferences (sos enabled, auto sos timer, auto share trip, share duration cycle 30–120 min, pickup OTP)
- `login_activity_page.dart`: fake IP/device removed → real OS label + "This device"
- `data_privacy_page.dart`: no longer claims account deletion; signs out and informs that deletion is handled by support
- `search_page.dart`: 'Price Range' → `l10n.priceRange`; 'EGP' → `l10n.currencySymbol`
- `privacy_security_page.dart`: raw `Navigator.push` → `context.push` go_router routes (7 sub-pages registered in settings_module)
- Deleted dead files: `splash_page_backup.dart`, `splash_page.dart.bak`, `splash_page_v2.dart.bak`

### New l10n keys (ARB en+ar, regenerated)
`orderStatus`, `deliveryStatus`, `driverAssignedPending`, `deliveryAddressNotFound`, `loginRequired`, `thisDevice`, `accountDeletionInfo`, `driverSearchRetried`, `dispatchStuckMessage`, `retryNow`

## Pending-Warning Resolutions (2026-09-15, round 2)

1. **Account deletion (DONE)** — migration `supabase/migrations/079_delete_my_account.sql` adds a
   security-definer `delete_my_account(reason)` RPC: reuses the moderation engine's
   `_member_exec_delete` (anonymize PII + `account_status='deactivated'`, FK-safe) and then revokes
   the auth row. RLS-safe (only `auth.uid()`), admins refused. `data_privacy_page.dart` now calls the
   RPC first; if it is not deployed it falls back to sign-out + support info. Apply via
   `supabase db push` when deploying.
2. **Direct delivery dispatch retry (DONE)** — `delivery_tracking_page.dart` shows a rescue card
   while `RideStatus.searching`: explains no-driver-yet and calls `dispatchDelivery(rideId)` again
   (shows the real Postgrest error when it fails). Live validation still requires a connected device
   against the real Supabase project (manual, one-time).
3. **Ride-hailing module — classified & archived (DONE, no code change)**—— per AGENTS.md §12.1 it is
   **Dormant Infrastructure** (data/repo/providers/widgets only; **no** booking pages, routes, or
   module_registry entry — verified no UI dead-links). Kept deliberately, not deleted. Activation
   criteria: product decision to launch ride booking → then build
   `ride/presentation/pages/ride_booking_page.dart` (+ confirm/payment flow), register
   `/ride-booking` route in `customer_module_registry.dart`, add export to module registry.
4. **Staging/prod `.env` (SCRIPT-READY)** — values still require real credentials (manual,
   cannot fabricate). `build.sh` now supports `--env <dev|staging|prod>` (default `dev`) and verifies
   the file exists; once real values are inserted, `bash ./build.sh --env prod` works. The empty
   skeleton hard-fails at app runtime on purpose (ConfigValidator), so no broken APK is shipped.

## Known Gaps / Manual Follow-ups
1. **Live dispatch validation** — run the app on a real device against the real Supabase project and
   submit a courier order; verify the `rides` row appears (`service_type='courier'`, status
   `searching`) and `dispatch_delivery` returns OK. (One-time, manual.)
2. **Ride booking activation** — product decision only; module remains archived/dormant until then.