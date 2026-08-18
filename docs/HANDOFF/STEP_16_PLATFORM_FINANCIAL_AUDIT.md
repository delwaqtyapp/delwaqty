# STEP 16 — Platform Operations + Financial Intelligence Center — Full Audit

> **Date:** 2026-08-18
> **Author:** Lead Software Architect (automated)
> **Authority:** PROJECT_CONSTITUTION.md v2.0

---

## 1. Executive Summary

STEP 16 transforms the admin dashboard from a basic stat-card view into a **production-grade platform operations and financial intelligence center**. Every number shown must trace back to real database records.

### Current State
- 897/897 tests green (STEP 15)
- 17 users, 9 merchants, 1 complaint, 1 escalation
- All financial tables exist but are EMPTY (no orders, rides, wallets, commissions, settlements)
- Existing dashboard: 8 stat cards via N+1 client-side queries + `count_table_rows` RPC
- No time filtering, no regional intelligence, no commission breakdown, no financial center

### Target State
- Server-side aggregation RPCs for all metrics (no N+1)
- Time period filtering (today/yesterday/7d/30d/month/year/custom)
- Regional intelligence (Egypt → Governorate → City → Region)
- Service performance by category
- Delivery intelligence
- Provider intelligence
- Merchant/Restaurant/Pharmacy intelligence
- Financial center (revenue, commissions, settlements, wallets, ledger)
- Operational alerts
- Full security matrix (8 roles)

---

## 2. Live Database Inventory

### 2.1 User Ecosystem (17 users)

| user_type | count | verification_status breakdown |
|-----------|-------|-------------------------------|
| customer | 16 | 13 approved, 3 pending |
| provider | 1 | 1 rejected |
| delivery | 0 | — |
| merchant | 0 | — |
| driver | 0 | — |

**admin_users:** 0 rows (empty — owner is in `users.role = 'owner'`)

### 2.2 Merchants (9)

| type | count |
|------|-------|
| food | 5 |
| grocery | 2 |
| pharmacy | 1 |
| bakery | 1 |

### 2.3 Service Categories (8)

| type | name_en | name_ar |
|------|---------|---------|
| acMaintenance | AC Maintenance | صيانة تكييف |
| applianceRepair | Appliance Repair | إصلاح أجهزة |
| carpentry | Carpentry | نجارة |
| cleaning | Cleaning | تنظيف |
| electrical | Electrical | كهرباء |
| painting | Painting | دهان |
| pestControl | Pest Control | مكافحة حشرات |
| plumbing | Plumbing | سباكة |

### 2.4 Financial Tables — ALL EMPTY

| table | rows | columns |
|-------|------|---------|
| orders | 0 | 22 (id, user_id, merchant_id, driver_id, status, payment_status, payment_method, subtotal, delivery_fee, discount, tax, total_amount, coupon_id, delivery_address, lat/lng, cancelled_reason, notes, created_at, updated_at, payment_id, transaction_id) |
| rides | 0 | 61 (full dispatch + delivery + pricing + OTP + location) |
| service_bookings | 0 | 18 (user_id, provider_id, category_type, status, scheduled_date/time, estimated_price, final_price) |
| wallets | 0 | 6 (user_id, balance, currency) |
| wallet_transactions | 0 | 9 (wallet_id, type, amount, reference_type/id, description, balance_after) |
| platform_commissions | 0 | 14 (member_id, reference_type/id, gross_amount, commission_rate, commission_amount, net_amount, currency, status, fulfilled_at) |
| commission_rules | 9 | 13 (entity_type, entity_key, rate, currency, effective_from/to, is_active) |
| driver_earnings | 0 | 8 (driver_id, ride_id, type, amount, currency, description) |
| payment_transactions | 0 | 13 (order_id, user_id, provider, amount_cents, currency, status) |
| withdrawal_requests | 0 | 7 (driver_id, amount, status, method) |
| complaints | 1 | 21 (pending) |
| sanctions | 0 | 18 |
| escalation_events | 1 | 10 |
| sos_alerts | 0 | 12 |

### 2.5 Commission Rules (LIVE)

| entity_type | entity_key | rate | currency | is_active |
|-------------|-----------|------|----------|-----------|
| delivery | courier | 0.07 | EGP | true |
| delivery | food | 0.07 | EGP | true |
| delivery | grocery | 0.07 | EGP | true |
| delivery | package | 0.07 | EGP | true |
| delivery | pharmacy | 0.07 | EGP | true |
| provider | plumbing | 0.07 | EGP | true |
| provider | electrical | 0.07 | EGP | true |
| provider | carpentry | 0.07 | EGP | true |
| provider | cleaning | 0.07 | EGP | true |
| provider | painting | 0.07 | EGP | true |
| provider | pestControl | 0.07 | EGP | true |
| provider | acMaintenance | 0.07 | EGP | true |
| provider | applianceRepair | 0.07 | EGP | true |
| restaurant | food | 0.03 | EGP | true |
| restaurant | grocery | 0.03 | EGP | true |
| restaurant | bakery | 0.03 | EGP | true |
| pharmacy | pharmacy | 0.03 | EGP | true |

**Note:** The original prompt specified 7% driver/provider + 3% restaurant/pharmacy. The actual DB has ALL delivery types at 7%, ALL provider types at 7%, restaurants at 3%, pharmacies at 3%. This is consistent.

### 2.6 Regions

Hierarchical: country → governorate → markaz → city (6,157 regions total). RLS via `admin_region_assignments` + `is_admin_for_region()`.

---

## 3. Data Source Matrix

### 3.1 MEMBERS

| Metric | Source Table | Source Column | Calculation | Auth |
|--------|-------------|---------------|-------------|------|
| Total Members | users | id | COUNT(*) | Admin+ |
| Customers | users | id | COUNT(*) WHERE user_type='customer' | Admin+ |
| Providers | users | id | COUNT(*) WHERE user_type='provider' | Admin+ |
| Delivery | users | id | COUNT(*) WHERE user_type='delivery' | Admin+ |
| Drivers | users | id | COUNT(*) WHERE user_type='driver' | Admin+ |
| Merchants (as users) | users | id | COUNT(*) WHERE user_type='merchant' | Admin+ |
| Active Members | users | id, updated_at | COUNT(*) WHERE updated_at > now() - interval | Admin+ |
| Online Members | drivers | is_online | COUNT(*) WHERE is_online = true | Admin+ |
| Pending Verification | users | verification_status | COUNT(*) WHERE verification_status='pending' | Admin+ |
| Approved This Period | users | created_at, verification_status | COUNT(*) WHERE verification_status='approved' AND created_at >= period_start | Admin+ |

### 3.2 ORDERS / RIDES / SERVICE BOOKINGS

| Metric | Source Table | Source Column | Calculation | Auth |
|--------|-------------|---------------|-------------|------|
| Total Orders | orders | id | COUNT(*) | Admin+ |
| Orders Today | orders | id, created_at | COUNT(*) WHERE created_at >= today_start | Admin+ |
| Orders This Week | orders | id, created_at | COUNT(*) WHERE created_at >= week_start | Admin+ |
| Orders This Month | orders | id, created_at | COUNT(*) WHERE created_at >= month_start | Admin+ |
| Completed Orders | orders | id, status | COUNT(*) WHERE status='completed' | Admin+ |
| Pending Orders | orders | id, status | COUNT(*) WHERE status='pending' | Admin+ |
| Cancelled Orders | orders | id, status | COUNT(*) WHERE status='cancelled' | Admin+ |
| Total Rides | rides | id, service_type='ride' | COUNT(*) | Admin+ |
| Rides by Status | rides | status | GROUP BY status | Admin+ |
| Total Deliveries | rides | id, service_type!='ride' | COUNT(*) | Admin+ |
| Deliveries by Status | rides | status, service_type | GROUP BY status, service_type | Admin+ |
| Service Bookings | service_bookings | id | COUNT(*) | Admin+ |
| Bookings by Status | service_bookings | status, category_type | GROUP BY status, category_type | Admin+ |

### 3.3 FINANCIAL

| Metric | Source Table | Source Column | Calculation | Auth |
|--------|-------------|---------------|-------------|------|
| GMV (Gross Merchandise Value) | orders | total_amount | SUM(total_amount) WHERE status='completed' | Admin+ |
| Ride GMV | rides | fare | SUM(fare) WHERE status='completed' AND service_type='ride' | Admin+ |
| Delivery GMV | rides | fare | SUM(fare) WHERE status='completed' AND service_type!='ride' | Admin+ |
| Service GMV | service_bookings | final_price | SUM(final_price) WHERE status='completed' | Admin+ |
| Total GMV | All above | — | SUM of all | Admin+ |
| Platform Commission | platform_commissions | commission_amount | SUM(commission_amount) | Admin+ |
| Commission by Rate | platform_commissions | commission_rate, commission_amount | GROUP BY commission_rate | Admin+ |
| Refunds | orders | discount, status='refunded' | SUM(discount) WHERE status='refunded' | Admin+ |
| Adjustments | wallet_transactions | type='adjustment' | SUM(amount) WHERE type='adjustment' | Admin+ |
| Net Platform Revenue | platform_commissions | commission_amount, status='fulfilled' | SUM(commission_amount) WHERE status='fulfilled' | Admin+ |

### 3.4 EARNINGS & SETTLEMENTS

| Metric | Source Table | Source Column | Calculation | Auth |
|--------|-------------|---------------|-------------|------|
| Provider Earnings | service_bookings | final_price, provider_id | SUM(final_price) GROUP BY provider_id | Admin+ |
| Driver Earnings | driver_earnings | amount | SUM(amount) | Admin+ |
| Merchant Settlement | orders | total_amount, merchant_id | SUM(total_amount) - platform_commission GROUP BY merchant_id | Admin+ |
| Pending Settlements | withdrawal_requests | status='pending' | COUNT(*), SUM(amount) | Admin+ |
| Paid Settlements | withdrawal_requests | status='paid' | COUNT(*), SUM(amount) | Admin+ |

### 3.5 WALLETS

| Metric | Source Table | Source Column | Calculation | Auth |
|--------|-------------|---------------|-------------|------|
| Total Wallet Liability | wallets | balance | SUM(balance) | Admin+ |
| Wallet Count | wallets | id | COUNT(*) | Admin+ |
| Transactions This Period | wallet_transactions | created_at | COUNT(*) WHERE created_at >= period_start | Admin+ |

### 3.6 RISK & OPERATIONS

| Metric | Source Table | Source Column | Calculation | Auth |
|--------|-------------|---------------|-------------|------|
| Open Complaints | complaints | status | COUNT(*) WHERE status NOT IN ('resolved','closed') | Admin+ |
| Escalated Complaints | complaints | escalated_at | COUNT(*) WHERE escalated_at IS NOT NULL | Admin+ |
| Active Sanctions | sanctions | is_active | COUNT(*) WHERE is_active=true | Admin+ |
| Emergency/SOS | sos_alerts | status | COUNT(*) WHERE status='active' | Admin+ |
| Payment Failures | payment_transactions | status | COUNT(*) WHERE status='failed' | Admin+ |

### 3.7 SERVICES

| Metric | Source Table | Source Column | Calculation | Auth |
|--------|-------------|---------------|-------------|------|
| Active Providers | service_providers | is_available | COUNT(*) WHERE is_available=true GROUP BY category_type | Admin+ |
| Bookings by Category | service_bookings | category_type, status | GROUP BY category_type, status | Admin+ |
| Category Revenue | service_bookings | final_price, category_type | SUM(final_price) GROUP BY category_type | Admin+ |
| Category Ratings | service_providers | rating, category_type | AVG(rating) GROUP BY category_type | Admin+ |

### 3.8 DELIVERY

| Metric | Source Table | Source Column | Calculation | Auth |
|--------|-------------|---------------|-------------|------|
| Active Drivers | drivers | is_online | COUNT(*) WHERE is_online=true | Admin+ |
| Online Drivers | drivers | status | COUNT(*) WHERE status='online' | Admin+ |
| Verified Drivers | drivers | is_verified | COUNT(*) WHERE is_verified=true | Admin+ |
| Completed Deliveries | rides | status, service_type | COUNT(*) WHERE status='completed' AND service_type!='ride' | Admin+ |
| Delivery GMV | rides | fare, service_type | SUM(fare) WHERE status='completed' AND service_type!='ride' | Admin+ |
| Driver Earnings Total | driver_earnings | amount | SUM(amount) | Admin+ |

---

## 4. Existing Flutter Architecture

### 4.1 Admin Dashboard (Current)
- `admin_dashboard_page.dart` — 8 stat cards (totalUsers, totalMerchants, totalOrders, revenue, activeDrivers, pendingOrders, totalRides, totalDeliveries) + quick actions + activity feed
- `admin_models.dart` — `AdminDashboardMetrics` (15 fields), `AdminDashboard` (legacy)
- `admin_repository.dart` (data) — N+1 queries: `count_table_rows` RPC × 3 + 9 sequential count queries + 6 fare summation queries
- `admin_providers.dart` — `dashboardMetricsProvider`, `recentActivityProvider`, etc.
- `admin_service.dart` — thin wrapper

### 4.2 Problems with Current Dashboard
1. **N+1 queries**: 15+ sequential Supabase queries to build one dashboard
2. **No time filtering**: Hardcoded today/month
3. **No regional filtering**: All data is global
4. **No commission visibility**: Revenue = fare sum, not commission
5. **No financial center**: No separate financial page
6. **No service performance**: No breakdown by service category
7. **No delivery intelligence**: No delivery-specific view
8. **No merchant intelligence**: Basic merchant count only
9. **No wallet metrics**: Not tracked at all
10. **Revenue is fare-based**: Not commission-based (wrong for platform)

---

## 5. Migration Plan

### 5.1 New RPCs (Migration 050)

| RPC | Returns | Purpose |
|-----|---------|---------|
| `platform_kpi_summary` | JSONB | All top-level KPIs in one call (time-filtered) |
| `platform_orders_summary` | JSONB | Order/ride/booking counts by status (time-filtered) |
| `platform_financial_summary` | JSONB | GMV, commission, refunds, net revenue (time-filtered) |
| `platform_service_performance` | JSONB[] | Performance per service category (time-filtered) |
| `platform_delivery_intelligence` | JSONB | Driver stats, delivery GMV, earnings |
| `platform_merchant_intelligence` | JSONB[] | Per-merchant metrics |
| `platform_wallet_summary` | JSONB | Wallet liability, transactions |
| `platform_settlement_summary` | JSONB | Pending/paid settlements |
| `platform_financial_ledger` | JSONB[] | Paginated transaction ledger |
| `platform_regional_kpi` | JSONB | KPIs filtered by region |
| `platform_alerts` | JSONB[] | Operational alerts |

All RPCs: SECURITY DEFINER, admin-only, region-scoped via `admin_region_assignments`.

### 5.2 Flutter Architecture

```
lib/features/admin/
  domain/entities/
    admin_models.dart          (extended with new models)
    platform_kpi.dart          (new: PlatformKpi, FinancialSummary, etc.)
  domain/repositories/
    admin_repository.dart      (extended with new methods)
  data/datasources/
    supabase_admin_data_source.dart  (new: dedicated admin data source)
  data/repositories/
    supabase_admin_repository_impl.dart  (new: clean impl)
  presentation/
    pages/
      admin_dashboard_page.dart  (rewritten: full KPI dashboard)
      admin_financial_center.dart (new: financial center)
      admin_delivery_intelligence.dart (new)
      admin_provider_intelligence.dart (new)
      admin_merchant_intelligence.dart (new)
      admin_wallet_intelligence.dart (new)
      admin_settlements_page.dart (new)
    providers/
      admin_providers.dart       (rewritten: new providers)
```

---

## 6. Security Matrix

| Role | Dashboard | Financial | Regional | Member | Alerts |
|------|-----------|-----------|----------|--------|--------|
| ANON | ❌ | ❌ | ❌ | ❌ | ❌ |
| CUSTOMER | ❌ | ❌ | ❌ | ❌ | ❌ |
| PROVIDER | ❌ | ❌ | ❌ | ❌ | ❌ |
| DRIVER | ❌ | ❌ | ❌ | ❌ | ❌ |
| MERCHANT | ❌ | ❌ | ❌ | ❌ | ❌ |
| REGIONAL ADMIN | ✅ (scoped) | ✅ (scoped) | ✅ (own region) | ✅ (scoped) | ✅ (scoped) |
| GLOBAL ADMIN | ✅ | ✅ | ✅ | ✅ | ✅ |
| OWNER | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## 7. Limitations & Gaps

1. **No real financial data**: All financial tables are empty. Dashboard will show zeros until real transactions occur.
2. **No payment gateway integration**: `payment_transactions` table exists but no real gateway is wired.
3. **No settlement engine**: `withdrawal_requests` exist but no payout processing.
4. **No real-time operational data**: No active rides, orders, or deliveries.
5. **Admin hierarchy is empty**: No admin_users in the database (owner is in users table with role='owner').
6. **No region assignments**: `admin_region_assignments` is empty — regional filtering will be global-only until admins are assigned regions.

These are all documented as known limitations. No fabricated data.
