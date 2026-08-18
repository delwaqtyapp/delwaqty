# STEP 18 — ADMIN COMMAND CENTER (FINAL)

**Date:** 2026-08-18
**Sprint:** 84
**Status:** Complete — committed + pushed

Predecessor audit: `STEP_18_ADMIN_COMMAND_CENTER_AUDIT.md` (feature inventory, 9 integration bugs, permissions matrix).

Legend: 🟢 Complete + Connected · 🟡 Partial · 🟠 Implemented but not connected · 🔴 Missing · ⚪ Not applicable

---

## 1. Objective

Rebuild the Admin Command Center on top of the existing architecture (no backend rebuilds): fix every broken navigation/integration found in the audit, group the entire admin surface, make the dashboard a true command center, and verify live on the physical device.

---

## 2. Bugs Fixed (audit → done)

| # | Audit finding | Fix | File(s) | Status |
|---|---------------|-----|---------|--------|
| 1 | Admin quick actions used `context.go(/admin/...)` → Back could exit app | `go` → `push` on all quick actions | `platform_intelligence_dashboard.dart`, `admin_dashboard_page.dart` | 🟢 |
| 2 | Member drawer read `profile['basic']`/`region.hierarchical_label`/`can_decide_verification` but `get_member_ops_profile` (049) returns `member`/`region.label`/`can_view_*` | Added `normalizeMemberOpsProfile()` adapter at the drawer boundary | `member_drawer.dart` | 🟢 |
| 3 | `/admin/members/:id` dangling push → page-not-found | Registered `MemberDetailPage` under `/admin/members/:id` | `admin_module.dart` | 🟢 |
| 4 | `/admin/escalations` registered in both AdminModule and EscalationModule | Removed duplicate from `AdminModule` | `admin_module.dart` | 🟢 |
| 5 | Sidebar covered only 6/25 admin routes | Rebuilt grouped admin sidebar covering **all 25 routes** + new emergency | `floating_sidebar_overlay.dart`, `sidebar_section.dart` (collapsible) | 🟢 |
| 6 | Hardcoded `'Members'` sidebar label (no l10n) | New `adminMembers`/`admin*` l10n keys (en + ar) | `app_en.arb`, `app_ar.arb` | 🟢 |
| 7 | Live tracking was one-shot fetch (not realtime) | Dedicated realtime wire-up in emergency page; tracked 🟡 — live-tracking page still one-shot fetch (see §5) | `admin_emergency_page.dart` | 🟡 |
| 8 | Chat uses implicit `.stream()` not `RealtimeService` | Kept (chat stream is correct for its RLS-scoped usage); `sosAlerts` channel now routed through `RealtimeService` | `admin_emergency_page.dart` | 🟡 |
| 9 | Admin notification deep-link never `isAdmin: true` | `NotificationCenterPage` now resolves `AuthAuthenticated.user.isAdmin` and passes it | `notification_center_page.dart` | 🟢 |
| 10 | **NEW (found during live verify)** `Member.fromJson` cast `List<dynamic>` → `List<String>` throws on real `member_ops_list` rows → empty member list despite live data | Safe `(json[...] as List<dynamic>?)?.cast<String>()`; notifier now catches errors and exposes `lastError` + retry UI | `member.dart`, `member_providers.dart`, `member_operations_center.dart` | 🟢 |

---

## 3. New / Rebuilt UI

### 3.1 Command Center dashboard (`/admin`)
- 🟢 **Grouped KPI sections** — Platform / Operations / Financial / Risk (`_KpiGroup`, animated)
- 🟢 **Geo scope selector** — `governoratesProvider` dropdown (كافة المحافظات + governorates) → `adminScopeRegionProvider` feeds `platform_kpi_summary(p_region_id)`
- 🟢 **Time filter** (اليوم / الأسبوع / الشهر / الربع / الكل) — existing
- 🟢 **Global search entry** → `/search`
- 🟢 Actionable operational alerts (existing), revenue breakdown (existing)
- AppBar title now `adminCommandCenter` (مركز القيادة)

### 3.2 Grouped admin sidebar
Collapsible admin section (`CollapsibleSidebarSection`) with **5 groups** and localized labels:
- **العمليات** — Command Center, Members, Users, Merchants, Drivers, Orders, Deliveries, Verifications, Complaints, Escalations, Sanctions
- **الدعم** — Support Chat, Live Tracking, Emergency
- **المالية** — Financial Center, Transaction Ledger, Wallet Intelligence
- **التسويق** — Service Performance, Push Notifications
- **الإدارة المتقدمة** — Analytics, Delivery/Merchant/Provider Intelligence, Settings, Legacy Dashboard

Coverage: **25/25 admin routes** (was 6/25). Expand/collapse with tooltips `adminExpand`/`adminCollapse`.

### 3.3 Emergency / SOS page (`/admin/emergency`)
- 🟢 Active SOS alerts from `sos_alerts` (admin select policy 033) with realtime refresh via `RealtimeService` + `RealtimeChannels.sosAlerts`
- 🟢 Critical/high `platform_operational_alerts` surfaced
- Fresh route added to `AdminModule`

### 3.4 Member detail route
- 🟢 `/admin/members/:id` → `MemberDetailPage` (was a dangling push target)

---

## 4. Verification

### Static
- `dart analyze lib/` — **0 errors, 0 warnings**
- `flutter gen-l10n` regenerated cleanly

### Tests (targeted suites; full-suite hangs in PROot-Distro)
- Admin 65 + member 10 + notifications + safety + escalation + complaints + router 139-target suite — **139/139 green**, 0 failures (includes new `Member.fromJson` dynamic-array regression test)

### Live device (DNP NX9 over adb wireless, `192.168.8.36`)
- `flutter build apk --debug --dart-define-from-file=.env.dev` — built
- `adb install -r app-debug.apk` — installed, app launches, no crashes (logcat clean)
- ✅ Command Center renders with real zeros/matches (17 users, 9 merchants, 1 complaint, 0 orders — real empty financial tables)
- ✅ Grouped sidebar opens with Arabic groups (العمليات/الدعم/المالية/التسويق/الإدارة المتقدمة) and all admin items
- ✅ **Back navigation verified**: Command Center → Home, Members → Home — stays in app (exit only at Home root)
- ✅ Member list now returns live users (bug #10 was confirmed reproducing before the fix: "No members found" → fixed build lists all 17)
- ✅ Member drawer renders all 14 sections on a live admin member (normalizer works)
- ✅ `/admin/emergency` route added; `sos_alerts` admin-select policy verified present (migration 033)

### Live SQL
- `member_ops_list` returns 17 rows under owner JWT context (verified via `set_config('request.jwt.claims', ...)`)
- `platform_operational_alerts()` returns empty (no alerts; all financial tables genuinely empty)

---

## 5. Remaining / Known partial (explicitly tracked, not blocked)

| Item | State | Why kept |
|------|-------|----------|
| `AdminLiveTrackingPage` — one-shot fetch | 🟡 | Location stream is user-scoped; a platform-wide administrator location stream needs a server RPC + RLS policy. Classified Dormant Infrastructure-friend: do not delete, wire when server support lands. |
| Chat `.stream()` not via `RealtimeService` | 🟡 | Correct for its RLS-scoped subscription; centralizing would change subscription semantics. `RealtimeService` is canonical for new channels (`sosAlerts`). |
| Owner id not in `admin_users` | ⚪ | Pre-existing, documented in audit; role `owner` → `is_admin()` bypass works. |
| All financial tables empty (0 orders/rides/wallets) | ⚪ | Real zero, not a bug. |

---

## 6. Files modified

- `lib/features/admin/presentation/pages/platform_intelligence_dashboard.dart` — grouped KPIs, scope selector, search, `push` nav
- `lib/features/admin/presentation/pages/admin_dashboard_page.dart` — quick-action `go`→`push`
- `lib/features/admin/presentation/providers/platform_intelligence_providers.dart` — `adminScopeRegionProvider`, KPI region pass-through
- `lib/features/admin/presentation/pages/admin_emergency_page.dart` — **new** SOS page
- `lib/features/admin/admin_module.dart` — members/:id route, emergency route, removed duplicate escalations
- `lib/features/floating_sidebar/floating_sidebar_overlay.dart` — grouped admin sidebar (all 25 routes)
- `lib/features/floating_sidebar/sidebar_section.dart` — `CollapsibleSidebarSection`
- `lib/features/member_management/domain/entities/member.dart` — safe list casts (bug #10)
- `lib/features/member_management/presentation/member_providers.dart` — error capture + `refresh`
- `lib/features/member_management/presentation/pages/member_operations_center.dart` — error state + retry
- `lib/features/member_management/presentation/pages/member_drawer.dart` — `normalizeMemberOpsProfile`
- `lib/features/notifications/presentation/pages/notification_center_page.dart` — `isAdmin` deep-link
- `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` — admin sidebar/group keys
- `test/features/member_management/member_entity_test.dart` — regression test

No backend (migration/SQL) changes were required for this step.

---

## 7. Commit

`sprint 84: rebuild admin command center`