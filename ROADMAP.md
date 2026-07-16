# ROADMAP.md — Delwaqty Development Roadmap

> **Last updated:** 2026-07-16
> **Authority:** PROJECT_CONSTITUTION.md §15

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

## Next Steps (per Constitution §15)

### 1. Finalize Commerce Domain Model
- [ ] Wire Reviews to Supabase (reviews table exists)
- [ ] Wire Coupons to Supabase (coupons table exists)
- [ ] Delete remaining mock files
- [ ] Verify end-to-end commerce flow

### 2. Merchant Platform
- [ ] Merchant registration flow
- [ ] Merchant dashboard
- [ ] Product CRUD for merchants
- [ ] Order management for merchants

### 3. Restaurant Module
- [ ] Restaurant-specific features (menu, table booking)
- [ ] Restaurant admin portal

### 4. Customer Ordering Flow
- [ ] Full checkout with payment
- [ ] Order tracking with real-time status
- [ ] Delivery address management

### 5. Driver Platform
- [ ] Driver registration and onboarding
- [ ] Order assignment and dispatch
- [ ] Real-time location tracking
- [ ] Delivery completion flow

### 6. Admin Platform
- [ ] Admin dashboard with live data
- [ ] User management
- [ ] Merchant management
- [ ] Order oversight

### 7. Marketplace
- [ ] Buy & Sell listings
- [ ] Category management
- [ ] Search and filtering

### 8. Ride Hailing
- [ ] Ride request flow
- [ ] Driver matching
- [ ] Real-time tracking
- [ ] Fare calculation

### 9. Home Services
- [ ] Service booking
- [ ] Provider matching
- [ ] Scheduling

### 10. Wallet & Payments
- [ ] Digital wallet
- [ ] Payment gateway integration (Stripe/Moyasar)
- [ ] QR payments
- [ ] Bill payments

### 11. Subscriptions
- [ ] Subscription plans
- [ ] Recurring billing

### 12. AI Assistant
- [ ] Provider-agnostic AI engine
- [ ] Natural language ordering
- [ ] Recommendations

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
