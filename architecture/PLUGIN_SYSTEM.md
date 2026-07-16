# PLUGIN_SYSTEM.md — Plugin Architecture

> **Authority:** PROJECT_CONSTITUTION.md §21
> **Version:** 2.0

---

## What is a Plugin?

A Plugin is a business capability that runs on top of the Platform Kernel. Plugins represent specific verticals (Restaurant, Pharmacy, Ride, etc.) that use Platform Engines to deliver their functionality.

---

## Plugin Definition

```dart
abstract interface class Plugin {
  /// Unique identifier
  String get id;

  /// Human-readable name
  String get name;

  /// Required Engines this Plugin depends on
  List<Type> get requiredEngines;

  /// Optional Engines this Plugin may use
  List<Type> get optionalEngines;

  /// Permissions this Plugin requires
  List<Permission> get permissions;

  /// Routes this Plugin registers
  List<RouteBase> get routes;

  /// Providers this Plugin registers
  List<Override> providerOverrides(Ref ref);

  /// Background tasks this Plugin runs
  List<BackgroundTask> get backgroundTasks;

  /// Initialize the Plugin
  Future<void> initialize(PlatformKernel kernel);

  /// Dispose the Plugin
  Future<void> dispose();
}
```

---

## Plugin Rules

| Rule | Description |
|------|-------------|
| No bypass | Plugin must use Platform Kernel for all operations |
| No cross-calls | Plugin must not directly call another Plugin |
| Through Platform | All cross-plugin communication via Platform Services or Events |
| Engine access | Plugin accesses Engines through `kernel.engine<T>()` |
| Event publish | Plugin publishes events to notify other Plugins |
| Event subscribe | Plugin subscribes to events from other Plugins |

---

## Plugin Lifecycle

```
Register → Initialize → Activate → [Running] → Deactivate → Dispose
```

| Phase | Description |
|-------|-------------|
| Register | Plugin registered with Platform Kernel |
| Initialize | Plugin sets up its services, providers, routes |
| Activate | Plugin becomes available to users |
| Running | Plugin handles user requests |
| Deactivate | Plugin becomes unavailable (e.g., maintenance) |
| Dispose | Plugin cleans up resources |

---

## Plugin Examples

### Restaurant Plugin

| Aspect | Detail |
|--------|--------|
| **Capabilities** | Menu management, table booking, food ordering, delivery tracking |
| **Required Engines** | Identity, Commerce, Maps, Notifications, Payments |
| **Optional Engines** | AI (recommendations), Analytics (ordering patterns) |
| **Permissions** | `merchant.create`, `order.create`, `delivery.track` |

### Pharmacy Plugin

| Aspect | Detail |
|--------|--------|
| **Capabilities** | Prescription management, medication catalog, delivery, consultation |
| **Required Engines** | Identity, Commerce, Notifications |
| **Optional Engines** | AI (drug interactions), Maps (delivery) |
| **Permissions** | `merchant.create`, `order.create`, `prescription.manage` |

### Ride Plugin

| Aspect | Detail |
|--------|--------|
| **Capabilities** | Ride request, driver matching, real-time tracking, fare calculation |
| **Required Engines** | Identity, Mobility, Maps, Payments, Notifications |
| **Optional Engines** | AI (route optimization), Analytics (demand prediction) |
| **Permissions** | `ride.request`, `driver.manage`, `trip.track` |

---

## Plugin Communication

Plugins communicate through the Platform Kernel:

```
Restaurant Plugin                    Ride Plugin
       │                                │
       ▼                                ▼
  ┌─────────────────────────────────────────┐
  │           PLATFORM KERNEL               │
  │                                         │
  │  Event: OrderPlaced                     │
  │    → Restaurant Plugin publishes        │
  │    → Ride Plugin subscribes             │
  │    → Dispatches driver                  │
  │                                         │
  │  Service: PaymentService                │
  │    → Restaurant Plugin charges          │
  │    → Ride Plugin charges                │
  │    → Both use same Payment Engine       │
  └─────────────────────────────────────────┘
```

---

## Migration from FeatureModule

Current `FeatureModule` evolves to `Plugin`:

1. Add `requiredEngines` and `optionalEngines`
2. Add `permissions` list
3. Add `initialize()` and `dispose()` lifecycle
4. Register with Platform Kernel instead of module registry
5. Existing routes and providers continue working
