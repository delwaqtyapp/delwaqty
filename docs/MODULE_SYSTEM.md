# Module System

Delwaqty uses a plugin-based module architecture. Every feature is a self-contained `FeatureModule` that registers its routes, providers, navigation entries, and lifecycle hooks with the platform core.

## Adding a New Module

1. Create `lib/features/my_feature/my_feature_module.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class MyFeatureModule extends FeatureModule {
  @override String get id => 'my_feature';
  @override String name(BuildContext ctx) => 'My Feature';
  @override IconData get icon => Icons.star_outline;
  @override bool get isNavModule => false;
  @override int get navPriority => 60;

  @override
  StatefulShellBranch? buildBranch() => StatefulShellBranch(
    routes: [GoRoute(path: '/my-feature', builder: (_, __) => MyFeaturePage())],
  );

  @override
  List<RouteBase> get shellSubRoutes => [
    GoRoute(path: '/my-feature/detail', builder: (_, __) => DetailPage()),
  ];

  @override
  List<DrawerEntry> get drawerEntries => [
    DrawerEntry(
      id: 'my_feature',
      label: (ctx) => 'My Feature',
      icon: Icons.star_outline,
      onTap: (ctx, ref) { Navigator.of(ctx).pop(); ctx.push('/my-feature'); },
    ),
  ];

  @override
  List<Override> providerOverrides(Ref ref) => [
    myFeatureRepoProvider.overrideWithValue(MockMyFeatureRepo()),
  ];
}
```

2. Register in `lib/module_registry.dart`:

```dart
registry.registerAll([
  // ...existing modules...
  MyFeatureModule(),
]);
```

3. Done. Routes, nav, drawer, and providers are all wired automatically.

## FeatureModule Contract

| Property | Purpose |
|---|---|
| `id` | Unique identifier (e.g. `'expenses'`, `'commerce'`) |
| `name(ctx)` | Display name (localized) |
| `icon` | Nav icon (null if not a nav module) |
| `isNavModule` | Whether this appears in bottom navigation |
| `navPriority` | Ordering in nav (lower = earlier) |
| `standaloneRoutes` | Routes outside the shell (login, splash) |
| `buildBranch()` | Bottom nav branch (null if not a nav module) |
| `shellSubRoutes` | Routes inside shell but not a nav tab |
| `drawerEntries` | Drawer navigation entries |
| `providerOverrides(ref)` | Riverpod provider overrides |
| `capabilities` | Declares optional capabilities |
| `badgeStream(ref)` | Badge count stream for nav/drawer |
| `dependsOn` | Module dependencies (topological sort) |

## Capabilities

Modules declare capabilities that the platform uses to enable/disable features:

- `searchable` — Module supports search
- `hasNotifications` — Module provides badge counts
- `hasLocation` — Module uses location services
- `hasPayments` — Module processes payments
- `hasAI` — Module uses AI Core
- `hasOfflineMode` — Module works offline
- `hasDeepLinks` — Module handles deep links

## Architecture

```
main.dart
  └─ registerAllModules()  →  FeatureRegistry.instance.registerAll([...])
  └─ registry.freeze()     →  topological sort, shell index assignment

app_router.dart
  └─ goRouterProvider reads FeatureRegistry
  └─ routes = standaloneRoutes + buildShellRoute() + shellSubRoutes

app_shell.dart
  └─ reads navModules for bottom nav
  └─ reads allDrawerEntries for drawer
  └─ subscribes to badgeAggregatorProvider
```

## Disabling a Module

Comment out the module in `module_registry.dart`:

```dart
registry.registerAll([
  SplashModule(),
  // CommerceModule(),  ← disabled
  // ...
]);
```

The app continues working without that module's routes, nav, and providers.
