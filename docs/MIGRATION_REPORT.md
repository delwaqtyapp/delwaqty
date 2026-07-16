# MIGRATION_REPORT.md — Mock to Real Migration Tracking

> **Last updated:** 2026-07-16

---

## Migration Status

| Domain | Mock → Real | Commit | Date |
|--------|-------------|--------|------|
| Auth (Supabase GoTrue) | ✅ Complete | `bd9672a` | 2026-07-16 |
| Profile (Supabase Realtime) | ✅ Complete | `f4d20c6` | 2026-07-16 |
| User (Supabase deleteUser) | ✅ Complete | `f4d20c6` | 2026-07-16 |
| Location (geolocator) | ✅ Complete | `4af3c1b` | 2026-07-16 |
| Analytics (Firebase) | ✅ Complete | `4af3c1b` | 2026-07-16 |
| Notifications (FCM) | ✅ Complete | `4af3c1b` | 2026-07-16 |
| Crash Reporting (Crashlytics) | ✅ Complete | `4af3c1b` | 2026-07-16 |
| Performance (Firebase) | ✅ Complete | `4af3c1b` | 2026-07-16 |
| Storage (SharedPreferences) | ✅ Complete | `e82d641` | 2026-07-16 |
| Merchant (Supabase) | ✅ Complete | `0ebc61b` | 2026-07-16 |
| CatalogCategory (Supabase) | ✅ Complete | `0ebc61b` | 2026-07-16 |
| Product (Supabase) | ✅ Complete | `159227f` | 2026-07-16 |
| Favorite (Supabase) | ✅ Complete | `159227f` | 2026-07-16 |
| Cart (SharedPreferences) | ✅ Complete | `479e2b4` | 2026-07-16 |
| Order (Supabase) | ✅ Complete | `479e2b4` | 2026-07-16 |
| Reviews (Supabase) | ⏳ Pending | — | — |
| Coupons (Supabase) | ⏳ Pending | — | — |

## Files Created

| File | Purpose |
|------|---------|
| `lib/data/datasources/remote/supabase_auth_data_source.dart` | Auth data source |
| `lib/data/datasources/remote/supabase_profile_data_source.dart` | Profile data source (Realtime) |
| `lib/data/datasources/remote/supabase_merchant_data_source.dart` | Merchant data source |
| `lib/data/datasources/remote/supabase_catalog_category_data_source.dart` | Catalog category data source |
| `lib/data/datasources/remote/supabase_product_data_source.dart` | Product data source |
| `lib/data/datasources/remote/supabase_favorite_data_source.dart` | Favorite data source |
| `lib/data/datasources/remote/supabase_order_data_source.dart` | Order data source |
| `lib/data/repositories/auth_repository_impl.dart` | Auth repository (real) |
| `lib/data/repositories/profile_repository_impl.dart` | Profile repository (real-time) |
| `lib/data/repositories/user_repository_impl.dart` | User repository (real deleteUser) |
| `lib/data/repositories/merchant_repository_impl.dart` | Merchant repository (real) |
| `lib/data/repositories/catalog_category_repository_impl.dart` | Catalog category repository (real) |
| `lib/data/repositories/product_repository_impl.dart` | Product repository (real) |
| `lib/data/repositories/favorite_repository_impl.dart` | Favorite repository (real) |
| `lib/data/repositories/order_repository_impl.dart` | Order repository (real) |
| `lib/data/repositories/local_cart_repository.dart` | Cart repository (SharedPreferences) |

## DB Migrations Deployed

| Migration | Tables | Policies | Status |
|-----------|--------|----------|--------|
| `001_initial_schema.sql` | 14 tables | 29 RLS | ✅ Deployed |
| `002_favorites_merchant_support.sql` | +1 column | Updated | ✅ Deployed |

## Remaining Mocks (Intentional)

| Mock | Reason |
|------|--------|
| `MockReviewRepository` | Reviews table exists but not yet wired |
| `MockCouponRepository` | Coupons table exists but not yet wired |

## Test Impact

| Metric | Before | After |
|--------|--------|-------|
| Tests passing | 443 | 443 |
| Test failures | 0 | 0 |
| Analyze errors | 0 | 0 |
