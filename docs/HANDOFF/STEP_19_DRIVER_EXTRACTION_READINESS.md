# STEP 19 — Driver Extraction Readiness

## Status: ARCHITECTURE PREPARED, NOT BUILT

## Driver-Only Modules (future)
- Driver Registration + Verification
- Driver Profile + Documents
- Availability (Online/Offline)
- Current Location + Background Location
- Live GPS + Heartbeat
- Assigned Jobs / Available Jobs
- Accept Job / Reject Job
- Pickup → Delivery → Trip State
- Navigation
- Customer Contact
- Order Details
- Proof of Delivery
- Delivery Status Updates
- Earnings + Wallet + Commission + Settlement
- Ratings + Complaints + Support
- SOS + Emergency
- Trip History + Performance

## Shared Driver Modules
- Auth (login, register, profile)
- Supabase client
- RealtimeService (driver channels only)
- PushNotificationService
- ConnectivityService
- HiveCacheService
- Theme + Localization
- Wallet primitives
- Order primitives
- Commission domain models
- Region resolution

## GPS Dependencies
- `geolocator` package (already in pubspec)
- `permission_handler` package (already in pubspec)
- foreground service permission
- background location permission
- location always permission
- location while in use permission

## Realtime Dependencies
- Driver location channel
- Driver availability channel
- Job assignment channel
- Trip state channel
- Realtime order updates
- SOS channel

## Notification Dependencies
- Job assignment notifications
- Trip state change notifications
- Earnings notifications
- SOS notifications

## Order Dependencies
- Order assignment
- Order status updates
- Proof of delivery
- Customer communication

## Wallet Dependencies
- Driver balance
- Earnings history
- Withdrawal requests
- Commission deductions

## Commission Dependencies
- Driver commission rate (default 7%)
- Per-delivery commission calculation
- Settlement schedule

## Authentication
- Same Supabase auth as customer
- Driver-specific role verification
- Document verification

## Permissions
- Location (foreground + background)
- Camera (proof of delivery)
- Notifications
- Phone (customer contact)

## Region Dependencies
- Same region system as customer
- Driver region assignment
- Service area boundaries

## Background Execution
- Foreground service for GPS tracking
- Background location updates
- Periodic heartbeat
- State restoration on kill

## Platform-Specific
- Android: foreground service type "location"
- Android: background location permission
- iOS: location always usage description
- iOS: background modes: location

## Future Extraction Sequence
1. Create `lib/features/driver_ops/` (new feature module)
2. Move driver-specific pages from `lib/features/driver/`
3. Create `lib/main_driver.dart` entry point
4. Create `lib/module_registry_driver.dart`
5. Add `driver` flavor to build.gradle.kts
6. Create `android/app/src/driver/` source set
7. Test driver app independently
