# EVENT_ARCHITECTURE.md — Event-Driven Communication

> **Authority:** PROJECT_CONSTITUTION.md §19
> **Version:** 2.0

---

## Purpose

The Event Bus enables loose coupling between Engines and Plugins. Components communicate by publishing and subscribing to events, not by direct method calls.

---

## Event Definition

```dart
sealed class PlatformEvent {
  final String id;
  final DateTime timestamp;
  final String? source;

  PlatformEvent({
    required this.id,
    required this.timestamp,
    this.source,
  });
}
```

---

## Event Categories

### Domain Events

Business occurrences that other components may care about:

| Event | Publisher | Subscribers |
|-------|-----------|-------------|
| `OrderPlaced` | Commerce Engine | Notifications, Analytics, Mobility |
| `OrderDelivered` | Commerce Engine | Notifications, Analytics |
| `PaymentCompleted` | Payments Engine | Commerce, Analytics |
| `UserSignedUp` | Identity Engine | Notifications, Analytics |
| `MerchantApproved` | Identity Engine | Commerce, Notifications |
| `RideRequested` | Mobility Engine | Notifications, Analytics |
| `RideCompleted` | Mobility Engine | Payments, Analytics |

### System Events

Technical occurrences:

| Event | Publisher | Subscribers |
|-------|-----------|-------------|
| `EngineInitialized` | Kernel | Logging |
| `EngineFailed` | Kernel | Logging, Analytics |
| `PluginActivated` | Kernel | Logging |
| `PluginFailed` | Kernel | Logging, Analytics |

### Command Events

Requests for action:

| Event | Publisher | Subscribers |
|-------|-----------|-------------|
| `SendNotification` | Any | Notifications Engine |
| `ProcessPayment` | Any | Payments Engine |
| `TrackEvent` | Any | Analytics Engine |

---

## Event Bus Interface

```dart
abstract interface class EventBus {
  /// Publish an event
  Future<void> publish(PlatformEvent event);

  /// Subscribe to events of a specific type
  Stream<T> on<T extends PlatformEvent>();

  /// Subscribe to all events
  Stream<PlatformEvent> get onAny;

  /// Get event history
  Future<List<PlatformEvent>> getHistory({int limit});
}
```

---

## Event Flow

```
Restaurant Plugin                    Ride Plugin
       │                                │
       │  1. publish(OrderPlaced)       │
       ▼                                │
  ┌─────────────────────────────────────────┐
  │              EVENT BUS                  │
  │                                         │
  │  2. Route to subscribers                │
  │     → Notifications Engine              │
  │     → Analytics Engine                  │
  │     → Mobility Engine                   │
  │                                         │
  │  3. Deliver events                      │
  └─────────────────────────────────────────┘
       │                    │
       ▼                    ▼
  Notifications         Ride Plugin
  Engine                (dispatches driver)
```

---

## Event Rules

| Rule | Description |
|------|-------------|
| Immutable | Events cannot be modified after creation |
| Idempotent | Publishing the same event twice has no extra effect |
| Ordered | Events processed in publish order |
| Async | All event handling is asynchronous |
| Logged | All events logged by Logging Engine |

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Subscriber throws | Log error, continue to next subscriber |
| Event bus full | Drop oldest events, log warning |
| Subscriber timeout | Skip subscriber, log warning |
| Publisher fails | Event not published, log error |

---

## Current Implementation

The event bus is currently implicit — components call each other directly. The formal EventBus will be implemented as part of the Platform Kernel documentation phase (Constitution §15 step 1).
