# OBSERVABILITY.md — Observability Architecture

> **Authority:** PROJECT_CONSTITUTION.md §13
> **Version:** 2.0

---

## Observability Pillars

```
┌─────────────────────────────────────────┐
│            OBSERVABILITY                 │
├─────────────┬─────────────┬─────────────┤
│   Logging   │  Analytics  │   Tracing   │
│             │             │             │
│ App logs    │ Events      │ Request     │
│ Audit logs  │ Metrics     │ flow        │
│ Error logs  │ Funnels     │ Performance │
│ Security    │ Dashboards  │ Errors      │
└─────────────┴─────────────┴─────────────┘
```

---

## Logging

### Log Levels

| Level | Usage | Example |
|-------|-------|---------|
| DEBUG | Development debugging | Variable values, flow traces |
| INFO | Normal operations | User signed in, order placed |
| WARN | Recoverable issues | Rate limit approaching, cache miss |
| ERROR | Failures requiring attention | API error, DB connection failed |
| CRITICAL | System-threatening | Data corruption, security breach |

### Log Destinations

| Destination | Level | Purpose |
|-------------|-------|---------|
| Console | All | Development |
| Firebase Crashlytics | ERROR, CRITICAL | Production crash reporting |
| Supabase | All | Persistent storage |
| Custom endpoint | AUDIT, SECURITY | Compliance |

### Audit Logging

| Event | Data Logged |
|-------|-------------|
| User action | userId, action, resource, timestamp |
| Admin action | adminId, action, target, before/after |
| Data change | table, row, column, old_value, new_value |
| Auth event | userId, event, ip, device |

---

## Analytics

### Event Tracking

| Event Category | Examples |
|----------------|----------|
| User | signup, login, logout, profile_update |
| Commerce | merchant_view, product_view, add_to_cart |
| Order | order_placed, order_delivered, order_cancelled |
| Payment | payment_success, payment_failed, refund |
| Engagement | search, favorite, share, review |

### Metrics

| Metric | Type | Description |
|--------|------|-------------|
| Daily Active Users | Gauge | Users active per day |
| Orders per Hour | Counter | Order volume |
| Revenue per Day | Counter | Total revenue |
| Average Order Value | Gauge | Revenue / orders |
| Delivery Time | Histogram | Time from order to delivery |
| Error Rate | Gauge | Errors / total requests |

### Dashboards

| Dashboard | Audience |
|-----------|----------|
| Business Overview | Management |
| Technical Health | Engineering |
| User Growth | Marketing |
| Revenue | Finance |

---

## Tracing

### Request Tracing

Every user action generates a trace:

```
User taps "Place Order"
  → Commerce Engine: validateCart()
  → Payments Engine: charge()
  → Notifications Engine: push()
  → Analytics Engine: track()
```

### Performance Tracing

| Operation | Target | Alert |
|-----------|--------|-------|
| Screen load | < 300ms | > 500ms |
| API call | < 500ms | > 1000ms |
| DB query | < 100ms | > 200ms |
| Image load | < 1000ms | > 2000ms |

---

## Error Tracking

### Error Categories

| Category | Handling |
|----------|----------|
| Network error | Retry with backoff |
| Auth error | Redirect to login |
| Validation error | Show user message |
| Server error | Log, show generic message |
| Unknown error | Log full context, show generic |

### Error Reporting

```dart
class ErrorHandler {
  static Future<void> handle(Object error, StackTrace stack) async {
    // 1. Log to Logging Engine
    await loggingEngine.log(LogLevel.error, error.toString());

    // 2. Report to Crashlytics
    await crashlytics.recordError(error, stack);

    // 3. Track in Analytics
    await analyticsEngine.track('error', properties: {
      'type': error.runtimeType.toString(),
      'message': error.toString(),
    });
  }
}
```

---

## Health Monitoring

| Check | Frequency | Alert |
|-------|-----------|-------|
| API availability | Every 5 minutes | Down > 2 minutes |
| Database connectivity | Every 1 minute | Down > 1 minute |
| Storage availability | Every 5 minutes | Down > 5 minutes |
| Auth service | Every 1 minute | Down > 1 minute |

---

## Current Observability Status

| Pillar | Status |
|--------|--------|
| Logging | ✅ AppLogger implemented |
| Crash Reporting | ✅ Firebase Crashlytics active |
| Analytics | ✅ Firebase Analytics active |
| Performance | ✅ Firebase Performance active |
| Audit Logging | ⚠️ Partial |
| Tracing | ❌ Not started |
| Dashboards | ❌ Not started |
| Health Monitoring | ❌ Not started |
