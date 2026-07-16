# System Architecture

## Layer Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        PRESENTATION                                 │
│  Features (pages, widgets, providers per module)                    │
│  Shared widgets, animations, themes                                 │
│  Commerce widgets (7 reusable components)                           │
│  Commerce screens (6 presentation screens)                          │
│  Admin panel (5 screens)                                            │
├─────────────────────────────────────────────────────────────────────┤
│                          DOMAIN                                     │
│  Entities (Freezed), Repository interfaces, Use cases               │
│  Commerce: 15 entities, 8 repository interfaces                    │
│  Admin: 5 domain models                                            │
├─────────────────────────────────────────────────────────────────────┤
│                          DATA                                       │
│  Repository implementations, Mock repos, Data sources               │
│  Models (DTOs), Remote/Local data sources                           │
│  Supabase data sources, FCM service                                │
├─────────────────────────────────────────────────────────────────────┤
│                         CORE                                        │
│  Module system, Router, Theme, L10n, Errors, Extensions             │
│  Engines (AI, Maps, Search), Observability, Security                │
│  Database patterns, Platform services                               │
├─────────────────────────────────────────────────────────────────────┤
│                       CONFIG                                        │
│  Environment, Supabase, Google Maps, Cloudflare, Service Locator    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Design System

Unified visual identity layer with semantic tokens.

### Color Tokens (AppColors)

| Category | Tokens |
|----------|--------|
| Core Brand | primaryLight/Dark, secondaryLight/Dark, tertiaryLight/Dark, errorLight/Dark |
| Semantic | success, warning, info, link (light/dark variants) |
| Surface Variants | surface, surfaceDim, surfaceBright, surfaceContainer (lowest/low/mid/high/highest) |
| Merchant Types | food, grocery, pharmacy, electronics, fashion, furniture |
| Order Status | pending, confirmed, preparing, ready, inTransit, delivered, cancelled |
| Rating | amber star rating color |

### Spacing System (AppSpacing)

`xxs` (2), `xs` (4), `sm` (8), `md` (12), `lg` (16), `xl` (24), `xxl` (32), `xxxl` (48), `huge` (64)

### Theme Provider

ThemeMode persistence via SharedPreferences with Riverpod provider. Automatic light/dark theme switching.

---

## Platform Services (12 Abstract Interfaces)

| Service | File | Purpose |
|---------|------|---------|
| ConnectivityService | `lib/core/services/connectivity_service.dart` | Network monitoring with stream-based online/offline state |
| SecureStorageService | `lib/core/security/secure_storage_service.dart` | AES-256 encrypted storage (FlutterSecureStorage) |
| SharedPreferencesService | `lib/core/services/shared_preferences_service.dart` | Lightweight key-value storage for preferences |
| LocationService | `lib/core/engines/maps/map_engine.dart` | GPS, geocoding, address resolution |
| NotificationService | `lib/features/notifications/` | Push notification infrastructure (FCM) |
| PaymentService | `lib/core/services/` | Multi-method payment processing (Mada, STC Pay, Apple Pay, COD) |
| AuthService | `lib/features/auth/` | Supabase-backed auth with JWT tokens |
| AnalyticsService | `lib/core/observability/app_analytics.dart` | Event tracking, screen views, e-commerce events |
| LoggingService | `lib/core/observability/app_logger.dart` | Structured logging with crash-report buffer |
| StorageService | `lib/config/cloudflare_config.dart` | R2/CDN asset storage and delivery |
| ImageService | `lib/core/services/` | Image upload, processing, and CDN delivery |
| SearchService | `lib/core/engines/search/search_engine.dart` | Full-text search, autocomplete, voice search, semantic search |

---

## Observability Layer

| Component | File | Purpose |
|-----------|------|---------|
| AppLogger | `lib/core/observability/app_logger.dart` | Singleton logger with 6 log levels, 500-entry crash buffer |
| AppAnalytics | `lib/core/observability/app_analytics.dart` | Analytics abstraction (Firebase, Amplitude, Mixpanel) |
| FeatureFlags | `lib/core/observability/feature_flags.dart` | Typed flag access with remote refresh and change streams |
| CrashReporter | `lib/core/observability/crash_reporter.dart` | Exception capture, breadcrumbs, user context (Sentry, Crashlytics) |
| PerformanceMonitor | `lib/core/observability/performance_monitor.dart` | Named traces, custom metrics, timing instrumentation |
| HealthCheckService | `lib/core/observability/health_check.dart` | Registered health checks with aggregate status |

Each component provides debug, no-op, and production implementations.

---

## Security Layer

| Component | File | Purpose |
|-----------|------|---------|
| EncryptionService | `lib/core/security/encryption_service.dart` | Symmetric encryption, password hashing, secure random generation |
| SecureStorageService | `lib/core/security/secure_storage_service.dart` | AES-256 (Android) / Keychain (iOS) encrypted storage |
| SessionManager | `lib/core/security/session_manager.dart` | Session creation, validation, refresh, expiration |
| AuthorizationService | `lib/core/security/authorization_service.dart` | RBAC with resource-level access control |
| AuditLogger | `lib/core/security/audit_logger.dart` | Who-did-what-when audit trail with export (JSON/CSV) |
| InputValidator | `lib/core/security/input_validator.dart` | Field validation, HTML/SQL sanitization |
| RateLimiter | `lib/core/security/rate_limiter.dart` | Sliding-window rate limiting per key |

Each component provides a real implementation and a no-op/test implementation.

---

## Database Patterns

```
┌──────────────────────────────────────────────────────────────────┐
│  BaseEntity                                                      │
│  ├─ id: UUID v4                                                  │
│  ├─ createdAt: DateTime                                          │
│  ├─ updatedAt: DateTime                                          │
│  ├─ deletedAt: DateTime?  (Soft Delete)                          │
│  ├─ version: int  (Optimistic Concurrency)                       │
│  └─ metadata: Map<String, dynamic>                               │
├──────────────────────────────────────────────────────────────────┤
│  UuidGenerator      UUID-based entity identification             │
│  SoftDeletable      deletedAt filter pattern                     │
│  Auditable          Who/when tracking for changes                │
│  Pagination         Offset/limit pagination support              │
│  SortParams         Configurable sort order                      │
└──────────────────────────────────────────────────────────────────┘
```

### Supabase Integration
- UUID-based entity identification (`gen_random_uuid()`)
- Row Level Security (RLS) for data access control
- Real-time subscriptions available for live updates
- Foreign key relationships between tables

### Repository Pattern
```
Domain: Abstract interface → Data: Mock impl / Real impl → Provider override at app level
```

---

## Engines

### AI Engine (`lib/core/engines/ai/`)

Provider-agnostic AI abstraction. Supports OpenAI, Gemini, Claude, or local models.

| Service | Purpose |
|---------|---------|
| AIService | Text analysis, generation, classification, entity extraction, translation, embedding, chat |
| RecommendationService | Personalized recommendations, similar items, trending, interaction tracking |
| PricingService | Dynamic pricing, surge multipliers, promotions, coupon application |
| FraudDetectionService | Transaction analysis, behavioral risk, user blocking |
| SmartRoutingService | Route optimization, ETA prediction, driver matching, load balancing, traffic |

### Map Engine (`lib/core/engines/maps/`)

Abstract maps with platform-agnostic design.

| Service | Purpose |
|---------|---------|
| MapEngine | Route calculation, ETA, nearby search, geocoding, reverse geocoding, static maps, polygons |
| GeofencingService | Create/remove geofences, boundary monitoring, enter/exit/dwell events |
| DriverTrackingService | Real-time driver location, heatmap generation, active driver counts |
| DynamicPricingZoneService | Geographic pricing zones with configurable multipliers |

Default location: Riyadh, Saudi Arabia (24.7136, 46.6753)

### Search Engine (`lib/core/engines/search/`)

Unified search across all modules.

| Service | Purpose |
|---------|---------|
| SearchEngine | Full-text search, autocomplete, voice search, semantic search, search history |
| SearchIndex | Index creation, document management, schema config, index statistics |

---

## Module System

Every feature is a `FeatureModule` plugin:

```
FeatureRegistry (singleton)
  ├─ SplashModule
  ├─ OnboardingModule
  ├─ WelcomeModule
  ├─ AuthModule
  ├─ HomeModule         (nav tab, priority 10)
  ├─ ExpensesModule     (nav tab, priority 20)
  ├─ SettingsModule     (nav tab, priority 90)
  ├─ ProfileModule      (drawer only)
  ├─ NotificationsModule (drawer only, badge)
  ├─ CommerceModule     (deep links)
  ├─ AdminModule        (standalone routes)
  └─ [Future modules...]
```

### Registered Modules (11)

| Module | Routes | Capabilities |
|--------|--------|-------------|
| SplashModule | `/splash` | — |
| OnboardingModule | `/onboarding` | — |
| WelcomeModule | `/welcome` | — |
| AuthModule | `/login`, `/register`, `/forgot-password` | — |
| HomeModule | `/home` (nav, priority 10) | — |
| ExpensesModule | `/expenses` (nav, priority 20) | — |
| CommerceModule | `/market/*` | `hasDeepLinks` |
| SettingsModule | `/settings` (nav, priority 90) | — |
| ProfileModule | `/profile` | — |
| NotificationsModule | `/notifications` | `hasNotifications` |
| AdminModule | `/admin/*` | `searchable`, `hasNotifications` |

---

## Commerce Engine

Generic, merchant-type-agnostic commerce supporting 8+ merchant types.

### Domain (15 Freezed Entities)
Merchant, Product, ProductVariant, Category, Cart, CartItem, Order, OrderItem, OrderStatus, Review, Coupon, Favorite, MerchantType, Money, MoneyRange

### Repository Interfaces (8)
MerchantRepository, ProductRepository, CategoryRepository, CartRepository, OrderRepository, ReviewRepository, CouponRepository, FavoriteRepository

### Presentation (7 Widgets + 6 Screens)
Widgets: MerchantCard, ProductCard, CartBadge, RatingStars, PriceTag, DeliveryInfo, MerchantTypeChip
Screens: CommerceDiscoveryPage, MerchantDetailPage, ProductDetailPage, CartPage, CheckoutPage, OrdersPage

### Supported Merchant Types
Food (restaurants), Grocery, Pharmacy, Electronics, Furniture, Fashion, Flowers, Bakery

---

## Data Flow

```
Startup:
  main() → registerAllModules() → registry.freeze()
  ProviderScope overrides ← registry.collectOverrides()

Routing:
  GoRouter ← built from registry
    ├─ standaloneRoutes (splash, login, commerce)
    ├─ buildShellRoute() (nav modules → branches)
    └─ shellSubRoutes (profile, notifications, etc.)

Navigation:
  AppShell ← reads navModules for bottom nav
  AppShell ← reads allDrawerEntries for drawer
  BadgeAggregator ← merges badge streams from all modules
```

## Provider Architecture

```
Tier 1: CORE (always loaded)
  AuthRepository, UserRepository, ProfileRepository
  ConnectivityService, ThemeMode, Locale
  AppLogger, AppAnalytics, FeatureFlags

Tier 2: MODULE (lazy, per-feature)
  Each module owns its repository + derived providers
  Provided via providerOverrides()

Tier 3: CROSS-MODULE
  badgeAggregatorProvider, totalUnreadProvider
```

---

## Environment Configuration

### Multi-Environment Setup

| Environment | File | Purpose |
|-------------|------|---------|
| Development | `.env.dev` | Local development with Supabase dev project |
| Staging | `.env.staging` | Pre-production testing |
| Production | `.env.prod` | Live production environment |
| Template | `.env.example` | Reference for all required variables |

### Supabase (Primary Database)

| Variable | Purpose | Injected Via |
|----------|---------|-------------|
| SUPABASE_DEV_URL | Dev database URL | --dart-define |
| SUPABASE_DEV_ANON_KEY | Dev auth key | --dart-define |
| SUPABASE_STAGING_URL | Staging database URL | --dart-define |
| SUPABASE_STAGING_ANON_KEY | Staging auth key | --dart-define |
| SUPABASE_PROD_URL | Production database URL | --dart-define |
| SUPABASE_PROD_ANON_KEY | Production auth key | --dart-define |

Config: `lib/config/supabase_config.dart` — auto-selects dev/staging/prod based on build mode and environment.

### Google Maps

| Variable | Purpose | Injected Via |
|----------|---------|-------------|
| GOOGLE_MAPS_API_KEY | Maps SDK, Directions, Places, Geocoding | --dart-define |

Config: `lib/config/maps_config.dart` — default center: Riyadh, Saudi Arabia (24.7136, 46.6753).

### Cloudflare (CDN/Storage, NOT replacing Supabase)

| Variable | Purpose | Injected Via |
|----------|---------|-------------|
| CLOUDFLARE_API_TOKEN | API access | --dart-define |
| CLOUDFLARE_ACCOUNT_ID | Account identification | --dart-define |
| CLOUDFLARE_R2_BUCKET | Asset storage bucket | --dart-define |
| CLOUDFLARE_CDN_DOMAIN | CDN delivery domain | --dart-define |

Config: `lib/config/cloudflare_config.dart` — R2 for storage, CDN for delivery.

### Environment

Config: `lib/config/environment.dart` — development/staging/production enum with automatic config selection.

---

## APK Workflow

### Build Scripts

| Script | Purpose |
|--------|---------|
| `build.sh` | Full build: pub get → analyze → test → debug APK → releases/ |
| `scripts/dev_build.sh` | Quick dev build without full test suite |
| `scripts/test_and_build.sh` | Test first, then build release APK |
| `scripts/setup_git_remote.sh` | Configure GitHub remote with branch push |

### Usage
```bash
./build.sh              # Full build (analyze + test + debug APK)
./build.sh --release    # Release APK
./build.sh --test       # Test first, then build
./scripts/dev_build.sh  # Quick dev build
```

### Releases
APKs are output to `releases/Delwaqty-Latest.apk`.

---

## Adding a Feature (10 steps)

1. Create `lib/features/{name}/{name}_module.dart`
2. Implement `FeatureModule` interface
3. Create domain entities (Freezed)
4. Create repository interfaces
5. Create mock repository
6. Create presentation pages
7. Create provider overrides
8. Register in `module_registry.dart`
9. Run `flutter gen-l10n` if adding l10n strings
10. Run `dart run build_runner build` if using Freezed

No core files need modification.
