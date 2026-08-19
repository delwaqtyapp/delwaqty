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

---

# APPENDIX — Sprint 85: Backend Hardening + Commission Management + Approvals Center + Admin Locale

**Date:** 2026-08-19 · **Sprint 85 · Status:** implemented, migrated, tested

Follow-up deep-dive that moved the admin surface from "rebuild on top of existing" to **fixing the backend itself**. Four live migrations closed real authorization/logic gaps and two brand-new admin pages replaced dead UI.

---

## 8. Backend findings → fixes (live-verified)

| # | Finding | Root cause | Fix | Verified |
|---|---------|------------|-----|----------|
| A | **`decide_approval_request` regressed** to campaign-only: `040:354` rejected every type except `campaign_approve` (owner could never decide admin/member/offer approvals) | Migration 040 narrowed a full dispatcher (admin_*, member_ban, member_delete, reward_config_change) that existed in 034/045 | **052** restored the full dispatcher (authority guards + `_approval_apply`) | Owner approve → request executes; non-owner → `P0001: Not authorized` |
| B | **Commissions hardcoded** `rate = 7` / `rate = 3` inside `050` `platform_kpi_summary` / `platform_revenue_breakdown` / `platform_revenue_overview` | 050 inlined constants instead of consulting `commission_rules` | **052** added `set_commission_rate` (PLATFORM_REVENUE-gated, versioned history, `COMMISSION_RATE_CHANGED` audit) + `list_commission_rules`; recreated `get_commission_rate` (effective-date, most-specific-wins); added service_role-only `_commission_bucket_amount`; recreated all three analytics fns with rule-derived buckets | Rates: provider 7.00 / merchant 3.00 / driver 7.00 / customer 0.00 / restaurant 3.00; owner-set 4.25 test rate round-trips then was removed |
| C | **`get_admin_analytics` unsecured**: not SECURITY DEFINER, no gate, but granted to `authenticated` | 029 shipped an admin-only RPC without access control | **052** hardened it (SECURITY DEFINER + `is_admin()` gate + `SET search_path`) | Non-admin call → `P0001: Not authorized` |
| D | **UI called nonexistent `delete_user_account`**; `delete_member_account` (035:631) had no email-confirmation step | RPC name mismatch + destructive action without final confirmation  | **053** added `request_member_deletion(p_member_id, p_confirmation_email, p_reason)` — validates the admin-typed email against the member, computes `DELETE-<sha256(email)>` server-side, opens a `member_delete` approval | Wrong email → rejected; correct email → approval → owner decide → user deactivated + anonymized (`deleted-…@anonymized.invalid`); fixture cleaned up |
| E | **No listing API** for the Approvals Center (current 034 functions only decide/create) | Approvals were admin-action side-effects, not a browsable queue | **054** added `list_approval_requests(p_state='pending', p_limit=100)` (admin-gated, JSON `{requests:[...]}`) | `apply.py` → HTTP 201; rows returned under owner JWT |
| F | **Fake "Reset All Data" Danger Zone** in Admin Settings (dialog with no RPC, no permission) | Leftover placeholder UI | Removed UI entirely + dropped the l10n keys | `dart analyze` clean; no destructive surface remains |
| G | Sidebar exposed **every admin route at app level** → navigation duplicated with the new in-admin nav | Sprint-84 shipped both | Sidebar collapsed to **one App-level admin entry**; the full grouped navigation now lives inside `AdminShell` (26 grouped items) | Tests updated |

**Server-side tooling note:** `apply.py` auto-commits every statement and JWT claims are **transaction/batch-local** — owner-simulation fixtures must live in the same batch as their assertions (cross-batch probes fail with "Not authorized for this member"). Verified empirically; this also means fresh migrations are applied as `authenticated` (no owner session persists).

---

## 9. New UI

- **`AdminShell`** (`lib/features/admin/admin_shell.dart`) — wraps all 26 `/admin` routes: applies the **independent Admin locale** via `Localizations.override` + `Directionality` (RTL for Arabic), hosts the **grouped admin rail** (≥1100px) / **drawer + floating control** (phones, hidden on chat-room/member-detail), syncs active state with the matched route.
- **`AdminLocaleNotifier`** (`lib/core/localization/admin_locale_provider.dart`) — separate persisted locale (`admin_locale`, default `Locale('ar')`), switchable live from Admin Settings without touching the app language.
- **Commission Management** (`/admin/commissions`) — groups all rules by account/service/category, shows active + history rows, inline edit dialog (decimal filter) → `set_commission_rate` → invalidates `commissionRulesProvider`.
- **Approvals Center** (`/admin/approvals`) — `pendingApprovalsProvider` renders the pending queue with localized request-type badges; approve / reject-with-reason dialogs → `decide_approval_request`.
- **Admin Settings rebuilt** — two sections: *Personal* (Admin language switch) + *Global* (platform settings); Danger Zone removed.

---

## 10. Verification

- **Static:** `dart analyze` on all touched areas — 0 errors, 0 warnings. Removed two pre-existing unused imports (`AppColors`) in `admin_dashboard_page.dart` / `admin_analytics_page.dart`.
- **Tests:** `flutter test test/features/admin test/features/member_management` — **77/77 green**, including updated sidebar test (collapsed single entry) + new `admin_shell` grouped-nav assertions.
- **Live SQL:** migrations **052**, **053**, **054** applied (HTTP 201) and each behavior probed with the owner JWT as recorded in §8.

---

## 11. Files (sprint 85)

- `supabase/migrations/052_admin_commission_approval_fixes.sql` · `053_member_deletion_confirmation.sql` · `054_approval_center_listing.sql` — **new, applied**
- `lib/features/admin/admin_shell.dart` — **new** shell/rail/drawer + admin nav groups
- `lib/features/admin/presentation/pages/admin_commission_management_page.dart` · `admin_approvals_center_page.dart` — **new**
- `lib/core/localization/admin_locale_provider.dart` · `lib/core/constants/storage_keys.dart` (`adminLocale`) — **new**
- `lib/services/admin/admin_providers.dart` — `commissionRulesProvider`, `pendingApprovalsProvider`
- `lib/features/admin/admin_module.dart` — wrapped every route in `AdminShell`, registered `commissions` + `approvals`
- `lib/features/admin/presentation/pages/admin_settings_page.dart` — personal/global split, admin language switch, no Danger Zone
- `lib/features/floating_sidebar/floating_sidebar_overlay.dart` — single app-level admin entry (grouped nav moved into the shell)
- `lib/features/member_management/presentation/pages/member_drawer.dart` — `request_member_deletion`, `issue_sanction`, restore unsupported snackbar
- `lib/features/admin/presentation/pages/admin_analytics_page.dart`, `admin_dashboard_page.dart` — removed unused imports
- `lib/l10n/app_en.arb`, `app_ar.arb` + generated files — approval/commission/shell keys; removed danger-zone keys
- `test/features/member_management/member_management_module_test.dart` — updated sidebar + shell tests

---

## 12. Commit

`commit upcoming: sprint 85: harden admin backend, add commissions + approvals centers`
---

## 13. Appendix — Sprint 86 (Full Localization + Deletion Rework)

### 13.1 Member deletion rework (mandate #3)

`_confirmDeletion` in `member_drawer.dart` is now a pure **confirmation dialog**: shows `deleteAccountMessage` warning, auto-displays the member's email (`memberEmailLabel`, read from `profile['email']`), and collects only a reason. The email is passed automatically to `request_member_deletion(p_member_id, p_confirmation_email, p_reason)`. All email-typing UI removed — the server still validates the email (053) so the security guarantee is intact.

### 13.2 Localization coverage (mandate #2)

- **Member drawer** — all sections localized (Identity, Verification, Location, Timeline, Orders/Deliveries, Services, Wallet/Earnings, Complaints, Support, Sanctions, Documents, Admin Actions) with `_StatusChip`-style helpers.
- **Admin pages** — emergency, delivery intelligence, financial center, wallet/merchant/provider intelligence, merchants, commission management, analytics (`MaterialLocalizations.formatTimeOfDay` replaces hardcoded AM/PM), transaction ledger.
- **Member management** — operations center (filters, sort, tiles via `_accountStatusLabel`/`_roleLabel`), member detail (sanction sheet, contact card, sanctions section, timeline).
- Added ~135 keys to **both** `app_en.arb` and `app_ar.arb` (OrderedDict-preserving python script; parity validated each `gen-l10n`); missing Arabic `addBranch`/`branchName` backfilled.
- Removed a non-existent `l10n.provider` role branch (fallback keeps raw role).

### 13.3 Link audit (mandate #4)

All 26 admin nav items in `admin_shell.dart` resolve to registered routes in `admin_module.dart`; `/admin/escalations` resolves via `escalation_module.dart`; `/search` resolves via `search_module.dart`. No dangling links.

### 13.4 Verification

- `dart analyze <touched>` — 0 errors / 0 warnings per file
- `flutter test test/features/admin test/features/member_management` — **73/73 green**
- `flutter build apk --debug --dart-define-from-file=.env.dev` — built

### 13.5 Files (sprint 86)

- `lib/l10n/app_en.arb` · `app_ar.arb` + `app_localizations*.dart` (new key set)
- `lib/features/member_management/presentation/pages/member_drawer.dart` (deletion rework + localization)
- `lib/features/member_management/presentation/pages/member_operations_center.dart` · `member_detail_page.dart`
- `lib/features/admin/admin_module.dart` · `admin_shell.dart` · `domain/entities/admin_models.dart`
- `lib/features/admin/presentation/pages/*` (all localized; `admin_dashboard_page.dart` deleted — redundant vs Command Center)
- `lib/services/admin/admin_providers.dart` · `admin_service.dart`
- `test/features/admin/domain/entities_test.dart`
