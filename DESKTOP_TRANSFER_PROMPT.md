# DELWAQTY - DESKTOP TRANSFER PROMPT

**Copy this entire document into OpenCode Desktop to continue development.**

---

=========================================================
DELWAQTY - GLOBAL SUPER PLATFORM
=========================================================

## Project Vision

Delwaqty is a **Global Super Platform** — a "Service Operating System" where every service (commerce, delivery, payments, maps, AI) is a plug-in on a shared platform kernel. Think of it as a super-app that unifies food delivery, grocery, pharmacy, electronics, furniture, fashion, flowers, and bakery into one platform with shared infrastructure.

**Target Markets:** Middle East (Arabic + English)
**Platform:** Mobile-first (Android, iOS) with web and desktop support

## Architecture

**Pattern:** Clean Architecture (Domain / Data / Presentation)
**State Management:** Riverpod (^2.5.1)
**Routing:** GoRouter (^14.0.2)
**Immutable Models:** Freezed + JSON Serializable
**Backend:** Supabase (PostgreSQL 14.5, Auth, Storage, Realtime)
**Testing:** mocktail (443 tests, all passing)
**Module System:** FeatureModule plugin architecture

## Folder Structure

```
delwaqty/
├── lib/
│   ├── main.dart                          # Entry point
│   ├── module_registry.dart               # Feature module registration
│   ├── app/app.dart                       # MaterialApp + AppShell
│   ├── config/                            # Service configurations (10 files)
│   │   ├── supabase_config_v2.dart        # Multi-env Supabase config
│   │   ├── firebase_config.dart           # Firebase services
│   │   ├── maps_config_v2.dart            # Google Maps
│   │   ├── cloudflare_config_v2.dart      # Cloudflare CDN/R2
│   │   ├── platform_config.dart           # Readiness aggregator
│   │   ├── environment.dart               # Environment enum
│   │   └── service_locator.dart           # Service locator
│   ├── core/                              # Platform kernel (58 files)
│   │   ├── constants/                     # App, API, storage keys
│   │   ├── database/                      # Base entities, pagination
│   │   ├── engines/                       # AI, Maps, Search engines
│   │   │   ├── ai/                        # Recommendation, pricing, fraud, routing
│   │   │   ├── maps/                      # Geofencing, tracking, dynamic pricing
│   │   │   └── search/                    # Search engine + index
│   │   ├── errors/                        # Failures, exceptions, error handler
│   │   ├── extensions/                    # String, Date, Context extensions
│   │   ├── localization/                  # Locale provider
│   │   ├── module/                        # FeatureModule, FeatureRegistry, BadgeAggregator
│   │   ├── observability/                 # Logger, analytics, feature flags, crash, perf, health
│   │   ├── router/                        # GoRouter app_router
│   │   ├── security/                      # Encryption, secure storage, session, authz, audit, validator, rate limiter
│   │   ├── theme/                         # Colors, spacing, icons, theme, text styles, elevation, animation
│   │   └── utils/                         # Validators, page transitions, icon mapper, currency/date formatters
│   ├── data/                              # Data layer (14 files)
│   │   ├── datasources/local/             # SharedPreferences, SecureStorage
│   │   ├── datasources/remote/            # Supabase Auth + Profile data sources
│   │   ├── models/                        # UserModel (freezed)
│   │   └── repositories/                  # Auth, User, Profile, Admin + 3 mocks
│   ├── domain/                            # Domain layer (21 files)
│   │   ├── entities/                      # User, Expense, Category, Notification (freezed)
│   │   ├── repositories/                  # 6 repository interfaces
│   │   └── usecases/                      # Auth, User, Profile use cases
│   ├── features/                          # Feature modules (101 files across 13 modules)
│   │   ├── admin/                         # Dashboard, Users, Merchants, Orders, Settings
│   │   ├── auth/                          # Login, Register, ForgotPassword
│   │   ├── categories/                    # Categories, AddCategory
│   │   ├── commerce/                      # Discovery, MerchantDetail, ProductDetail, Cart, Checkout, Orders
│   │   │   ├── domain/entities/           # Merchant, Product, Cart, Order, Review, Coupon, Favorite, etc. (36 files)
│   │   │   ├── domain/repositories/       # 8 repository interfaces
│   │   │   └── data/repositories/mock/    # 8 mock implementations
│   │   ├── expenses/                      # Expenses, AddExpense, ExpenseDetail
│   │   ├── home/                          # Home page
│   │   ├── notifications/                 # Notification center
│   │   ├── onboarding/                    # Onboarding flow
│   │   ├── profile/                       # Profile page
│   │   ├── reports/                       # Reports dashboard
│   │   ├── settings/                      # Settings page
│   │   ├── splash/                        # Splash screen
│   │   └── welcome/                       # Welcome page
│   ├── services/                          # Platform services (29 files, 15 services)
│   │   ├── admin/                         # AdminService + AdminProviders
│   │   ├── analytics/                     # Analytics service
│   │   ├── authentication/                # Auth service
│   │   ├── connectivity/                  # Network connectivity
│   │   ├── fcm/                           # Firebase Cloud Messaging
│   │   ├── image/                         # Image service
│   │   ├── location/                      # Location/GPS service
│   │   ├── logger/                        # App logger
│   │   ├── logging/                       # Logging service
│   │   ├── maps/                          # Maps + Google Maps service
│   │   ├── notification/                  # Notification service
│   │   ├── payment/                       # Payment service
│   │   ├── search/                        # Search service
│   │   ├── storage/                       # Storage + Cloudflare R2
│   │   └── supabase/                      # Supabase init + service
│   ├── shared/widgets/                    # 23 reusable widgets
│   └── l10n/                              # Localization (EN + AR)
├── supabase/
│   ├── config.toml                        # Supabase local config
│   └── migrations/001_initial_schema.sql  # Database schema (370 lines)
├── scripts/                               # 9 build/dev scripts
├── docs/                                  # 27+ documentation files
├── .github/workflows/                     # CI/CD (ci.yml + auto_sync.yml)
├── .env.dev                               # Development credentials
├── .env.staging                           # Staging credentials (template)
├── .env.prod                              # Production credentials (template)
├── pubspec.yaml                           # Dependencies
└── analysis_options.yaml                  # Lint rules
```

## Flutter Version

- **Flutter SDK:** ^3.12.2
- **Dart SDK:** ^3.12.2
- **Version:** 1.0.0+1

## Packages

### Runtime (16)
| Package | Purpose |
|---------|---------|
| flutter_riverpod ^2.5.1 | State management |
| go_router ^14.0.2 | Navigation/routing |
| freezed_annotation ^2.4.1 | Immutable data models |
| json_annotation ^4.9.0 | JSON serialization |
| shared_preferences ^2.2.3 | Local key-value storage |
| flutter_secure_storage ^9.0.0 | Encrypted storage |
| logger ^2.4.0 | Logging |
| supabase_flutter ^2.5.0 | Supabase backend |
| connectivity_plus ^6.0.3 | Network detection |
| google_maps_flutter ^2.10.0 | Maps |
| http ^1.2.0 | HTTP client |
| crypto ^3.0.3 | Cryptography |
| firebase_core ^2.30.1 | Firebase initialization |
| firebase_messaging ^14.8.2 | Push notifications |
| flutter_localizations (sdk) | i18n |
| intl ^0.20.2 | Date/number formatting |

### Dev (5)
| Package | Purpose |
|---------|---------|
| flutter_lints ^3.0.0 | Lint rules |
| mocktail ^1.0.4 | Mocking |
| build_runner ^2.4.9 | Code generation |
| freezed ^2.5.2 | Freezed codegen |
| json_serializable ^6.8.0 | JSON codegen |

## Feature Modules

13 registered modules via `FeatureModule` abstract class:

| Module | Pages | Description |
|--------|-------|-------------|
| admin | Dashboard, Users, Merchants, Orders, Settings | Admin panel |
| auth | Login, Register, ForgotPassword | Authentication |
| categories | Categories, AddCategory | Category management |
| commerce | Discovery, MerchantDetail, ProductDetail, Cart, Checkout, Orders | Full commerce |
| expenses | Expenses, AddExpense, ExpenseDetail | Expense tracking |
| home | Home | Main dashboard |
| notifications | NotificationCenter | Notifications |
| onboarding | Onboarding | First-time user flow |
| profile | Profile | User profile |
| reports | Reports | Analytics dashboard |
| settings | Settings | App settings |
| splash | Splash | App loading |
| welcome | Welcome | Welcome/landing |

## Commerce Engine

Full e-commerce domain with 8 entities and 8 repositories:

**Entities:** Merchant, Product, CatalogCategory, Cart, Order, Review, Coupon, Favorite
**Value Objects:** Money, GeoLocation, ImageSet, SearchFilter

All entities use Freezed for immutability + JSON serialization.

## Platform Services (15)

Admin, Analytics, Auth, Connectivity, FCM, Image, Location, Logger, Logging, Maps, Notification, Payment, Search, Storage (Cloudflare R2), Supabase.

## Navigation

GoRouter-based with dynamic route generation from FeatureRegistry. AppShell provides bottom navigation with badge aggregation.

## Dependency Injection

Riverpod providers throughout. Feature modules register their own providers. Service locator pattern in `lib/config/service_locator.dart`.

## Repositories

| Repository | Current | Target |
|------------|---------|--------|
| AuthRepository | Supabase AuthDataSource | Supabase |
| UserRepository | Mock | Supabase |
| ProfileRepository | Supabase ProfileDataSource | Supabase |
| AdminRepository | Supabase REST | Supabase |
| ExpenseRepository | Mock | Supabase |
| CategoryRepository | Mock | Supabase |
| NotificationRepository | Mock | Supabase |
| MerchantRepository | Mock | Supabase |
| ProductRepository | Mock | Supabase |
| CartRepository | Mock | Supabase |
| OrderRepository | Mock | Supabase |
| ReviewRepository | Mock | Supabase |
| CouponRepository | Mock | Supabase |
| FavoriteRepository | Mock | Supabase |

## Admin System

AdminService + AdminProviders with 5 pages (Dashboard, Users, Merchants, Orders, Settings). Connected to Supabase REST API via AdminRepository.

## AI Engine

5 services: AIService, RecommendationService, PricingService, FraudDetectionService, SmartRoutingService. Currently mock implementations.

## Maps Layer

Google Maps integration with geofencing, driver tracking, dynamic pricing zones. Config ready, needs API key.

## Payment Layer

PaymentService + PaymentServiceImplementation. Abstract interface ready, needs gateway integration (Stripe/Moyasar recommended).

## Security Layer

7 services: Encryption, SecureStorage, SessionManager, AuthorizationService, AuditLogger, InputValidator, RateLimiter.

## Testing Strategy

- **Framework:** mocktail + flutter_test
- **Coverage:** 443 tests, all passing
- **Pattern:** Unit tests for domain/data, widget tests for presentation
- **Convention:** Mirror lib/ structure in test/

## Build Workflow

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
bash scripts/build.sh
```

## Git Workflow

- **Branch:** master (single branch)
- **Commits:** Conventional format (type: description)
- **PR Template:** .github/PULL_REQUEST_TEMPLATE.md
- **CI:** Analyze → Build → Release (on merge to master)

## Current Sprint Status

| Sprint | Status |
|--------|--------|
| 1-9 | ✅ Complete |
| 10 (Infrastructure) | ✅ Complete |
| 11 (Admin Backend) | ✅ Complete |
| Infrastructure Integration (12 steps) | ✅ Complete |
| 12 (Real Supabase Repos) | NEXT |

## Known Issues

1. **Database tables not created** — Must run SQL in Supabase Dashboard
2. **All repos are mock** — Need Supabase implementations
3. **Firebase not connected** — Needs google-services.json
4. **Google Maps not functional** — Needs API key
5. **Assets empty** — No images, fonts, or icons yet
6. **Admin RLS too permissive** — Uses `USING (true)`

## Immediate Next Tasks

1. Deploy database schema (run `supabase/migrations/001_initial_schema.sql` in Supabase Dashboard)
2. Replace mock repos with Supabase implementations (start with User, Category, Expense)
3. Wire authentication flow (login → Supabase Auth → profile creation)
4. Add Firebase credentials
5. Add Google Maps API key
6. Populate assets

## Coding Standards

- No comments unless explicitly requested
- Prefer single quotes
- Require trailing commas
- Freezed for all immutable models
- Riverpod for state management
- Clean Architecture: Domain layer has zero framework imports
- Feature-first organization
- FeatureModule pattern for all features
