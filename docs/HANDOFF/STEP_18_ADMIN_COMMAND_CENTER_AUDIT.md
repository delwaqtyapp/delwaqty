# STEP 18 — ADMIN COMMAND CENTER AUDIT

**Date:** 2026-08-18
**Sprint:** 84
**Status:** Audit complete — implementation follows

---

## 1. Purpose

Full audit of the existing admin platform before rebuilding the Admin Command Center.
Inventory every feature, classify its connection state, and locate broken integrations.

Legend:
- 🟢 Complete + Connected
- 🟡 Partial
- 🟠 Implemented but not connected
- 🔴 Missing
- ⚪ Not applicable

---

## 2. Architecture Snapshot

| Layer | Source of truth | Notes |
|-------|----------------|-------|
| Router | GoRouter + `FeatureRegistry` (`lib/core/router/app_router.dart`) | Single global `/admin` redirect guard (`user.isAdmin`) |
| Auth gate | `lib/core/auth/admin_access.dart` | Binary `isAdmin` = role `admin`\|`owner` (mirrors server `is_admin()`) |
| Mobile admin | `lib/features/admin/` | 25 `/admin/*` routes, registered by `AdminModule` |
| Web admin | `lib/features/admin_web/` standalone (`main_web.dart`) | Separate auth, separate UI, NOT in module registry |
| Permission engine | Server-side `has_permission()` (migration 034) + `admin_region_assignments` (031) | Owner bypass → scope check → supervisor check → grant override |
| Realtime | `lib/services/realtime/realtime_service.dart` + `RealtimeChannels` constants | Centralized (STEP 17) |
| Financial | `platform_*` RPCs (migration 050) + `PlatformIntelligenceDataSource` | 14 RPCs, dual-unwrapping |
| Members | `member_ops_*` RPCs (migration 049) + `get_member_*` (035/044) | Ops Center has 14 sections |

---

## 3. Feature Inventory Matrix

### 3.1 Navigation & Shell

| Feature | Backend | RPC | Datasource | Repository | Provider | Page | Route | Sidebar | Permission | Region | Status |
|---------|---------|-----|-----------|-----------|----------|------|-------|---------|-----------|--------|--------|
| Admin Command Center (landing) | `platform_kpi_summary` etc. | ✅ 050 | `PlatformIntelligenceDataSource` | — | `platformKpiProvider` | `PlatformIntelligenceDashboard` | `/admin` | ✅ | `isAdmin` | filter only | 🟢 |
| Legacy dashboard | `count_table_rows`, `get_admin_analytics` | ✅ | `AdminRepository` | `AdminRepository` | `dashboardMetricsProvider` | `AdminDashboardPage` | `/admin/legacy` | — | `isAdmin` | none | 🟢 |
| Admin navigation (sidebar) | — | — | — | — | — | floating sidebar | — | 🟠 6/25 routes | `isAdmin` | — | 🟠 |
| **Android Back behavior** | — | — | — | — | — | — | — | — | — | — | 🔴 |

### 3.2 Members

| Feature | Backend | RPC | Datasource | Repository | Provider | Page | Route | Sidebar | Permission | Region | Status |
|---------|---------|-----|-----------|-----------|----------|------|-------|---------|-----------|--------|--------|
| Member list/search | `member_ops_list` | ✅ 049 | `SupabaseMemberDataSource` | `SupabaseMemberRepositoryImpl` | `memberOpsProvider` | `MemberOperationsCenter` | `/admin/members` | ✅ (label 'Members' EN hardcoded) | `MEMBER_VIEW` | ✅ scoped | 🟢 |
| Member detail | `get_member_ops_profile` | ✅ 049 | ✅ | ✅ | `memberOpsProfileProvider` | `MemberDrawer` (in Ops Center) | — (drawer) | — | `MEMBER_VIEW` + per-section | ✅ | 🟢 |
| Member profile sections | `get_member_ops_profile` | ✅ | ✅ | ✅ | 14 providers | drawer 14 sections | — | — | per-capability | ✅ | 🟡 drawer schema mismatch |
| Pending verification | `list_members` filter / `decide_user_verification` | ✅ | ✅ | ✅ | `memberOpsProvider` | `MemberOperationsCenter` filter | `/admin/members` | — | `MEMBER_VIEW` | ✅ | 🟢 |
| Member sanctions | `get_member_ops_profile.sanctions` | ✅ | ✅ | ✅ | `memberSanctionsProvider` | drawer | — | — | `MEMBER_VIEW` | ✅ | 🟢 |
| Member orders/rides | `get_member_ops_profile.orders/rides` | ✅ | ✅ | ✅ | `memberOrdersProvider` | drawer | — | — | `MEMBER_VIEW` | ✅ | 🟢 |
| Member wallet/earnings | `member_financial_summary` | ✅ | ✅ | ✅ | `memberFinancialSummaryProvider` | drawer | — | — | `MEMBER_VIEW` | ✅ | 🟢 |
| **Member detail route** | — | — | — | — | — | — | 🔴 no `/admin/members/:id` route (dangling push) | — | — | — | 🔴 |

### 3.3 Complaints / Escalations / Sanctions / Support / SOS

| Feature | Backend | RPC | Datasource | Repository | Provider | Page | Route | Sidebar | Permission | Region | Status |
|---------|---------|-----|-----------|-----------|----------|------|-------|---------|-----------|--------|--------|
| Complaints | `complaints` table + `add_complaint_admin_note` | ✅ | ✅ | ✅ | `adminComplaintsProvider` | `AdminComplaintsPage` | `/admin/complaints` | ✅ | `MEMBER_VIEW`-adjacent | ✅ | 🟢 |
| Escalations | `escalation_events` + `escalate_complaint`/`assign_complaint`/`get_escalation_events` | ✅ 048 | ✅ | ✅ | `escalationEventsProvider` | `AdminEscalationsPage` | `/admin/escalations` | 🔴 not in admin sidebar | admin tier | ✅ | 🟠 (duplicate route reg) |
| Sanctions | `issue_sanction`/`revoke_sanction` | ✅ | ✅ | ✅ | `sanctionsProvider` | `AdminSanctionsPage` | `/admin/sanctions` | ✅ | `MEMBER_BAN`-gated | ✅ | 🟢 |
| Live tracking | `activeDriversLocation` (RPC/query) | ✅ | ✅ | ✅ | `activeDriversLocationProvider` | `AdminLiveTrackingPage` | `/admin/live-tracking` | ✅ | location permission | ✅ | 🟡 not realtime |
| Support chat | `chat_rooms`/`chat_messages` + `.stream()` | — | ✅ | ✅ | `chatRoomsProvider`, `chatMessageStreamProvider` | `AdminSupportChatPage` / `SupportChatRoomPage` | `/admin/support-chat` (+room) | ✅ | `MEMBER_VIEW_CHAT_HISTORY` | ✅ | 🟡 routing through `.stream()` not `RealtimeService` |
| SOS/Emergency | `sos_alerts` + `get_member_ops_profile.location`, `platform_operational_alerts` | ✅ | ✅ | ✅ | via KPI alerts | 🔴 no dedicated SOS page exists | 🔴 no `/admin/emergency` | 🔴 | `EMERGENCY_VIEW` (in `has_permission` vocabulary) | ✅ | 🟠 |

### 3.4 Financial / Wallet / Commissions / Ledger

| Feature | Backend | RPC | Datasource | Repository | Provider | Page | Route | Sidebar | Permission | Region | Status |
|---------|---------|-----|-----------|-----------|----------|------|-------|---------|-----------|--------|--------|
| Financial center | `platform_revenue_overview` | ✅ 050 | ✅ | — | `revenueOverviewProvider` | `AdminFinancialCenter` | `/admin/financial-center` | 🔴 not in sidebar | `PLATFORM_REVENUE` | filter | 🟠 |
| Revenue breakdown | `platform_revenue_breakdown` | ✅ | ✅ | — | `revenueBreakdownProvider` | dashboard + financial | `/admin` | ✅ | `PLATFORM_REVENUE` | filter | 🟢 |
| Wallet intelligence | `platform_wallet_intelligence` | ✅ | ✅ | — | `walletIntelligenceProvider` | `AdminWalletIntelligencePage` | `/admin/wallet-intelligence` | 🔴 not in sidebar | `PLATFORM_REVENUE` | filter | 🟠 |
| Provider intelligence | `platform_provider_intelligence` | ✅ | ✅ | — | `providerIntelligenceProvider` | `AdminProviderIntelligencePage` | `/admin/provider-intelligence` | 🔴 not in sidebar | `PLATFORM_REVENUE` | filter | 🟠 |
| Delivery intelligence | `platform_delivery_intelligence` | ✅ | ✅ | — | `deliveryIntelligenceProvider` | `AdminDeliveryIntelligencePage` | `/admin/delivery-intelligence` | 🔴 not in sidebar | `PLATFORM_REVENUE` | filter | 🟠 |
| Merchant intelligence | `platform_merchant_intelligence` | ✅ | ✅ | — | `merchantIntelligenceProvider` | `AdminMerchantIntelligencePage` | `/admin/merchant-intelligence` | 🔴 not in sidebar | `PLATFORM_REVENUE` | filter | 🟠 |
| Transaction ledger | `platform_transaction_ledger` | ✅ | ✅ | — | `transactionLedgerProvider` | `AdminTransactionLedgerPage` | `/admin/transaction-ledger` | 🔴 not in sidebar | `PLATFORM_REVENUE` | filter | 🟠 |
| Commission summary | `platform_commission_summary` | ✅ | ✅ | — | `commissionSummaryProvider` | financial center | `/admin/financial-center` | — | `PLATFORM_REVENUE` | filter | 🟢 |

### 3.5 Users / Verification / Broadcast / Settings

| Feature | Backend | RPC | Datasource | Repository | Provider | Page | Route | Sidebar | Permission | Region | Status |
|---------|---------|-----|-----------|-----------|----------|------|-------|---------|-----------|--------|--------|
| Users mgmt | `admin_users`, `users` | `create_admin_account` etc. | ✅ | `AdminRepository` | `adminUsersProvider` | `AdminUsersPage` | `/admin/users` | 🔴 not in sidebar | `ADMIN_CREATE` | none | 🟠 |
| Verifications | `decide_user_verification` | ✅ | ✅ | ✅ | `verificationRequestsProvider` | `AdminVerificationsPage` | `/admin/verifications` | 🔴 not in sidebar | `ADMIN_*`/member | region-aware | 🟠 |
| Push broadcast | `admin_broadcast_notification` | ✅ | ✅ | — | `adminNotificationTokensProvider` | `AdminPushNotificationsPage` | `/admin/push-notifications` | 🔴 not in sidebar | `isAdmin` | none | 🟠 |
| Merchants mgmt | `merchants` + `updateMerchantStatus` | ✅ | ✅ | ✅ | `adminMerchantsProvider` | `AdminMerchantsPage` | `/admin/merchants` | 🔴 not in sidebar | `isAdmin` | none | 🟠 |
| Orders mgmt | `orders` + `updateOrderStatus` | ✅ | ✅ | ✅ | `adminOrdersProvider` | `AdminOrdersPage` | `/admin/orders` | 🔴 not in sidebar | `isAdmin` | none | 🟠 |
| Drivers mgmt | `drivers` + `verifyDriver` | ✅ | ✅ | ✅ | `activeDriversProvider` | `AdminDriversPage` | `/admin/drivers` | 🔴 not in sidebar | `isAdmin` | none | 🟠 |
| Deliveries | `rides` service filter | ✅ | ✅ | ✅ | `recentDeliveriesProvider` | `AdminDeliveriesPage` | `/admin/deliveries` | 🔴 not in sidebar | `isAdmin` | none | 🟠 |
| Analytics | `get_admin_analytics`, `get_peak_hours`, `platform_service_performance` | ✅ | ✅ | ✅ | `revenueChartProvider` etc. | `AdminAnalyticsPage` | `/admin/analytics` `/admin/service-performance` | 🔴 | `isAdmin` | none | 🟡 |
| Settings | `platform_settings` | ✅ | ✅ | ✅ | `platformSettingsProvider` | `AdminSettingsPage` | `/admin/settings` | 🔴 not in sidebar | `isAdmin` | none | 🟠 |

### 3.6 Admin hierarchy / Permissions / Region

| Feature | Backend | RPC | Datasource | Repository | Provider | Page | Route | Sidebar | Permission | Region | Status |
|---------|---------|-----|-----------|-----------|----------|------|-------|---------|-----------|--------|--------|
| Admin list | `users` role admin/owner | — | ✅ | — | `adminTierUsersProvider` | admin_web `AdminRegionScopePage` | — | — | `ADMIN_*` | — | 🟡 |
| Region assignments | `admin_region_assignments` | ✅ 031/034 | ✅ | `AdminRegionAssignmentRepositoryImpl` | `adminRegionAssignmentsProvider` | admin_web Region Scope | — | — | `ADMIN_REGION_ASSIGN` | ✅ | 🟡 web-only |
| Permission engine | `has_permission` | ✅ 034 | ✅ | — | — | — | — | — | owner→scope→grant | ✅ | 🟢 |

### 3.7 Realtime

| Feature | Backend | Channel | Consumer | Status |
|---------|---------|---------|----------|--------|
| In-app notifications | `notifications` INSERT | `RealtimeChannels.inAppNotifications` via `RealtimeService` | push service | 🟢 |
| Chat messages | `chat_messages` | implicit `.stream()` (NOT `RealtimeService`) | `chatMessageStreamProvider` | 🟡 bypasses RealtimeService |
| Location | `location_updates` | implicit `.stream()` available, `locationStream()` unused by admin | admin live tracking uses one-shot | 🟡 |
| SOS | `sos_alerts` | `RealtimeChannels.sosAlerts` defined but unused | — | 🟠 |
| Orders/Rides | `orders`/`rides` | implicit `.stream()` (driver only) | — | ⚪ |

### 3.8 IDENTIFIED INTEGRATION BUGS

1. **Android Back behavior** (`canPop`/`go`):
   - Quick actions use `context.go(action.route)` → **replaces** stack top rather than pushing. From a deep admin page, Back may pop past dashboard to Home or exit. **FIX: `context.push` everywhere + PopScope-aware root.**
2. **Member drawer schema mismatch**:
   - `member_drawer.dart` reads `profile['basic']`, `profile['region']['hierarchical_label']`, `permissions['can_decide_verification']/can_issue_sanction/...`
   - `get_member_ops_profile` (049) actually returns `profile['member']`, `profile['region']['label']`, `permissions['can_view_location'/'can_view_chat'/'can_view_documents'/'can_moderate']`
   - **Drawer silently falls back to empty/defaults for name, email, region, permissions.**
3. **Dangling `/admin/members/:id`** — `member_list_page.dart:168` pushes it; no GoRoute exists → page-not-found error.
4. **Duplicate `/admin/escalations`** — registered in both `AdminModule` and `EscalationModule`.
5. **Sidebar coverage** — only 6/25 admin routes surfaced; financial/intelligence/ledger/verifications/users all unreachable from nav.
6. **Hardcoded 'Members'** label in sidebar (no l10n).
7. **Live tracking not realtime** — one-shot fetch with manual refresh.
8. **Chat uses implicit `.stream()`** instead of `RealtimeService` (SPRINT-17 says centralized).
9. **Admin notification deep-link** never passes `isAdmin: true` in `notification_center_page` → admin-only routes fall back to `/notifications`.

---

## 4. Data Integrity Check (live numbers)

- Live users: 17 (16 customers, 1 provider), merchants: 9, complaints: 1 pending, escalations: 1.
- Financial tables empty (0 orders/rides/commissions/wallets) → dashboard 0s are **REAL ZERO**, not a bug.
- `platform_*` RPCs return `null` for anon ✅, data for owner ✅ (STEP 16 verified).

---

## 5. Permissions Matrix (server `has_permission`, migration 034)

| Permission | Fallback grant | Notes |
|-----------|----------------|-------|
| `MEMBER_VIEW` | in-scope yes | owner always |
| `MEMBER_VIEW_LOCATION` | NO (grant-only) | drawer gates location |
| `MEMBER_VIEW_CHAT_HISTORY` | NO (grant-only) | drawer gates chat |
| `MEMBER_VIEW_DOCUMENTS` | NO (grant-only) | drawer gates documents |
| `MEMBER_MODERATE` | in-scope yes | drawer gates admin actions |
| `MEMBER_BAN` / `MEMBER_SUSPEND` / `MEMBER_DELETE` | NO (grant-only) | sanctions RPCs enforce server-side |
| `PLATFORM_REVENUE` | in-scope yes | platform_* RPCs enforce server-side |
| `EMERGENCY_VIEW` | in-scope yes | available for SOS page |
| `ADMIN_CREATE` etc. | owner only / grant | admin management RPCs enforce |

**Verdict:** Server-side authorization is sound (owner bypass → scope → supervisor → grant). Client sidebar is binary `isAdmin` only — acceptable for UI, server remains authoritative.

---

## 6. Back Navigation Analysis

- Admin routes are **standalone** (outside `StatefulShellRoute`), pushed above the root shell → bottom nav absent on admin pages.
- `context.push` from sidebar → correct stack growth (Home → Admin → Detail).
- `context.go` in quick actions/dashboard → **stack replacement** → Back skips levels.
- No `PopScope` anywhere in admin; default GoRouter behavior pops one page then exits app from `/home`.

**Fix plan:**
1. Change dashboard quick actions + legacy dashboard from `context.go` → `context.push`.
2. Keep sidebar `push` semantics.
3. Register `/admin/members/:id` route for member detail.
4. Remove duplicate `/admin/escalations` from `AdminModule` (keep in `EscalationModule`).
5. Add `PopScope(canPop: false)` guard on member operations detail where needed.

---

## 7. What Must Be Rebuilt / Connected

1. **Sidebar**: full grouped admin navigation (الإدارة/الدعم/المالية/التسويق/الإدارة المتقدمة), Arabic labels, collapsible.
2. **Command Center dashboard**: executive KPI groups (Platform/Operations/Financial/Risk), actionable alerts, global search entry, scope selector, time filter.
3. **Global search**: member-centric search surfacing existing `member_ops_list`.
4. **Member drawer fix** (schema mismatch #2).
5. **Route fixes** (#3, #4, #1 back-nav).
6. **Emergency/SOS** page (exists as data, no page).
7. **Realtime** connect Live Tracking + Chat through `RealtimeService`.
8. **Notification deep-link isAdmin fix** (#9).