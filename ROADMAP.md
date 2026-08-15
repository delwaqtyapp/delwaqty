# ROADMAP.md — Delwaqty Development Roadmap

> **Last updated:** 2026-08-15
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
| Sprint 20: Production Polish | Premium widgets, core screens, L10n | ✅ Complete |
| Sprint 21: Real Functionality | Notifications, bugs, RLS, performance | ✅ Complete |
| Sprint 22-24: Restaurant Presentation | Restaurant module, favorites, dead code cleanup | ✅ Complete |
| Sprint 25: Restaurant UX Polish | Glass Cards, Lottie, skeletons, Hero, Gallery, deletion policy | ✅ Complete |

## Current State

| System | Status |
|--------|--------|
| Supabase DB | ✅ Deployed (24 tables, 27 RLS policies, 31 FK relationships) |
| Supabase RLS | ✅ Migration 005 applied (role-based policies on all 23 tables) |
| Supabase Trigger | ✅ Migration 006 applied (auto-create profile on signup) |
| Firebase | ✅ Wired (delwaqty0, FCM, Analytics, Crashlytics) |
| Google Maps | ✅ Wired (5 APIs, Android manifest) |
| Cloudflare R2 | ✅ Wired (bucket: delwaqty-assets) |
| Auth (Supabase GoTrue) | ✅ Real (login, register, logout, reset password, session, guest) |
| Profile (Supabase) | ✅ Real (view, edit, avatar) |
| Merchants | ✅ Real (CRUD, search, filters) |
| Catalog Categories | ✅ Real |
| Products | ✅ Real (CRUD, variants, search) |
| Favorites | ✅ Real (toggle, list, filter) |
| Cart | ✅ Local (SharedPreferences, cross-device sync deferred) |
| Orders | ✅ Real (create, track, history) |
| Reviews | ✅ Real (submit, list, average) |
| Coupons | ✅ Real (validate, apply, types) |
| Notifications | ✅ Real (Supabase: get, mark read, delete, unread count) |
| Branches | ✅ Real (6 methods) |
| Working Hours | ✅ Real (4 methods) |
| Delivery Zones | ✅ Real (6 methods) |
| Product Modifiers | ✅ Real (5 methods) |
| Restaurant Settings | ✅ Real (3 methods) |
| Offers | ✅ Real (10 methods, scheduling + discount calc) |
| Reservations | ✅ Real (8 methods, slot management) |
| Order Tracking | ✅ Real (4 methods) |
| Product Inventory | ✅ Real (9 methods, stock + reservation) |
| Account Verification | ✅ Code + live DB (migrations 020+021 applied; user_type/verification_status + admin approve/reject); email confirmation enabled + deep-link `site_url`/`uri_allow_list` configured; on-device E2E pending |
| Login UX (fingerprint + saved accounts) | ✅ Fingerprint login fixed (biometric permissions, Keystore-backed password via flutter_secure_storage v11), saved-accounts section with quick re-login, social login removed, save-account checkbox wired end-to-end |
| **Mocks remaining in codepath** | **0** |

## Next Steps (Constitution v2.0 §15)

### Phase 8: Transportation Platform (Ride-Hailing Ecosystem)
- [x] M1: Full Arabic-default localization + EGP currency (sprint 28)
- [x] M2: Transportation Supabase schema + pricing/dispatch/lifecycle RPCs (sprint 29)
- [x] M3: Passenger booking flow on real backend (6 categories, fare/promo, Maps, Realtime tracking, no mock) (sprint 30)
- [x] M4: Dispatch engine + live trip lifecycle (driver offers, accept/arrive/OTP/start/complete/cancel, earnings + withdrawals, driver ride app, Realtime, no mock) (sprint 31)
- [x] M5: Destination search & geocoding (provider-agnostic abstraction, Google Places provider, autocomplete/details/reverse/nearby, saved + recent, session tokens, debounce, caching, AR/EN) (sprint 32)
- [x] M6: Complete driver platform (onboarding wizard, vehicle management, document management, enhanced dashboard, wallet breakdown, performance metrics, 9 new RPCs, realtime-ready) (sprint 33)
- [x] M7: Delivery & Courier Platform (food, grocery, pharmacy, package — built on dispatch engine) (sprint 34)
- [x] M8: Safety (SOS, trusted contacts, live share, OTP pickup) (sprints 35-36)
- [x] M9: Admin monitoring dashboard → **expanded to Management Platform** (complaints, sanctions, live tracking, support chat) (sprint 40)
- [ ] M10: Payments integration

### Phase 6: Presentation Layer — Customer
- [x] Customer Home — nearby restaurants, search, categories (Premium Super App design)
- [x] Restaurant/Merchant Details — info, menu, Hero animations, ratings
- [x] Product Details — variants, quantity, add-to-cart
- [x] Search — debounced search, filters, sort by distance/rating/price
- [x] Cart — swipe-to-delete, quantity controls, summary
- [x] Checkout — address, payment method, coupon, order summary
- [x] Order Tracking — real-time timeline, driver info
- [x] Order Completed — celebration page with animations
- [x] Orders History — pull-to-refresh, status chips
- [x] Empty States — consistent EmptyState widget across all screens
- [x] Error States — consistent ErrorState widget across all screens
- [x] Loading States — skeleton loading, circular indicators
- [x] Localization — 197+ ARB strings (English + Arabic)
- [x] Reservations — slot picker, booking, management
- [x] Reviews & Ratings — submit, view, filter

### Phase 7: Presentation Layer — Merchant
- [x] Merchant Dashboard — overview, analytics, quick actions
- [x] Branch Management — CRUD, working hours, delivery zones
- [x] Product Management — CRUD, modifiers, inventory, pricing
- [x] Order Management — incoming, in-progress, completed, rejected
- [x] Offer Management — create, schedule, discount types
- [x] Reservation Management — upcoming, availability, capacity
- [x] Reviews Management — respond, moderate

### Phase 8: Presentation Layer — Driver
- [ ] Driver Assignment — accept/decline orders
- [ ] Navigation — Google Maps integration
- [ ] Delivery Confirmation — photo proof, signature
- [ ] Earnings Dashboard — daily/weekly/monthly

### Phase 9: Database Hardening
- [x] RLS per-role policies (replace USING(true) patterns — migration 005 created)
- [x] Add missing indexes (reviews.rating, orders.created_at, coupons.valid_until)
- [ ] Add RLS to activity_logs, admin_users, drivers, notifications, platform_settings

### Phase 10: Restaurant Plugin Polish
- [ ] Restaurant-specific unit tests
- [ ] Integration tests for full order flow
- [ ] Real-time subscriptions (order tracking, inventory changes)
- [ ] Push notifications for order status

### Phase 11: Super App MVP — Multi-Category Services Platform
- [x] Sprint 62: Home Grid + New Categories
- [x] Sprint 63: Home Services Booking Module
- [x] Sprint 64: Enhanced Search + Filters
- [x] Sprint 65: Admin Dashboard (Flutter Web)
- [x] Sprint 66: Multi-Role Registration + Offline Caching
- [x] Sprint 67: Merchant Operations & Payments Integration

---

## Phase 2 — Admin Hierarchy, Regions, Escalation (sprint 76+, planned)

> Authoritative per-sub-phase gate docs: `docs/HANDOFF/25…28`. Constitution §15 authority. No
> migration is written ahead of its gate's approval (architecture-first, evidence-first).

| Sub-phase | Scope | Migration | Status |
|-----------|-------|-----------|--------|
| 2.0 | Architecture audit (D1–D4 defined) | — | ✅ (`25_SPRINT_76_PHASE2_ARCHITECTURE_AUDIT.md`) |
| 2.1 | Egypt regions: canonical 27-governorate hierarchy + `user_region_preferences` + Flutter `regions` module | `030_regional_system` | ✅ shipped `1f3ba02`, live-verified (`27_SPRINT_76_PHASE2_REGIONS.md`) |
| **2.2** | **Admin hierarchy (D1): owner > admin tiers, `admin_region_assignments`, `is_admin_for_region()`, RLS standardization on `is_admin()` (fix literal-role + raw_user_meta_data drift), shared Dart `isAdminUser` helper, admin_web auth gate** | `031_admin_hierarchy_region_assignments` | ✅ **IMPLEMENTED + LIVE-VERIFIED, awaiting commit** (`28_..._ADMIN_HIERARCHY_AUDIT.md` + `29_..._FINAL_PRE_COMMIT_GATE.md`, ADR-055/056) |
| 2.3 | Chat backend (D3): EXTEND `chat_rooms` (priority/region/assignment/escalation cols), `assign_support_chat`/`escalate_support_chat` RPCs, region routing parent-walk, realtime | `032_support_conversations_priority` | 🏗 contract specified (doc 28 §5) |
| 2.4 | Notifications: admin send path + conversation deep-links | `034_notification_chat_deeplinks` | 🏗 pending |
| 2.5 | Escalation engine: `escalation_events` + engine RPCs; wire complaints `escalated` status | `033_escalation_engine` | 🏗 pending |
| 2.6 | Realtime hardening | — | 🏗 pending |
| 2.7 | Security hardening (029 RPC search_path audit, 016 pattern everywhere) | — | 🏗 pending |

**D-resolutions:** D1 → ADR-049 (+ADR-055/056) · D2 → ADR-050 (migration 030) · D3 → 2.3 (extend
`chat_rooms`, decided in doc 28 §5) · D4 → 2.5 (escalation engine + priority server-side only).

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
| 18 | Security audit, finance cleanup, localization (Phase 5.5) | ✅ |
| 19 | Customer Presentation Layer — all screens (Phase 6) | ✅ |
| 20 | Production Polish — RLS, premium UX, animations, security hardening | ✅ |
| 21 | Real Functionality — Notifications, bugs, RLS, performance | ✅ |
| 22 | Admin rewrite, L10n, dead code cleanup, commerce polish | ✅ |
| 23 | Restaurant module full presentation layer (5 pages, 5 widgets) | ✅ |
| 24 | Favorites, dead code cleanup, modifier integration, restaurant order tracking | ✅ |
| 25 | Restaurant UX polish — Glass Cards, Lottie, skeletons, Hero, Gallery, L10n, deletion policy | ✅ |
| 34 | Unified Delivery & Logistics Platform — 9 service types, dispatch engine reuse, merchant/driver/customer flow, delivery pricing | ✅ |
| 40 | Management Platform — Complaints, Sanctions, Live Tracking, Support Chat | ✅ |
| 51+ | Admin Panel Wiring — dashboard + sidebar entries; legacy rides page removed | ✅ |
| 53-54 | Management Tables DB Fix + RLS Rebuild — migrations 015/016 applied to Supabase | ✅ |
| 55 | UI Polish — Cairo typography, card system, pill search, banner copy, micro-interactions | ✅ |
| 56 | Functional Bottom-Nav Restructure — 4-tab layout (Home/Search/Orders/Profile), Settings via Profile gear, Delivery/Ride in Home grid | ✅ |
| 60 | Account Verification — user type (customer/provider/delivery) + verification status, document upload, pending-verification gate, admin approve/reject page, migration 020 | ✅ |
| 61 | Fingerprint Unification — DB-backed BiometricAuthStore, local_auth 3.0.0 for Android 16, Splash biometric gate | ✅ |

---

## Phase 11: Super App MVP — Multi-Category Services Platform

### Sprint 62: Home Grid + New Categories
- [x] Expand `MerchantType` enum (16 new types: supermarket, fruits, meat, seafood, sweets, clothing, shoes, mobile, appliances, cafe, petShop, fitness, gas, carwash)
- [x] Expand home page grid from 7 to 20+ tiles (scrollable 4-column)
- [x] Add new service category colors + icons + l10n (EN + AR)
- [x] Database migration 023: `ALTER TABLE merchants ADD COLUMN category_tags TEXT[]`

### Sprint 63: Home Services Booking Module
- [x] New `home_services` feature module (data/domain/presentation)
- [x] Service categories: Plumbing, Electrical, Carpentry, AC Maintenance, Painting
- [x] Booking flow: select service → pick date/time → confirm
- [x] Service provider listing with ratings/availability
- [x] DB schema: `service_bookings`, `service_providers`, `service_categories` tables

### Sprint 64: Enhanced Search + Filters
- [x] Auto-complete search with recent + suggested results
- [x] Filter chips: Price range, Distance, Rating, Open Now
- [x] Sort: Relevance, Distance, Rating, Price (low/high)
- [ ] Category quick-filter on search results

### Sprint 65: Admin Dashboard (Flutter Web)
- [x] Flutter Web admin shell with sidebar navigation
- [x] Dashboard overview: revenue, orders, users, merchants KPIs
- [x] User management: list, search, activate/deactivate
- [ ] Category/Service management: add/edit/remove categories

### Sprint 66: Multi-Role Registration + Offline
- [x] Dynamic registration fields per role (Customer/Merchant/Driver/Provider)
- [x] Document upload for merchant/provider verification
- [x] Offline caching with Hive for categories/products
- [ ] Push notification admin tool
