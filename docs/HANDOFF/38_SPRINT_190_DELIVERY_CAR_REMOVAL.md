# SPRINT_190_DELIVERY_CAR_REMOVAL.md — Round 56

**Date:** 2026-09-24 · **Round:** 56 · **Sprint:** 190 · **Commit:** round-56 (ADR-102)

## Owner request
«بس عندى نقطه مهمه احنا شغالين بالدليفرى بس مش عندنا عربيات توصيل زى اوبر وعايزين نشيل كود خدمه توصيله نهائيا من المنصه ومن الادمن ومن تطبيق العميل بدون كسر التطبيق لو الكود مختفى بشكل مؤقت»

Decision: the company operates courier (motorbike/bike) deliveries only. The Uber-style delivery-car service is removed **permanently** from the customer app, the admin app, and the database — while never breaking the app.

## What was done

### 1. Customer app (`lib/`) — delivery-car surface deleted
- Deleted pages: `delivery_car_request_page.dart`, `car_marketplace_page.dart`, `car_trip_order_page.dart`, `car_seller_form_page.dart`.
- Deleted entity: `car_product.dart` (`CarProduct`).
- Deleted booking-repo methods: `submitDeliveryCarRequest`, `getMyDeliveryCarRequests`, `getAvailableCarProducts`, `getCarProduct`, `createCarProduct`, `submitCarTripOrder` (+ `myDeliveryCarRequestsProvider`).
- Removed `ServiceCategoryType.deliveryCar` enum value + all mentions in `home_domain.dart`, `home_page.dart`, `all_services_page.dart`, `home_services_page.dart`, `service_booking_page.dart`, `service_providers_page.dart`, `category_visuals.dart`.
- Removed 4 module routes: `/home-services/delivery-car`, `/home-services/cars`, `/home-services/cars/sell`, `/home-services/cars/:carProductId/order`.
- l10n: removed 41 car-only keys from `app_ar.arb` + `app_en.arb` (JSON round-trip).
- Test: removed `CarProduct.fromJson` case from `snake_case_api_entities_test.dart`.

### 2. Admin app — car-requests page + ride metrics removed
- Deleted `admin_delivery_car_requests_page.dart` + its route (`admin_module.dart`) + nav entry (`admin_shell.dart`).
- Removed dead `ridesTimeseriesProvider` / `getRidesTimeseries`.
- Dashboard: "Active Rides" KPI card rewired to `activeDeliveries` (`Icons.directions_bike_rounded`); "Ride GMV" revenue card removed.
- Financial center: 7% commission card removed.
- Models: `AdminDashboardMetrics.totalRides/activeRides` removed; platform-intelligence `totalRides/completedRides/activeRides/rideGmv/commission7pct` removed; `TimeseriesData.ridesByDay/ridesByStatus` removed.
- Repository: `getDashboardMetrics` drops the two ride-count queries and ride revenue sums (delivery-only now).
- l10n: `kpiActiveRides` renamed → `kpiActiveDeliveries`; `revenueRideGmv`/`commissionRate7` removed. Freezed/generated code regenerated (`build_runner`), `gen-l10n` rerun.

### 3. Database — migration 091 (applied live)
```sql
DROP TABLE IF EXISTS public.delivery_car_requests;
DROP TABLE IF EXISTS public.car_products;
DELETE FROM public.service_categories WHERE type = 'deliveryCar';
ALTER TABLE public.drivers ALTER COLUMN service_types SET DEFAULT ARRAY[]::TEXT[];
```
Verified live: tables gone, category rows 0, default empty array, no car RPCs.

### 4. Kept (shared ride plumbing — must NOT be removed)
- Shared `rides` + `vehicles` tables and `rides.service_type='ride'` historical rows.
- Realtime channel `active-ride`, `RideMap`/`rideStreamProvider`, dormant `lib/features/customer/ride/` module — the courier delivery tracking page depends on this plumbing. Removing it would break deliveries (AGENTS 12.1 classification: kept infrastructure).

## Gates
- `flutter analyze` — **0 issues**.
- `flutter test` — **940/940** (941 ← 1 car test removed).
- Customer APK `releases/delwaqty_customer_1.0.0+1_debug_20260924_0010.apk` installed.
- Admin APK `releases/delwaqty_admin_1.0.0+1_debug_20260924_0010.apk` installed.
- Smoke on DNP NX9: customer pid 21158, admin pid 21258 — no FATAL, no stale `car*`/`deliveryCar` logcat references.

## Docs
- ADR-102 in `docs/DECISION_LOG.md`.
- `SESSION_STATUS.md` ROUND 56 banner added.