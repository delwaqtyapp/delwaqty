# Delwaqty - Desktop Handoff Guide

**Generated:** 2026-07-16
**Purpose:** Guide for continuing development on OpenCode Desktop

---

## Quick Start

1. Clone: `git clone https://github.com/delwaqtyapp/delwaqty.git`
2. Navigate: `cd delwaqty`
3. Get packages: `flutter pub get`
4. Run codegen: `dart run build_runner build --delete-conflicting-outputs`
5. Run: `flutter run`

## Project Structure

```
delwaqty/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── module_registry.dart         # Feature module registration
│   ├── app/                         # MaterialApp, AppShell
│   ├── config/                      # All service configurations
│   ├── core/                        # Platform kernel (theme, router, security, engines)
│   ├── data/                        # Data sources, models, repository implementations
│   ├── domain/                      # Entities, repository interfaces, use cases
│   ├── features/                    # Feature modules (13 modules)
│   ├── services/                    # Platform services (15 services)
│   ├── shared/                      # Reusable widgets (23 widgets)
│   └── l10n/                        # Localization (EN + AR)
├── supabase/migrations/             # Database schema
├── scripts/                         # Build/analyze/test scripts
├── docs/                            # All documentation
├── .github/                         # CI/CD workflows
├── .env.dev                         # Development credentials
├── pubspec.yaml                     # Dependencies
└── analysis_options.yaml            # Lint rules
```

## Architecture

- **Pattern:** Clean Architecture (Domain/Data/Presentation)
- **State Management:** Riverpod
- **Routing:** GoRouter
- **Models:** Freezed + JSON Serializable
- **Backend:** Supabase (PostgreSQL + Auth + Storage)
- **Module System:** FeatureModule abstract class → FeatureRegistry → AppShell

## Key Entry Points

| File | Purpose |
|------|---------|
| `lib/main.dart` | App bootstrap, Supabase init, module registration |
| `lib/module_registry.dart` | Register all feature modules |
| `lib/app/app.dart` | MaterialApp with theme, router, localization |
| `lib/core/router/app_router.dart` | GoRouter route definitions |
| `lib/config/platform_config.dart` | Service readiness checks |

## Development Commands

```bash
flutter pub get                          # Get dependencies
dart run build_runner build --delete-conflicting-outputs  # Code generation
flutter analyze                          # Static analysis
flutter test                             # Run all tests
bash scripts/build.sh                    # Build current platform
bash scripts/test.sh                     # Run tests with coverage
```

## What's Working

- Full Clean Architecture with 13 feature modules
- FeatureModule plugin system with dynamic routing
- Commerce engine (merchants, products, cart, orders, reviews, coupons)
- Admin backend with Supabase integration
- Material 3 design system with Arabic RTL support
- 443 tests passing
- CI/CD pipeline
- Multi-platform builds (Android, iOS, Linux, macOS, Windows, Web)

## What Needs Work

1. **Run SQL migration** (BLOCKED — IPv6-only DB from this env)
2. **Connect mock repos to real Supabase repos**
3. **Firebase integration** (needs google-services.json)
4. **Google Maps integration** (needs API key)
5. **Asset population** (images, fonts, icons)
6. **Payment gateway integration**
7. **Driver module real implementation**
8. **Real-time order tracking**
