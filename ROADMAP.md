# ROADMAP.md — Delwaqty Development Roadmap

> **Last updated:** 2026-07-17
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
| Phase 5: Platform Kernel Docs | 15 architecture docs | ✅ Complete |
| Phase 5.1: Restaurant Domain | Data layer complete | ✅ Complete |

## Current State

| System | Status |
|--------|--------|
| Supabase DB | ✅ Deployed (24 tables, 27 RLS policies, 31 FK relationships) |
| Firebase | ✅ Wired (delwaqty0, FCM, Analytics, Crashlytics) |
| Google Maps | ✅ Wired (5 APIs, Android manifest) |
| Cloudflare R2 | ✅ Wired (bucket: delwaqty-assets) |
| Auth (Supabase GoTrue) | ✅ Real |
| Profile (Supabase) | ✅ Real |
| Merchants | ✅ Real |
| Catalog Categories | ✅ Real |
| Products | ✅ Real |
| Favorites | ✅ Real |
| Cart | ✅ Real (SharedPreferences) |
| Orders | ✅ Real |
| Reviews | ✅ Real (9 methods) |
| Coupons | ✅ Real (9 methods) |
| Branches | ✅ Real (6 methods) |
| Working Hours | ✅ Real (4 methods) |
| Delivery Zones | ✅ Real (6 methods) |
| Product Modifiers | ✅ Real (5 methods) |
| Restaurant Settings | ✅ Real (3 methods) |
| Offers | ✅ Real (10 methods, scheduling + discount calc) |
| Reservations | ✅ Real (8 methods, slot management) |
| Order Tracking | ✅ Real (4 methods) |
| Product Inventory | ✅ Real (9 methods, stock + reservation) |
| **Mocks remaining in codepath** | **0** |

## Next Steps (Constitution v2.0 §15)

### Phase 6: Presentation Layer — Customer
- [ ] Customer Home — nearby restaurants, search, categories
- [ ] Restaurant Details — info, branches, hours, delivery zones
- [ ] Menu Browser — categories, products, modifiers, variants
- [ ] Cart & Checkout — items, coupons, payment, order placement
- [ ] Order Tracking — real-time status, order history
- [ ] Reservations — slot picker, booking, management
- [ ] Reviews & Ratings — submit, view, filter

### Phase 7: Presentation Layer — Merchant
- [ ] Merchant Dashboard — overview, analytics, quick actions
- [ ] Branch Management — CRUD, working hours, delivery zones
- [ ] Product Management — CRUD, modifiers, inventory, pricing
- [ ] Order Management — incoming, in-progress, completed, rejected
- [ ] Offer Management — create, schedule, discount types
- [ ] Reservation Management — upcoming, availability, capacity
- [ ] Reviews Management — respond, moderate

### Phase 8: Presentation Layer — Driver
- [ ] Driver Assignment — accept/decline orders
- [ ] Navigation — Google Maps integration
- [ ] Delivery Confirmation — photo proof, signature
- [ ] Earnings Dashboard — daily/weekly/monthly

### Phase 9: Database Hardening
- [ ] RLS per-role policies (replace USING(true) patterns)
- [ ] Add missing indexes (reviews.rating, orders.created_at, coupons.valid_until)
- [ ] Add RLS to activity_logs, admin_users, drivers, notifications, platform_settings

### Phase 10: Restaurant Plugin Polish
- [ ] Restaurant-specific unit tests
- [ ] Integration tests for full order flow
- [ ] Real-time subscriptions (order tracking, inventory changes)
- [ ] Push notifications for order status

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
| 17 | Restaurant domain data layer (Phase 5.1) | ✅ |
