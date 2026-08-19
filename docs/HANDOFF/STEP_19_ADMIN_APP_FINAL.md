# STEP 19 — Admin Delwaqty App Final

## App Identity
- **Name**: Admin Delwaqty
- **Package**: com.delwaqty.admin
- **Entry Point**: `lib/main_admin.dart`
- **MaterialApp**: `lib/app/app_admin.dart`
- **Router**: `lib/core/router/admin_router.dart`
- **Module Registry**: `lib/module_registry_admin.dart`

## Build Commands
```bash
flutter build apk --debug --flavor admin --target lib/main_admin.dart --dart-define-from-file=.env.dev
```

## App Structure
```
main_admin.dart
  → Firebase init (conditional)
  → Supabase init
  → Hive init
  → ConnectivityService init
  → registerAdminModules()
  → ProviderScope → AppAdmin

AppAdmin (MaterialApp.router)
  → Admin GoRouter (admin-only routes)
  → Arabic default locale
  → Theme (light + dark)

AdminModule.standaloneRoutes
  → /admin (Command Center)
  → /admin/users, /admin/merchants, /admin/orders
  → /admin/members, /admin/members/:id
  → /admin/analytics, /admin/settings
  → /admin/drivers, /admin/deliveries
  → /admin/emergency, /admin/live-tracking
  → /admin/financial-center, /admin/transaction-ledger
  → /admin/commissions, /admin/approvals
  → /admin/complaints, /admin/sanctions
  → /admin/support-chat, /admin/support-chat/room/:roomId
  → /admin/push-notifications
  → /admin/verifications
  → /admin/delivery-intelligence, /admin/merchant-intelligence
  → /admin/provider-intelligence, /admin/wallet-intelligence
  → /admin/service-performance
```

## Authentication Flow
1. App opens → Admin GoRouter redirect checks auth state
2. Not authenticated → redirects to /login
3. Authenticated but not admin → redirects to /login
4. Authenticated admin → redirects to /admin (Command Center)

## Admin Locale
- Default: Arabic (ar)
- Independent from customer app language
- Persisted via admin_locale_provider.dart
- Language switch in Admin Settings

## Platform Deletion Safety
Admin Delwaqty MUST NOT expose:
- Delete Platform / Delete Application / Delete Database
- Delete All Data / Destroy Platform / Factory Reset
- For ANY role, including Owner

Member deletion remains: Soft Delete + Anonymization + Audit + History

## Firebase Configuration
- google-services.json includes both com.delwaqty.app and com.delwaqty.admin
- Admin notification channel: delwaqty_admin_notifications
- Deep link scheme: io.delwaqty.admin
