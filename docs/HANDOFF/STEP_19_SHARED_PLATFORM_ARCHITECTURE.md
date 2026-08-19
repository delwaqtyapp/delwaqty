# STEP 19 — Shared Platform Architecture

## Core Principle
ONE PLATFORM with MULTIPLE CLIENT APPLICATIONS.
Not four independent systems.

## Shared Backend
All apps use the same:
- Supabase Project (Database, Auth, RLS, RPCs)
- Business Rules
- Regions, Geo Architecture
- Permissions
- Realtime
- Notifications
- Wallets, Orders, Commissions
- Audit, Security

## Shared Code (lib/core/, lib/shared/, lib/services/)

### Authentication
- `lib/features/auth/` — AuthModule (login, register, forgot-password)
- `lib/domain/entities/user.dart` — User entity
- `lib/data/repositories/auth_repository_impl.dart` — Supabase auth
- `lib/core/auth/admin_access.dart` — admin role checking

### Supabase
- `lib/services/supabase/supabase_initializer.dart` — initialization
- `lib/services/supabase/supabase_service.dart` — client provider

### Realtime
- `lib/services/realtime/realtime_service.dart` — centralized service
- `lib/services/realtime/realtime_channel_constants.dart` — channel names

### Notifications
- `lib/services/push_notification/push_notification_service.dart`
- `lib/shared/notifications/notification_channels.dart`
- `lib/shared/notifications/notification_route_resolver.dart`

### Configuration
- `lib/config/app_config.dart` — app configuration
- `lib/config/config_validator.dart` — validation
- `lib/config/supabase_config.dart` — Supabase config
- `lib/config/firebase_config.dart` — Firebase config

### Theme
- `lib/core/theme/app_theme.dart` — light + dark themes
- `lib/core/theme/app_colors.dart` — color palette
- `lib/core/theme/app_text_styles.dart` — typography

### Localization
- `lib/l10n/app_en.arb` — English
- `lib/l10n/app_ar.arb` — Arabic
- `lib/core/localization/locale_provider.dart` — locale state

### Shared Widgets
- `lib/shared/widgets/` — 34 reusable widgets
- `lib/shared/widgets/app_shell.dart` — customer app shell
- `lib/shared/widgets/premium_card.dart`, `premium_empty_state.dart`, etc.

### Domain Layer
- `lib/domain/entities/` — business entities
- `lib/domain/repositories/` — repository interfaces
- `lib/domain/usecases/` — use cases

### Data Layer
- `lib/data/datasources/remote/` — Supabase data sources
- `lib/data/datasources/local/` — local storage
- `lib/data/repositories/` — repository implementations
- `lib/data/models/` — data models

## App-Specific Code

### Customer App
- `lib/main.dart` — entry point
- `lib/app/app.dart` — MaterialApp
- `lib/module_registry.dart` — 28 modules
- `lib/features/home/` through `lib/features/welcome/`

### Admin App
- `lib/main_admin.dart` — entry point
- `lib/app/app_admin.dart` — MaterialApp
- `lib/module_registry_admin.dart` — 12 modules
- `lib/features/admin/` — all admin pages
- `lib/features/member_management/` — member operations
- `lib/services/admin/` — admin providers

## Future Apps (not built now)

### Driver Delwaqty
- Will share: auth, supabase, realtime, notifications, wallet, orders, commission
- Will own: GPS, availability, trip lifecycle, driver-specific realtime

### Partners Delwaqty
- Will share: auth, supabase, wallet, commission, notifications
- Will own: service management, bookings, business operations, analytics

## Database Rule
This extraction does NOT require database redesign.
Only create a migration if absolutely necessary.
The goal is application separation over the SAME backend.
