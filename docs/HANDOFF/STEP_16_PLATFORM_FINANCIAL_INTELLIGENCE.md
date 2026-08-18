# STEP 16: Platform Operations + Financial Intelligence Center

> **Status:** Complete — sprint 82
> **Date:** 2026-08-18
> **Commit:** pending

---

## Executive Summary

Built the Platform Operations + Financial Intelligence Center: 14 SECURITY DEFINER PostgreSQL RPCs for server-side aggregation, a completely rewritten admin dashboard with 12 KPI cards and time-period filtering, financial center, delivery intelligence, merchant intelligence, provider intelligence, wallet intelligence, transaction ledger, and operational alerts panel. All data flows through Freezed entities and Riverpod providers.

---

## Backend: 14 SECURITY DEFINER RPCs

All functions are `SECURITY DEFINER`, require `has_permission('MEMBER_VIEW')`, and most additionally require `has_permission('PLATFORM_REVENUE')` for financial data.

| RPC | Purpose | Verified |
|-----|---------|----------|
| `platform_kpi_summary(p_from, p_to, p_region_id)` | All top-level KPIs (members, orders, rides, financials, risk) | ✅ |
| `platform_revenue_breakdown(p_from, p_to, p_region_id)` | GMV, commission by rate, refunds, net revenue | ✅ |
| `platform_service_performance(p_from, p_to)` | Per-service-category metrics (home/ride/delivery) | ✅ |
| `platform_delivery_intelligence(p_from, p_to)` | Driver stats, delivery GMV, earnings, withdrawals | ✅ |
| `platform_merchant_intelligence(p_from, p_to)` | Per-merchant metrics, type breakdown | ✅ |
| `platform_wallet_intelligence(p_from, p_to)` | Wallet liability, transactions by type | ✅ |
| `platform_provider_intelligence(p_from, p_to)` | Service provider metrics by category | ✅ |
| `platform_commission_summary(p_from, p_to)` | Commission by rate, active rules | ✅ |
| `platform_complaint_summary(p_from, p_to)` | Complaint/escalation metrics | ✅ |
| `platform_transaction_ledger(p_from, p_to, p_type, p_member_id, p_search, p_limit, p_offset)` | Paginated transaction ledger | ✅ |
| `platform_revenue_overview(p_period, p_service_category, p_from, p_to)` | Revenue by period | ✅ |
| `platform_orders_timeseries(p_from, p_to)` | Orders/rides/bookings by day + by status | ✅ |
| `platform_rides_timeseries(p_from, p_to)` | Rides/deliveries by day | ✅ |
| `platform_operational_alerts()` | Deterministic alerts (no data-dependent) | ✅ |

### Bug Fixes Applied

1. **KPI 100-argument limit:** Split `jsonb_build_object` into 7 nested chunks (members, drivers+merchants, orders, rides+deliveries, financial, risk)
2. **Merchant GROUP BY:** Removed `LATERAL` join GROUP BY error — simplified to ordered subselect
3. **Ledger GROUP BY:** Wrapped ORDER BY+LIMIT in subselect to avoid non-aggregated column error

---

## Flutter: 20 Freezed Entities

`lib/features/admin/domain/entities/platform_intelligence.dart` — 674 lines, generated 232KB freezed + 27KB JSON.

---

## Flutter: Data Source + Providers

- `PlatformIntelligenceDataSource` — 14 RPC methods with dual unwrapping pattern
- 15 Riverpod providers including `AdminTimeFilter` state class (today/week/month/quarter/all)

---

## Flutter: 7 New Pages

| Page | Route | Description |
|------|-------|-------------|
| `PlatformIntelligenceDashboard` | `/admin` | 12 KPI cards, time filter, revenue, alerts, quick actions |
| `AdminFinancialCenter` | `/admin/financial-center` | Revenue hero, commission breakdown, rules |
| `AdminDeliveryIntelligencePage` | `/admin/delivery-intelligence` | Driver stats, delivery metrics, withdrawals |
| `AdminMerchantIntelligencePage` | `/admin/merchant-intelligence` | Merchant list with type/rating/status |
| `AdminProviderIntelligencePage` | `/admin/provider-intelligence` | Provider stats, bookings by category |
| `AdminWalletIntelligencePage` | `/admin/wallet-intelligence` | Wallet liability, transactions by type |
| `AdminTransactionLedgerPage` | `/admin/transaction-ledger` | Paginated ledger with filter + search |

---

## Security Probes

All 14 RPCs return `null` for anon ✅
All 14 RPCs return data for owner ✅

---

## Tests

- Admin tests: 65/65 pass
- Member/complaints/sanctions/escalation tests: 42/42 pass
- `dart analyze lib/features/admin/`: 0 errors

---

## Files Modified

- `supabase/migrations/050_platform_financial_intelligence_rpcs.sql` (new + 3 fixes)
- `lib/features/admin/domain/entities/platform_intelligence.dart` (new)
- `lib/features/admin/data/datasources/remote/platform_intelligence_data_source.dart` (new)
- `lib/features/admin/presentation/providers/platform_intelligence_providers.dart` (new)
- `lib/features/admin/presentation/pages/platform_intelligence_dashboard.dart` (new)
- `lib/features/admin/presentation/pages/admin_financial_center.dart` (new)
- `lib/features/admin/presentation/pages/admin_delivery_intelligence_page.dart` (new)
- `lib/features/admin/presentation/pages/admin_merchant_intelligence_page.dart` (new)
- `lib/features/admin/presentation/pages/admin_provider_intelligence_page.dart` (new)
- `lib/features/admin/presentation/pages/admin_wallet_intelligence_page.dart` (new)
- `lib/features/admin/presentation/pages/admin_transaction_ledger_page.dart` (new)
- `lib/features/admin/admin_module.dart` (routes + imports)
- `SESSION_STATUS.md` (updated)
- `ROADMAP.md` (sprint 82 added)

---

## Live DB State

- 17 users (16 customers, 1 provider)
- 9 merchants (5 food, 2 grocery, 1 pharmacy, 1 bakery)
- 1 complaint (pending), 1 escalation
- 0 orders, 0 rides, 0 wallets, 0 commissions (empty financial tables)
- Commission rules: 19 active (7% provider/driver + 3% merchant + per-category)
