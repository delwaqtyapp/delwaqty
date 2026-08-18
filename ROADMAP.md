# ROADMAP.md — Delwaqty Development Roadmap

> **Last updated:** 2026-08-18
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
| Profile (Supabase) | ✅ Real (view, edit, avatar, date-of-birth via `update_member_dob` RPC with privacy rule) |
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
| Account Verification | ✅ Code + live DB (migrations 020+021 applied; user_type/verification_status + admin approve/reject); email confirmation enabled + deep-link `site_url`/`uri_allow_list` configured; **Step 11**: role registration unblocked (user_type CHECK widened to merchant/driver), registration language persisted, admin verification queue covers all roles, rejected state UI; on-device E2E pending |
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

> Authoritative per-sub-phase gate docs: `docs/HANDOFF/25…28, 30`. Constitution §15 authority. No
> migration is written ahead of its gate's approval (architecture-first, evidence-first).

| Sub-phase | Scope | Migration | Status |
|-----------|-------|-----------|--------|
| 2.0 | Architecture audit (D1–D4 defined) | — | ✅ (`25_SPRINT_76_PHASE2_ARCHITECTURE_AUDIT.md`) |
| 2.1 | Egypt regions: canonical 27-governorate hierarchy + `user_region_preferences` + Flutter `regions` module | `030_regional_system` | ✅ shipped `1f3ba02`, live-verified (`27_SPRINT_76_PHASE2_REGIONS.md`) |
| 2.1B | Egypt complete geographic coverage: extend admin hierarchy (markaz/aqsam/cities/villages/new cities) + `geo_places`/`geo_aliases`/`geo_admin_boundaries` + server-side GPS/spatial resolution (PostGIS `geo_region_for_point`) | `032_egypt_geographic_schema` + `032_egypt_geographic_seed` | ✅ **SHIPPED** in sprint 76 (`b1081d2`; ADR-057 + amendment A1–A4; `30_..._AUDIT.md` + `31_..._PRE_COMMIT_GATE.md`; 6,157 regions / 64 places / 6,879 aliases / 374 valid boundaries live; RPC EXECUTE anon-revoked; licenses per source; analyzer 0/0 region files; tests 731/731) |
| **2.2** | **Admin hierarchy (D1): owner > admin tiers, `admin_region_assignments`, `is_admin_for_region()`, RLS standardization on `is_admin()` (fix literal-role + raw_user_meta_data drift), shared Dart `isAdminUser` helper, admin_web auth gate** | `031_admin_hierarchy_region_assignments` | ✅ **SHIPPED** in sprint 76 (`b1081d2`; `28_..._ADMIN_HIERARCHY_AUDIT.md` + `29_..._FINAL_PRE_COMMIT_GATE.md`, ADR-055/056) |
| 2.3 | Member Management + Support + Emergency (D3): EXTEND `chat_rooms` (priority incl. `emergency`/region/assignment/escalation) + routing/escalation + guard triggers; admin delegation (supervision tree + permission grants + Approval Center); member mgmt/moderation/deletion; emergency command center + audio foundation; regional offers + approval workflow; birthday/anniversary engines; RLS fixes (activity_logs insert, driver_locations read, sos_alerts admin) | `033_support_chat_priority_region_assignment` + `034_admin_management_permissions_approvals` + `035_member_management_moderation_deletion` + `038_member_rewards_engines_retention` + `044_member_management_list_rpc` + `045_rewards_config_approvals_region` + `046_profile_registration_roles_language` | ✅ **SHIPPED** — migrations 033/034/035/038/044/045/046 applied live + probe-verified; **Step 10**: birthday/anniversary reward engine hardened (free-delivery gate restored, region-aware config, Cairo timezone, config-driven expiry, reward config via approval pipeline) + Flutter reward card period/validity/benefit detail; **Step 11**: profile + registration completion (DOB editing via `update_member_dob` RPC with privacy rule, `user_type` CHECK widened to merchant/driver, registration language persisted end-to-end, admin verification queue widened + rejected state); **Step 12**: rejected-verification **re-apply** (migration `047_verification_reapply.sql` — `reapply_verification` + `decide_user_verification` RPCs, rejection reason stored + shown, direct `verification_status` writes blocked by guard) + **login-callback deep-link classification** (`io.delwaqty://login-callback`, `DeepLinkResolver`/`DeepLinkService`, app_links direct dep); `sprint 80` committed+pushed; `flutter test` 868/868 |
| 2.4 | Notifications delivery layer: server-side FCM send path (`send-push` Edge Function + pg_net trigger + `dispatch_push`), device-scoped token lifecycle RPCs, realtime-first badge, Notification Center pagination/l10n/priority, controlled deep-links (allowlist), support chat/complaint/emergency/campaign/reward notifications | `041_notification_delivery_layer` | ✅ **SHIPPED** — `sprint 78` committed+pushed; migration 041 applied live + probe-verified; Flutter wiring shipped; `flutter test` 805/805 |
| 2.5 | Escalation engine: `escalation_events` + engine RPCs; wire complaints `escalated` status | `048_escalation_engine` | ✅ **SHIPPED** — migration `048_escalation_engine.sql` applied live + probe-verified (strict-upward routing: scoped → global → owner queue; marker-based server-origin guards replacing the unusable `session_user`/`current_user` discriminator under PostgREST); **Step 13**: Flutter `lib/features/escalation/` module (entity/repo/data source/impl/providers/admin queue page), `/admin/escalations` route + module registry registration, complaints `escalated` routed via `escalate_complaint` RPC (direct UPDATE raises), Escalate action with required-reason prompt, l10n en+ar; targeted suites green; `sprint 81` committed+pushed |
| 2.6 | Realtime hardening: centralized `RealtimeService` (channel tracking, cleanup, error callbacks) + `RealtimeChannels` constants (11 canonical names) + `PushNotificationService` migrated to use service | `—` (Dart only) | ✅ **SHIPPED** — `sprint 83` committed+pushed; `dart analyze` 0 errors; 119 tests green |
| 2.7 | Security hardening: `SET search_path = public, pg_temp` on 26 legacy SECURITY DEFINER RPCs (005/010/012/029/021) + `REVOKE ... FROM anon` on 15 platform_* admin-only RPCs + full 016 pattern everywhere | `051_rpc_search_path_and_acl_hardening` | ✅ **SHIPPED** — `sprint 83` committed+pushed; migration 051 applied live; pg_proc verified all 26 RPCs have search_path; anon blocked from all RPCs |
| **Promo** | **Promotion / Content / Campaign platform:** `campaigns`, `campaign_banners`, `campaign_reviews`, `campaign_cta_routes`, `campaign_seen` · targeting `campaign_targets` · generic `approval_requests` · `campaign-media` bucket · feed `get_active_campaigns` (SECURITY DEFINER) · analytics `campaign_events`→`campaign_metrics` · Flutter home carousel/campaign detail | **039 + 040 + 042 applied** | ✅ **SHIPPED** — `sprint 79` committed+pushed; DB-driven campaign carousel + notification gap wiring; `flutter test` 856/856 |

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
| 78 | Notifications delivery layer — `041_notification_delivery_layer` (FCM send path, device token lifecycle RPCs, realtime badge, Notification Center), sprint 78 | ✅ |
| 79 | Promotion/Content/Campaign platform — migrations 039/040/042, DB-driven campaign carousel, sprint 79 | ✅ |
| 80 | Profile + registration completion (Step 11) + verification re-apply & login-callback deep link (Step 12), migration 047, sprint 80 | ✅ |
| 81 | Member Operations Center Completion — Member Drawer (14 intelligence sections), Operations Center (responsive split-layout), Member entity extension (26 fields), repository refactoring, 10 lazy-loading providers, security probes (owner/anon/customer), all tests green, sprint 81 | ✅ |
| 82 | Platform Operations + Financial Intelligence Center — 14 SECURITY DEFINER RPCs, new admin dashboard (12 KPIs, time filter, revenue, alerts), financial center, delivery/merchant/provider/wallet intelligence, transaction ledger, 20 Freezed entities, data source, 15 Riverpod providers, 7 Flutter pages, sprint 82 | ✅ |
| 83 | Realtime + Security Hardening — centralized RealtimeService, channel constants, PushNotificationService migration, migration 051 (search_path on 26 RPCs, REVOKE anon from 15 platform_* RPCs, 016 pattern everywhere), sprint 83 | ✅ |
| 84 | Admin Command Center — grouped admin sidebar (25/25 routes, Arabic groups, collapsible), Command Center dashboard (grouped KPIs Platform/Operations/Financial/Risk, region scope selector, global search), Emergency/SOS page (realtime sos_alerts), `/admin/members/:id` route, member drawer schema normalizer, member-list dynamic-array cast fix, admin notification isAdmin deep-link, Back-navigation verified on device, sprint 84 | ✅ |

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
