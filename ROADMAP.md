# ROADMAP.md — Delwaqty Development Roadmap

> **Last updated:** 2026-07-16
> **Authority:** PROJECT_CONSTITUTION.md §15 (v2.0)

---

## Completed

| Phase | Sprints | Status |
|-------|---------|--------|
| Foundation | 1-2 | ✅ Complete |
| Core UI | 3-4 | ✅ Complete |
| Feature Modules | 5-6 | ✅ Complete |
| Architecture | 7-9 | ✅ Complete |
| Infrastructure | 10-11 | ✅ Complete |
| Infrastructure Integration | 12 Steps | ✅ Complete |
| Phase 3: External Services | — | ✅ Complete |
| Phase 4: Mock → Real Migration | 4.1-4.5 | ✅ Complete |

## Current State

| System | Status |
|--------|--------|
| Supabase DB | ✅ Deployed (14 tables, 29 RLS policies, 16 indexes) |
| Firebase | ✅ Wired (delwaqty0, FCM, Analytics, Crashlytics) |
| Google Maps | ✅ Wired (5 APIs, Android manifest) |
| Cloudflare R2 | ✅ Wired (bucket: delwaqty-assets) |
| Auth (Supabase GoTrue) | ✅ Real (email, phone, Google, Apple, anonymous) |
| Profile (Supabase) | ✅ Real (Realtime watchProfile, deleteProfile) |
| Merchants | ✅ Real (Supabase merchants table) |
| Catalog Categories | ✅ Real (Supabase catalog_categories table) |
| Products | ✅ Real (Supabase products table) |
| Favorites | ✅ Real (Supabase favorites table, polymorphic) |
| Cart | ✅ Real (SharedPreferences, ephemeral by design) |
| Orders | ✅ Real (Supabase orders + order_items tables) |
| Reviews | ⏳ Mock (Supabase reviews table exists, not wired) |
| Coupons | ⏳ Mock (Supabase coupons table exists, not wired) |

## Next Steps (Constitution v2.0 §15)

### Phase 5: Platform Kernel Documentation
- [x] Platform Kernel Architecture (`architecture/KERNEL.md`)
- [x] Platform Engine Catalog (`architecture/ENGINES.md`)
- [x] Plugin System (`architecture/PLUGIN_SYSTEM.md`)
- [x] Engine Interfaces (`architecture/ENGINE_INTERFACES.md`)
- [x] Domain Guide (`architecture/DOMAIN_GUIDE.md`)
- [x] Plugin Lifecycle (`architecture/PLUGIN_LIFECYCLE.md`)
- [x] Dependency Rules (`architecture/DEPENDENCY_RULES.md`)
- [x] Platform Services (`architecture/PLATFORM_SERVICES.md`)
- [x] Event Architecture (`architecture/EVENT_ARCHITECTURE.md`)
- [x] API Contracts (`architecture/API_CONTRACTS.md`)
- [x] Security Model (`architecture/SECURITY_MODEL.md`)
- [x] Performance Guide (`architecture/PERFORMANCE_GUIDE.md`)
- [x] Scalability Guide (`architecture/SCALABILITY_GUIDE.md`)
- [x] Observability (`architecture/OBSERVABILITY.md`)

### Phase 6: Commerce Core (Next after Kernel)
- [ ] Wire Reviews to Supabase
- [ ] Wire Coupons to Supabase
- [ ] Delete remaining mock files
- [ ] Branch Management domain design
- [ ] Catalog Management domain design
- [ ] Inventory domain design
- [ ] Pricing Engine domain design

### Phase 7: Merchant Platform
- [ ] Merchant registration flow
- [ ] Merchant dashboard
- [ ] Product CRUD for merchants
- [ ] Order management for merchants

### Phase 8: Restaurant Plugin
- [ ] Restaurant domain design
- [ ] Menu management
- [ ] Table booking
- [ ] Restaurant admin portal
- [ ] Customer ordering flow

---

## Sprint History

| Sprint | Focus | Status |
|--------|-------|--------|
| 1-2 | Foundation (project setup, routing, theme) | ✅ |
| 3-4 | Core UI (shared widgets, design system) | ✅ |
| 5-6 | Feature modules (auth, commerce, expenses) | ✅ |
| 7-9 | Architecture (plugin system, DI, testing) | ✅ |
| 10-11 | Infrastructure (CI/CD, environment config) | ✅ |
| 12 | External services (Supabase, Firebase, Maps, R2) | ✅ |
| 13 | Mock → Real migration (Auth, Profile, User) | ✅ |
| 14 | Mock → Real migration (Merchant, Categories) | ✅ |
| 15 | Mock → Real migration (Products, Favorites) | ✅ |
| 16 | Mock → Real migration (Cart, Orders) | ✅ |
