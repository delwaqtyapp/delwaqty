# Sprint 56 Report — Functional Bottom-Nav Restructure (4-Tab Layout)

**Date:** 2026-08-01
**Sprint:** 56
**Status:** Complete ✅
**Flutter SDK:** 3.44.6 (Dart 3.12.2)

---

## Goal

Replace the module-driven Home / Direct Delivery / Ride / Settings tab set with a professional 4-tab bottom navigation — **Home / Search / Orders / Profile** — moving Settings behind the Profile gear icon and relocating Delivery/Ride into the Home screen's services grid. The tab set remains fully module-driven via `FeatureRegistry.navModules`.

## Deliverables

| # | Area | Change |
|---|------|--------|
| 1 | SearchModule | Promoted to nav module: branch `/search` → existing commerce `SearchPage`; `navPriority` 100→20; name now from l10n (`search`). |
| 2 | OrdersModule (new) | `lib/features/orders/orders_module.dart`: nav branch `/orders` → existing commerce `OrdersPage`; `navPriority` 30; `dependsOn: ['commerce']`. |
| 3 | ProfileModule | Promoted to nav module: branch `/profile` → `ProfilePage`; `navPriority` 50→40; added **gear icon** in Profile AppBar → `push('/settings')`; drawer entry now `go('/profile')`. |
| 4 | SettingsModule | Demoted to non-nav (`isNavModule: false`); `/settings` moved from branch to `shellSubRoute` wrapped in `Scaffold` + `AppBar` (page stays a bare `ListView`). |
| 5 | DirectDeliveryModule | Demoted to non-nav; `/direct-delivery` kept as a `standaloneRoute`; page gained its own `AppBar` (title + back) since the shell AppBar is gone. |
| 6 | RideModule | Re-enabled in `module_registry.dart` (was commented out); demoted to non-nav with `/ride/book` as a `standaloneRoute` (RideBookingPage has its own back button); `/ride/tracking/:id`, `/ride/history` unchanged. |
| 7 | AppShell | Global AppBar removed; menu + notifications moved into Home header (new **menu button** opens the floating sidebar); `extendBody: true` → `false` so branch pages with own Scaffolds are never overlapped by the floating pill; Home bottom spacer 100→24. |
| 8 | Home grid | Search bar now `context.go('/search')` (switches tab instead of pushing a duplicate); delivery tile fixed to push `/direct-delivery` (was incorrectly `/ride/book`); ride tile keeps `/ride/book` (now resolves). |
| 9 | Router | `restrictedRoutes` in `app_router.dart` now includes `/orders` (guests → login). `module_registry.dart` registers `OrdersModule` + `RideModule`. |
| 10 | Sidebar/Settings refs | Floating sidebar `/profile` targets use `_navigateReplace` (tab switch); Settings "Profile" tile uses `go('/profile')`. |

## Files Touched

- `lib/features/search/search_module.dart` — nav module + `/search` branch
- `lib/features/orders/orders_module.dart` — **new** nav module + `/orders` branch
- `lib/features/profile/profile_module.dart` — nav module + `/profile` branch + drawer `go`
- `lib/features/settings/settings_module.dart` — non-nav, `/settings` shellSubRoute
- `lib/features/delivery/delivery_module.dart` — non-nav, `/direct-delivery` standalone
- `lib/features/ride/ride_module.dart` — non-nav, `/ride/book` standalone
- `lib/module_registry.dart` — register OrdersModule, re-enable RideModule
- `lib/core/router/app_router.dart` — `/orders` restricted
- `lib/shared/widgets/app_shell.dart` — AppBar removed, `extendBody` false
- `lib/features/home/presentation/pages/home_page.dart` — menu button, search `go`, delivery tile, spacer
- `lib/features/profile/presentation/pages/profile_page.dart` — settings gear action
- `lib/features/delivery/presentation/pages/direct_delivery_page.dart` — AppBar added
- `lib/features/floating_sidebar/floating_sidebar_overlay.dart` — `/profile` → `_navigateReplace`
- `lib/features/settings/presentation/pages/settings_page.dart` — Profile tile → `go`

## Quality Gates

| Check | Result |
|-------|--------|
| `flutter analyze` | 0 errors |
| `flutter test` | 517/517 passing |
| APK build | `app-debug.apk` rebuilt (debug, `.env.dev`) |
| Device install | Installed on DNP NX9 (`A3SQUT5A28003808`) |
| Device smoke test | App launches; all 4 tabs tapped; no FATAL/`E/flutter` in logcat |

## Decision & Follow-ups

- **Decision:** navigation stays module-driven (tab set = registration + `navPriority`), existing `SearchPage`/`OrdersPage` reused (no placeholder scaffolds), secondary services reachable via Home grid + Profile gear. See `docs/DECISION_LOG.md` ADR-035.
- `Follow-up (release):` run `flutter build apk --release` then `flutter install` when the user is ready to ship.
- Optional follow-up: add a tab-aware page-transition or per-tab badge counts (orders/notifications) on the floating pill.

**Commit:** `feat(nav): redesign bottom navigation to professional 4-tab layout`
