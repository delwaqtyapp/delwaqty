# STEP 19 — Partner Extraction Readiness

## Status: ARCHITECTURE PREPARED, NOT BUILT

## Current Platform Taxonomy
Based on database and code inspection:

### Service Provider
- Home services (plumbing, electrical, AC, cleaning, etc.)
- Bookings, availability, scheduling
- Service-specific pricing

### Merchant
- Product catalog, inventory, pricing
- Branch management
- Order fulfillment

### Restaurant
- Menu management, food delivery
- Order + delivery workflow
- Time-based availability

### Pharmacy
- Medicine catalog
- Prescription handling
- Regulatory compliance

### Delivery
- Driver/delivery operations
- Trip lifecycle
- Proof of delivery

### Other Business Types
- Future categories as needed

## Partner-Only Modules (future)
- Registration + Verification
- Business Profile
- Service Management
- Service Availability
- Pricing Configuration
- Working Hours
- Bookings / Orders / Requests
- Customer Management
- Offers + Campaigns
- Wallet + Earnings + Commission + Settlements
- Ratings + Complaints + Support
- Notifications
- Analytics
- Documents
- Business Settings

## Shared Partner Modules
- Auth (login, register, profile)
- Supabase client
- RealtimeService (partner channels only)
- PushNotificationService
- ConnectivityService
- HiveCacheService
- Theme + Localization
- Wallet primitives
- Order primitives
- Commission domain models
- Region resolution

## Commission Architecture
Current defaults:
- Provider / Delivery = 7%
- Restaurant / Pharmacy = 3%

Future Partner App must:
- Consume commission configuration from backend
- NOT hardcode commission rates
- Respect admin-controlled overrides
- Display per-transaction commission snapshots

## Admin Commission Control (preserved)
Admin Delwaqty remains central authority for:
- Platform Default
- Provider Default / Delivery Default
- Merchant Default / Restaurant Default / Pharmacy Default
- Per-entity overrides

## Partner vs Merchant
Do NOT assume every service provider is a merchant:
- Service Provider: bookings, availability, scheduling
- Merchant: catalog, inventory, orders
- Restaurant: menu, food delivery, time-based
- Pharmacy: medicine, prescriptions, regulatory
- Delivery: trips, GPS, proof of delivery

## Workflows Overlap
Shared:
- Auth, profile, verification
- Wallet, earnings, commission
- Notifications, support, complaints
- Ratings, analytics

Differ:
- Service management (provider vs merchant vs restaurant)
- Order flow (booking vs purchase vs delivery)
- Availability (schedule vs inventory vs hours)
- Pricing (hourly vs fixed vs dynamic)

## Future Extraction Sequence
1. Create `lib/features/partner/` (new feature module)
2. Move partner-specific pages
3. Create `lib/main_partner.dart` entry point
4. Create `lib/module_registry_partner.dart`
5. Add `partner` flavor to build.gradle.kts
6. Create `android/app/src/partner/` source set
7. Test partner app independently
