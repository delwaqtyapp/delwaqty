# KERNEL.md — Platform Kernel Architecture

> **Authority:** PROJECT_CONSTITUTION.md §19
> **Version:** 2.0

---

## What is the Platform Kernel?

The Platform Kernel is the **logical core** of Delwaqty. It is NOT an operating system kernel. It is the architectural foundation that every feature runs on top of.

**Core Principle:** Every business feature must run on top of one shared Platform Core. No feature may bypass the Platform Core.

---

## Kernel Responsibilities

| Responsibility | Description |
|----------------|-------------|
| Engine Orchestration | Manages lifecycle of all Platform Engines |
| Event Bus | Routes events between Engines and Plugins |
| Service Registry | Discovers and provides access to all Platform Services |
| Authentication Gate | All requests pass through Identity Engine |
| Authorization Gate | All resource access checked by Identity Engine |
| Plugin Lifecycle | Manages registration, activation, deactivation of Plugins |
| Configuration | Centralized configuration management |
| Dependency Injection | Riverpod-based DI for all components |

---

## Kernel Components

```
┌─────────────────────────────────────────────────┐
│                 PLATFORM KERNEL                  │
├─────────────────────────────────────────────────┤
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
│  │ Identity │  │ Commerce │  │ Payments │      │
│  │  Engine  │  │  Engine  │  │  Engine  │      │
│  └──────────┘  └──────────┘  └──────────┘      │
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
│  │   Maps   │  │  Search  │  │Notifica- │      │
│  │  Engine  │  │  Engine  │  │tion Eng. │      │
│  └──────────┘  └──────────┘  └──────────┘      │
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
│  │Analytics │  │ Logging  │  │    AI    │      │
│  │  Engine  │  │  Engine  │  │  Engine  │      │
│  └──────────┘  └──────────┘  └──────────┘      │
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
│  │ Storage  │  │ Mobility │  │  Home    │      │
│  │  Engine  │  │  Engine  │  │Services  │      │
│  └──────────┘  └──────────┘  └──────────┘      │
│                                                  │
│  ┌──────────┐  ┌──────────┐                     │
│  │Market-   │  │  Event   │                     │
│  │place Eng.│  │   Bus    │                     │
│  └──────────┘  └──────────┘                     │
│                                                  │
├─────────────────────────────────────────────────┤
│              PLUGIN LAYER                       │
│  Restaurant │ Pharmacy │ Grocery │ Ride │ ...   │
└─────────────────────────────────────────────────┘
```

---

## Kernel API

The Kernel exposes a minimal public API:

```dart
abstract interface class PlatformKernel {
  /// Access any Engine by type
  T engine<T extends PlatformEngine>();

  /// Publish an event to the Event Bus
  Future<void> publish(PlatformEvent event);

  /// Subscribe to events
  Stream<PlatformEvent> subscribe<T extends PlatformEvent>();

  /// Register a Plugin
  Future<void> registerPlugin(Plugin plugin);

  /// Get current authenticated user
  AuthContext? get currentAuth;

  /// Check authorization
  Future<bool> authorize(Permission permission);
}
```

---

## Design Principles

| Principle | Description |
|-----------|-------------|
| Minimal Surface | Kernel exposes only what Plugins need |
| Engine Isolation | Engines don't know about each other directly |
| Event-Driven | Cross-cutting communication via events |
| Lazy Loading | Engines initialized on first access |
| Graceful Degradation | Engine failure doesn't crash the Kernel |
| Testable | Every component mockable for testing |

---

## Migration Path

The current `FeatureModule` system evolves into the Plugin system:

1. Current: `FeatureModule` registers routes and providers
2. Future: `Plugin` registers capabilities, engines, and routes
3. Migration: Wrap existing modules as Plugins, then enhance

No breaking changes. Incremental adoption.
