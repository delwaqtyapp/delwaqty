# Module Reference

Delwaqty uses a plugin-based module architecture. Every feature is a self-contained `FeatureModule` that registers its routes, providers, navigation entries, and lifecycle hooks with the platform core.

**GitHub:** https://github.com/delwaqtyapp/delwaqty

## Registered Modules (11)

| Module | ID | Nav Tab | Priority | Capabilities | Routes |
|--------|----|---------|----------|--------------|--------|
| SplashModule | `splash` | No | — | — | `/splash` |
| OnboardingModule | `onboarding` | No | — | — | `/onboarding` |
| WelcomeModule | `welcome` | No | — | — | `/welcome` |
| AuthModule | `auth` | No | — | — | `/login`, `/register`, `/forgot-password` |
| HomeModule | `home` | Yes | 10 | — | `/home` |
| ExpensesModule | `expenses` | Yes | 20 | — | `/expenses` |
| CommerceModule | `commerce` | No | — | `hasDeepLinks` | `/market/*` |
| SettingsModule | `settings` | Yes | 90 | — | `/settings` |
| ProfileModule | `profile` | No | — | — | `/profile` |
| NotificationsModule | `notifications` | No | 55 | `hasNotifications` | `/notifications` |
| AdminModule | `admin` | No | 100 | `searchable`, `hasNotifications` | `/admin/*` |

> **Note:** The `categories` and `reports` features exist in `lib/features/` but do not yet have `FeatureModule` implementations registered in the module registry.

---

## Module Details

### SplashModule
**File:** `lib/features/splash/splash_module.dart`
**Route:** `/splash`
**Purpose:** App initialization and routing decision (onboarding → auth → home)

### OnboardingModule
**File:** `lib/features/onboarding/onboarding_module.dart`
**Route:** `/onboarding`
**Purpose:** 4-page onboarding flow shown on first launch

### WelcomeModule
**File:** `lib/features/welcome/welcome_module.dart`
**Route:** `/welcome`
**Purpose:** Landing page with login/register/guest entry points

### AuthModule
**File:** `lib/features/auth/auth_module.dart`
**Routes:** `/login`, `/register`, `/forgot-password`
**Purpose:** Authentication flow with Supabase backend
**Providers:** Auth state management via Riverpod

### HomeModule
**File:** `lib/features/home/home_module.dart`
**Route:** `/home` (nav tab, priority 10)
**Purpose:** Main dashboard and navigation hub

### ExpensesModule
**File:** `lib/features/expenses/expenses_module.dart`
**Route:** `/expenses` (nav tab, priority 20)
**Purpose:** Personal expense tracking with categories
**Providers:** Expense repository, category repository

### CommerceModule
**File:** `lib/features/commerce/commerce_module.dart`
**Routes:** `/market`, `/market/merchant/:id`, `/market/merchant/:id/product/:productId`, `/market/cart`, `/market/checkout`, `/market/orders`
**Purpose:** Generic, merchant-type-agnostic commerce engine
**Providers:** 8 repository providers (merchant, product, category, cart, order, review, coupon, favorite)
**Capabilities:** `hasDeepLinks`
**Design:** All routes are standalone (not shell-wrapped) for deep link support

### SettingsModule
**File:** `lib/features/settings/settings_module.dart`
**Route:** `/settings` (nav tab, priority 90)
**Purpose:** Theme, language, notification preferences

### ProfileModule
**File:** `lib/features/profile/profile_module.dart`
**Route:** `/profile` (drawer entry)
**Purpose:** User profile view and edit

### NotificationsModule
**File:** `lib/features/notifications/notifications_module.dart`
**Route:** `/notifications` (drawer entry)
**Purpose:** In-app notification center with badge counts
**Providers:** Notification repository, unread count provider
**Capabilities:** `hasNotifications`

### AdminModule
**File:** `lib/features/admin/admin_module.dart`
**Routes:** `/admin` (dashboard), `/admin/users`, `/admin/merchants`, `/admin/orders`, `/admin/settings`
**Purpose:** Super admin platform for managing the entire Delwaqty ecosystem
**Capabilities:** `searchable`, `hasNotifications`
**Design:** Standalone routes (not shell-wrapped), accessible via direct URL

---

## Sprint 10: Workspace Setup + Infrastructure

Sprint 10 finalized the workspace configuration and build infrastructure:

### Workspace
- **Location:** `/root/Projects/delwaqty` (140MB)
- **Git:** 12 commits on `master` branch
- **GitHub:** https://github.com/delwaqtyapp/delwaqty
- **Config files:** `lib/config/` — Supabase, Google Maps, Cloudflare, Environment, Service Locator

### Build Infrastructure
- `build.sh` — Full build pipeline (analyze → test → debug APK)
- `scripts/dev_build.sh` — Quick dev build
- `scripts/test_and_build.sh` — Test + release build
- `scripts/setup_git_remote.sh` — One-command GitHub setup

### Environment Configuration
All secrets injected via `--dart-define` or `.env` file:
- Supabase: dev/staging/prod URLs and anon keys
- Google Maps: API key with Saudi Arabia defaults
- Cloudflare: R2 bucket and CDN domain

### Commerce Engine Polish
Sprint 10 also completed the commerce presentation layer:
- 7 reusable widgets (MerchantCard, ProductCard, CartBadge, etc.)
- 6 presentation screens (discovery through checkout)
- Mock data for 5 Saudi merchants (Al Baik, Tamimi, Nahdi, Jarir, IKEA)

---

## Sprint 11: Infrastructure Integration

- [x] GitHub repository setup (https://github.com/delwaqtyapp/delwaqty)
- [x] Multi-environment configuration (.env.dev, .env.staging, .env.prod)
- [x] Security documentation (SECURITY.md)
- [x] API plan documentation (API_PLAN.md)
- [x] Database plan documentation (DATABASE_PLAN.md)
- [x] Workspace setup documentation (WORKSPACE_SETUP.md)
- [ ] Supabase project provisioning
- [ ] Cloudflare R2 bucket configuration
- [ ] GitHub Actions CI/CD pipeline

---

## Adding a New Module

1. Create `lib/features/{name}/{name}_module.dart`
2. Implement `FeatureModule` interface
3. Define routes, capabilities, and provider overrides
4. Register in `lib/module_registry.dart`
5. Done — routes, navigation, and providers are wired automatically

See `docs/MODULE_SYSTEM.md` for the full FeatureModule contract and step-by-step guide.
