# System Architecture

## Layer Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        PRESENTATION                             │
│  Features (pages, widgets, providers per module)                │
│  Shared widgets, animations, themes                             │
├─────────────────────────────────────────────────────────────────┤
│                        DOMAIN                                   │
│  Entities (Freezed), Repository interfaces, Use cases           │
├─────────────────────────────────────────────────────────────────┤
│                          DATA                                   │
│  Repository implementations, Mock repos, Data sources           │
│  Models (DTOs), Remote/Local data sources                       │
├─────────────────────────────────────────────────────────────────┤
│                         CORE                                    │
│  Module system, Router, Theme, L10n, Errors, Extensions         │
│  Shared services (Auth, Location, Payment, AI - abstract)       │
├─────────────────────────────────────────────────────────────────┤
│                      SERVICES                                   │
│  Connectivity, FCM, Logger, Supabase client                     │
└─────────────────────────────────────────────────────────────────┘
```

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
  └─ [Future modules...]
```

## Data Flow

```
Startup:
  main() → registerAllModules() → registry.freeze()
  ProviderScope overrides ← registry.collectOverrides()

Routing:
  GoRouter ← built from registry
    ├─ standaloneRoutes (splash, login, etc.)
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

Tier 2: MODULE (lazy, per-feature)
  Each module owns its repository + derived providers
  Provided via providerOverrides()

Tier 3: CROSS-MODULE
  badgeAggregatorProvider, totalUnreadProvider
```

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
