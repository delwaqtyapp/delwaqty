# DEPENDENCY_RULES.md — Dependency and Coupling Rules

> **Authority:** PROJECT_CONSTITUTION.md §4
> **Version:** 2.0

---

## Fundamental Rules

| Rule | Description |
|------|-------------|
| **No Plugin-to-Plugin calls** | Plugins must never directly reference each other |
| **Through Kernel only** | All cross-cutting communication goes through Platform Kernel |
| **Engine isolation** | Engines communicate only via events or shared interfaces |
| **Domain purity** | Domain layer has zero framework imports |
| **DI everywhere** | All dependencies injected via Riverpod |

---

## Dependency Direction

```
Presentation → Domain ← Data
     │           │          │
     │           │          │
     ▼           ▼          ▼
  Riverpod   Interfaces  Implementations
```

| Layer | Can Import | Cannot Import |
|-------|-----------|---------------|
| Domain | Pure Dart only | Flutter, Supabase, Firebase, any framework |
| Data | Domain, external SDKs | Presentation, other features |
| Presentation | Domain, shared widgets | Data implementations directly |

---

## Engine Dependencies

```
         ┌─────────────────┐
         │ Identity Engine │ (foundational, no deps)
         └────────┬────────┘
                  │
    ┌─────────────┼─────────────────┐
    │             │                 │
    ▼             ▼                 ▼
Commerce     Payments          Notifications
 Engine        Engine             Engine
    │             │                 │
    │             │                 │
    ▼             ▼                 ▼
Marketplace  Mobility          Home Services
 Engine        Engine             Engine
                  │
                  ▼
              Maps Engine
```

---

## Plugin Dependencies

```
Restaurant Plugin
    ├── Requires: Identity, Commerce, Maps, Notifications, Payments
    ├── Optional: AI, Analytics
    └── Forbidden: Ride Plugin, Pharmacy Plugin (no cross-plugin)

Ride Plugin
    ├── Requires: Identity, Mobility, Maps, Payments, Notifications
    ├── Optional: AI, Analytics
    └── Forbidden: Restaurant Plugin, Pharmacy Plugin (no cross-plugin)
```

---

## Forbidden Patterns

| Pattern | Why | Alternative |
|---------|-----|-------------|
| `restaurantPlugin.orderService` | Direct plugin coupling | `kernel.engine<CommerceEngine>().createOrder()` |
| `import 'package:ride/...'` in restaurant | Cross-plugin import | Event: `OrderPlaced` → Kernel → Ride Plugin |
| `SupabaseClient` in domain | Framework in domain | Repository interface in domain, impl in data |
| Hardcoded provider | Not testable | Riverpod provider injection |
| Singleton service | Not mockable | Riverpod provider |

---

## Allowed Patterns

| Pattern | Example |
|---------|---------|
| Engine → Engine (via events) | Commerce Engine publishes `OrderCreated`, Mobility Engine subscribes |
| Plugin → Engine | Restaurant Plugin calls `kernel.engine<PaymentsEngine>().charge()` |
| Plugin → Kernel | Restaurant Plugin calls `kernel.publish(OrderPlaced(...))` |
| Kernel → Engine | Kernel initializes all Engines at startup |
| Plugin → Event Bus | Restaurant Plugin subscribes to `PaymentCompleted` |

---

## Testing Dependencies

| Component | Mock Strategy |
|-----------|--------------|
| Engine | Mock interface, verify interactions |
| Plugin | Mock Kernel, mock required Engines |
| Repository | Mock interface, use mocktail |
| External service | Never mock in domain tests |
