# FEATURE_REGISTRY.md

> **Generated:** 2026-07-16 | **Sprint:** 11.5
> **Purpose:** Every feature module MUST register here before implementation.

---

## Registration Rules

1. Every new feature MUST extend `FeatureModule` abstract class
2. Every module MUST be registered in `lib/module_registry.dart`
3. Every module MUST have its own directory under `lib/features/`
4. Every module MUST have at least one test file
5. No module may modify core files to register itself

---

## Active Modules (Registered)

| Module | Directory | Files | Status | Sprint |
|--------|-----------|-------|--------|--------|
| Splash | `lib/features/splash/` | 2 | Active | 1 |
| Onboarding | `lib/features/onboarding/` | 2 | Active | 3 |
| Welcome | `lib/features/welcome/` | 2 | Active | 3 |
| Auth | `lib/features/auth/` | 7 | Active | 1 |
| Home | `lib/features/home/` | 2 | Active | 4 |
| Expenses | `lib/features/expenses/` | 4 | Active | 4 |
| Commerce | `lib/features/commerce/` | 66 | Active | 8 |
| Settings | `lib/features/settings/` | 2 | Active | 4 |
| Profile | `lib/features/profile/` | 2 | Active | 4 |
| Notifications | `lib/features/notifications/` | 2 | Active | 6 |
| Admin | `lib/features/admin/` | 7 | Active | 10 |
| **Categories** | `lib/features/categories/` | 2 | Active | 4 |

---

## Planned Modules (Not Yet Implemented)

### Commerce Verticals

| Module | Directory | Description | Priority | Sprint |
|--------|-----------|-------------|----------|--------|
| Restaurants | `lib/features/restaurants/` | Restaurant ordering, menus, delivery | High | 12+ |
| Grocery | `lib/features/grocery/` | Grocery delivery, bulk ordering | High | 12+ |
| Pharmacy | `lib/features/pharmacy/` | Medicine delivery, prescriptions | High | 12+ |
| Electronics | `lib/features/electronics/` | Electronics marketplace | Medium | 14+ |
| Furniture | `lib/features/furniture/` | Furniture marketplace | Medium | 14+ |
| Fashion | `lib/features/fashion/` | Fashion marketplace | Medium | 14+ |

### Service Verticals

| Module | Directory | Description | Priority | Sprint |
|--------|-----------|-------------|----------|--------|
| Ride | `lib/features/ride/` | Ride-hailing, taxi booking | High | 16 |
| Home Services | `lib/features/home_services/` | Plumbing, electrical, cleaning | High | 16 |
| Medical | `lib/features/medical/` | Telemedicine, appointment booking | Medium | 17 |
| Travel | `lib/features/travel/` | Hotel booking, flight booking | Medium | 18 |
| Education | `lib/features/education/` | Online courses, tutoring | Low | 20+ |

### Platform Features

| Module | Directory | Description | Priority | Sprint |
|--------|-----------|-------------|----------|--------|
| Wallet | `lib/features/wallet/` | Digital wallet, top-up, transfers | High | 16 |
| Payments | `lib/features/payments/` | Payment processing, receipts | High | 16 |
| AI | `lib/features/ai/` | AI-powered search, recommendations | High | 15 |
| Search | `lib/features/search/` | Full-text search, filters | Medium | 17 |
| Chat | `lib/features/chat/` | In-app messaging (user↔merchant, user↔driver) | Medium | 19 |
| Maps | `lib/features/maps/` | Map views, delivery tracking | High | 16 |
| Reviews | `lib/features/reviews/` | Rating and review system | Medium | 13 |
| Favorites | `lib/features/favorites/` | Saved items, wishlists | Low | 14 |
| Coupons | `lib/features/coupons/` | Discount codes, promotions | Low | 14 |
| Loyalty | `lib/features/loyalty/` | Points, rewards, tiers | Low | 18 |

### Admin Features

| Module | Directory | Description | Priority | Sprint |
|--------|-----------|-------------|----------|--------|
| Admin Dashboard | `lib/features/admin/dashboard/` | Real-time admin dashboard | High | 12 |
| Admin Users | `lib/features/admin/users/` | User management CRUD | High | 12 |
| Admin Merchants | `lib/features/admin/merchants/` | Merchant approval workflow | High | 12 |
| Admin Orders | `lib/features/admin/orders/` | Order dispute resolution | High | 13 |
| Admin Analytics | `lib/features/admin/analytics/` | Revenue, growth, performance | Medium | 13 |
| Admin Reports | `lib/features/admin/reports/` | Export reports (PDF, CSV) | Medium | 13 |
| Admin Security | `lib/features/admin/security/` | RBAC, audit logging, 2FA | Medium | 14 |

---

## Module Registration Template

```dart
// lib/features/my_feature/my_feature_module.dart

import 'package:delwaqty/core/module/feature_module.dart';

class MyFeatureModule extends FeatureModule {
  @override
  String get id => 'my_feature';

  @override
  String get name => 'My Feature';

  @override
  String get description => 'Description of the feature';

  @override
  List<String> get dependencies => []; // other module IDs

  @override
  void onRegister() {
    // Register routes, providers, services
  }

  @override
  void onActivate() {
    // Called when module becomes active
  }

  @override
  void onDeactivate() {
    // Called when module becomes inactive
  }
}
```

### Registration in module_registry.dart

```dart
import 'package:delwaqty/features/my_feature/my_feature_module.dart';

void registerAllModules() {
  final registry = FeatureRegistry.instance;
  registry.registerAll([
    // ... existing modules ...
    MyFeatureModule(),
  ]);
  registry.freeze();
}
```

---

## Module Dependency Graph

```
Core (always loaded)
├── Splash
│   └── Onboarding
│       └── Welcome
│           └── Auth
│               ├── Home
│               │   ├── Expenses
│               │   ├── Commerce
│               │   ├── Notifications
│               │   └── Settings
│               │       └── Profile
│               └── Admin
└── Commerce
    ├── Restaurants (planned)
    ├── Grocery (planned)
    ├── Pharmacy (planned)
    └── Ride (planned)
        └── Maps (planned)
            └── Location (planned)
```

---

## Adding a New Module — Checklist

- [ ] Create directory: `lib/features/<module_name>/`
- [ ] Create `<module_name>_module.dart` extending `FeatureModule`
- [ ] Implement required overrides: `id`, `name`, `description`, `dependencies`
- [ ] Implement lifecycle hooks: `onRegister`, `onActivate`, `onDeactivate`
- [ ] Create feature structure: `domain/`, `data/`, `presentation/`
- [ ] Create abstract repository interface in `domain/repositories/`
- [ ] Create mock implementation in `data/repositories/mock/`
- [ ] Create at least one test file in `test/features/<module_name>/`
- [ ] Register in `lib/module_registry.dart`
- [ ] Update this file (FEATURE_REGISTRY.md)
- [ ] Run `flutter pub get && flutter analyze && flutter test`
- [ ] Commit and push
