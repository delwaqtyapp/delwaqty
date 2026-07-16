# PLUGIN_LIFECYCLE.md — Plugin Lifecycle Management

> **Authority:** PROJECT_CONSTITUTION.md §21
> **Version:** 2.0

---

## Lifecycle Phases

```
┌─────────┐    ┌──────────────┐    ┌──────────┐    ┌─────────┐    ┌────────────┐    ┌─────────┐
│ Register │───>│  Initialize  │───>│ Activate │───>│ Running │───>│ Deactivate │───>│ Dispose │
└─────────┘    └──────────────┘    └──────────┘    └─────────┘    └────────────┘    └─────────┘
```

---

## Phase Details

### Register

| Aspect | Detail |
|--------|--------|
| **When** | App startup |
| **What** | Plugin added to Platform Kernel's registry |
| **Can access** | Nothing (pre-initialization) |
| **Can do** | Declare metadata (id, name, required engines) |

### Initialize

| Aspect | Detail |
|--------|--------|
| **When** | After registration, before activation |
| **What** | Plugin sets up services, providers, routes |
| **Can access** | Platform Kernel (for engine discovery) |
| **Can do** | Register providers, set up event subscriptions |

### Activate

| Aspect | Detail |
|--------|--------|
| **When** | After initialization |
| **What** | Plugin becomes available to users |
| **Can access** | All Platform Engines |
| **Can do** | Handle user requests, publish/subscribe events |

### Running

| Aspect | Detail |
|--------|--------|
| **When** | Normal operation |
| **What** | Plugin handles requests |
| **Can access** | All Platform Engines |
| **Can do** | Full plugin functionality |

### Deactivate

| Aspect | Detail |
|--------|--------|
| **When** | Maintenance, update, or error |
| **What** | Plugin becomes unavailable |
| **Can access** | Read-only operations only |
| **Can do** | Serve cached data, queue operations |

### Dispose

| Aspect | Detail |
|--------|--------|
| **When** | App shutdown or plugin removal |
| **What** | Plugin cleans up resources |
| **Can access** | Nothing (post-operation) |
| **Can do** | Release connections, cancel subscriptions |

---

## Error Handling

| Phase | Error Behavior |
|-------|---------------|
| Register | Log warning, continue without plugin |
| Initialize | Retry 3 times, then skip plugin |
| Activate | Log error, mark plugin as degraded |
| Running | Catch errors, report to Logging Engine |
| Deactivate | Force deactivation after timeout |
| Dispose | Log errors, force cleanup |

---

## Plugin State Machine

```dart
enum PluginState {
  registered,    // Just registered
  initializing,  // Setting up
  active,        // Ready to serve
  running,       // Handling requests
  deactivating,  // Shutting down
  disposed,      // Cleaned up
  failed,        // Error state
  degraded,      // Partially functional
}
```

---

## Hot Reload Support

During development, Plugins support hot reload:

1. Deactivate current instance
2. Dispose current instance
3. Re-register with new code
4. Re-initialize
5. Re-activate

Production does not use hot reload.
