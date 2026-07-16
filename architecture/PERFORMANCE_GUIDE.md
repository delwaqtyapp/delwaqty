# PERFORMANCE_GUIDE.md — Performance Standards

> **Authority:** PROJECT_CONSTITUTION.md §4
> **Version:** 2.0

---

## Performance Targets

| Metric | Target | Current |
|--------|--------|---------|
| App launch (cold) | < 2 seconds | ~3 seconds |
| App launch (warm) | < 1 second | ~1 second |
| Screen transition | < 300ms | ~200ms |
| API response | < 500ms | Varies |
| Image load | < 1 second | Varies |
| Search results | < 500ms | In-memory |
| Order placement | < 2 seconds | ~1 second |

---

## Performance Layers

```
┌──────────────────────────────┐
│     Presentation Layer       │  Widget optimization
├──────────────────────────────┤
│     Domain Layer             │  Business logic efficiency
├──────────────────────────────┤
│     Data Layer               │  Caching, pagination
├──────────────────────────────┤
│     Network Layer            │  Connection pooling, compression
├──────────────────────────────┤
│     Storage Layer            │  Local caching, SharedPreferences
└──────────────────────────────┘
```

---

## Optimization Strategies

### Presentation

| Strategy | Description |
|----------|-------------|
| Const widgets | Use `const` constructors everywhere |
| Repaint boundaries | Isolate complex widgets |
| Lazy loading | Load images/content on demand |
| List optimization | Use `ListView.builder` for long lists |
| Animation | Use 60fps animations, avoid jank |

### Data

| Strategy | Description |
|----------|-------------|
| Pagination | Never load all records at once |
| Caching | Cache frequently accessed data |
| Batch operations | Combine multiple DB operations |
| Selective fields | Query only needed columns |
| Connection pooling | Reuse Supabase connections |

### Network

| Strategy | Description |
|----------|-------------|
| Compression | Enable gzip for API responses |
| Image optimization | Serve WebP, resize on server |
| CDN | Use Cloudflare for static assets |
| Retry with backoff | Handle transient failures gracefully |
| Timeout | Set appropriate timeouts |

---

## Monitoring

| Tool | Purpose |
|------|---------|
| Firebase Performance | Screen load times, network latency |
| Firebase Crashlytics | Crash detection |
| Custom metrics | Business-specific KPIs |

---

## Anti-Patterns

| Anti-Pattern | Impact | Fix |
|--------------|--------|-----|
| Loading all data at once | Memory, startup time | Paginate |
| No caching | Redundant network calls | Cache with TTL |
| Blocking main thread | UI jank | Use isolates |
| Unoptimized images | Memory, bandwidth | Resize, compress |
| No lazy loading | Slow screens | Load on demand |

---

## Current Performance Status

| Area | Status |
|------|--------|
| Widget optimization | ✅ Good |
| Pagination | ✅ Implemented |
| Caching | ⚠️ Partial (SharedPreferences only) |
| Image optimization | ❌ Not started |
| CDN | ✅ Cloudflare R2 |
| Performance monitoring | ✅ Firebase Performance |
