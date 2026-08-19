# STEP 19 — Admin Extraction Audit

## Architecture Decision
Build flavors approach: two entry points from a single codebase.
- `flutter build apk --flavor customer --target lib/main.dart`
- `flutter build apk --flavor admin --target lib/main_admin.dart`

## Module Classification

### CUSTOMER Modules (registered in module_registry.dart)
- SplashModule, OnboardingModule, WelcomeModule, AuthModule
- HomeModule, CommerceModule, RestaurantModule, MerchantModule
- WalletModule, DriverModule, RideModule, DirectDeliveryModule
- SettingsModule, ProfileModule, NotificationsModule
- SafetyModule, ServiceAudioLogsModule, ComplaintsModule
- SanctionsModule, LocationTrackingModule, SupportChatModule
- SearchModule, OrdersModule, HomeServicesModule
- RegionsModule, RewardsModule, CampaignsModule, EscalationModule

### ADMIN Modules (registered in module_registry_admin.dart)
- AuthModule, AdminModule, MemberManagementModule
- ComplaintsModule, SanctionsModule, LocationTrackingModule
- SupportChatModule, EscalationModule, RegionsModule
- CampaignsModule, RewardsModule, NotificationsModule

### SHARED CORE (both apps)
- `lib/core/` — router, auth, theme, localization, errors, utils
- `lib/shared/` — widgets, notifications
- `lib/services/` — supabase, realtime, push, maps, connectivity, admin, logger
- `lib/data/` — repositories, datasources, models
- `lib/domain/` — entities, repositories, usecases
- `lib/l10n/` — localization files
- `lib/config/` — configuration

### ADMIN-ONLY CODE
- `lib/features/admin/` — all admin pages, admin_shell, admin_module
- `lib/features/member_management/` — member operations, detail, drawer
- `lib/services/admin/` — admin_providers, admin_service
- `lib/core/auth/admin_access.dart` — admin role checking
- `lib/core/localization/admin_locale_provider.dart` — admin locale
- `lib/app/app_admin.dart` — admin MaterialApp
- `lib/core/router/admin_router.dart` — admin GoRouter
- `lib/module_registry_admin.dart` — admin module registration

### CUSTOMER-ONLY CODE (post-cleanup)
- `lib/features/floating_sidebar/` — customer sidebar (admin entry removed)
- `lib/features/home/` — customer home
- `lib/features/commerce/` — customer marketplace
- `lib/features/restaurant/` — customer restaurants
- `lib/features/merchant/` — customer merchant browsing
- `lib/features/wallet/` — customer wallet
- `lib/features/profile/` — customer profile
- `lib/features/search/` — customer search
- `lib/features/orders/` — customer orders
- `lib/features/safety/` — customer safety
- `lib/features/home_services/` — customer home services

## Mixed Modules (contain both customer and admin pages)
- `complaints/` — admin_complaints_page.dart (admin) + customer complaint pages
- `sanctions/` — admin_sanctions_page.dart (admin) + customer sanction views
- `location_tracking/` — admin_live_tracking_page.dart (admin) + customer tracking
- `support_chat/` — admin_support_chat_page.dart + admin_support_chat_page.dart (admin) + customer support

## What Changed
1. Admin sidebar entry removed from floating_sidebar_overlay.dart
2. AdminModule + MemberManagementModule removed from customer module_registry.dart
3. Admin entry point (main_admin.dart) created with admin-only module registration
4. Admin MaterialApp (app_admin.dart) with Arabic default locale
5. Admin GoRouter (admin_router.dart) with admin-only routes
6. Android flavors: customer (com.delwaqty.app) + admin (com.delwaqty.admin)
7. Flavor-specific AndroidManifest.xml with different deep link schemes

## Verification
- `dart analyze` — 0 errors on all touched files
- `flutter test` — 896/896 pass
- `flutter build apk --flavor customer` — builds successfully
- `flutter build apk --flavor admin` — builds successfully
