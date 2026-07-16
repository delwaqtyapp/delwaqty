# SCALABILITY_GUIDE.md — Scalability Architecture

> **Authority:** PROJECT_CONSTITUTION.md §18
> **Version:** 2.0

---

## Scalability Dimensions

| Dimension | Strategy |
|-----------|----------|
| **Users** | Horizontal scaling via Supabase |
| **Data** | Pagination, archiving, partitioning |
| **Features** | Plugin system, modular architecture |
| **Geography** | Multi-region via Cloudflare |
| **Traffic** | CDN, caching, connection pooling |
| **Complexity** | Engine abstraction, event-driven design |

---

## Architecture for Scale

```
┌─────────────────────────────────────────┐
│              CDN (Cloudflare)            │
│         Static assets, edge caching     │
├─────────────────────────────────────────┤
│           Load Balancer                  │
│      Automatic via Supabase/Cloud       │
├─────────────────────────────────────────┤
│         Application Layer               │
│    Stateless, horizontally scalable     │
├─────────────────────────────────────────┤
│         Database Layer                  │
│    Supabase (PostgreSQL, auto-scaling)  │
├─────────────────────────────────────────┤
│         Storage Layer                   │
│    Cloudflare R2 (S3-compatible)        │
└─────────────────────────────────────────┘
```

---

## Scaling Strategies

### Database Scaling

| Strategy | When |
|----------|------|
| Indexing | Always (16 indexes currently) |
| Pagination | Always (20 records per page) |
| Connection pooling | Built into Supabase |
| Read replicas | When read load exceeds single DB |
| Partitioning | When tables exceed 10M rows |
| Archiving | When historical data exceeds 1 year |

### Application Scaling

| Strategy | When |
|----------|------|
| Stateless services | Always |
| Horizontal scaling | Supabase handles automatically |
| Caching layer | When response time degrades |
| Background jobs | For long-running operations |
| Event-driven | For cross-service communication |

### Storage Scaling

| Strategy | When |
|----------|------|
| CDN caching | Always (Cloudflare) |
| Image resizing | On-demand via Cloudflare Images |
| Lazy loading | Always |
| Compression | Always |

---

## Plugin Scalability

The Plugin system enables independent scaling:

| Plugin | Independent Scaling |
|--------|-------------------|
| Restaurant | Separate catalog, orders |
| Marketplace | Separate listings, search |
| Ride | Separate drivers, trips |
| Home Services | Separate providers, bookings |

Each Plugin can scale independently without affecting others.

---

## Performance Budgets

| Resource | Budget |
|----------|--------|
| App size | < 50MB APK |
| Memory usage | < 200MB typical |
| Network requests | < 10 per screen |
| Database queries | < 5 per request |
| Image cache | < 100MB |

---

## Monitoring Scale

| Metric | Alert Threshold |
|--------|-----------------|
| API response time | > 2 seconds |
| Error rate | > 1% |
| Database connections | > 80% capacity |
| Storage usage | > 80% capacity |
| Memory usage | > 80% capacity |
