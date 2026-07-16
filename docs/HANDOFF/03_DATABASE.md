# Delwaqty - Database Report

**Generated:** 2026-07-16
**Engine:** PostgreSQL 14.5 (Supabase)
**Schema Location:** `supabase/migrations/001_initial_schema.sql`

---

## Tables (15)

| # | Table | Description | RLS |
|---|-------|-------------|-----|
| 1 | `users` | End users | ✅ 3 policies |
| 2 | `admin_users` | Admin staff | ✅ 4 policies |
| 3 | `merchants` | Business sellers | ✅ 2 policies |
| 4 | `products` | Product listings | ✅ 2 policies |
| 5 | `categories` | Product categories | ✅ 1 policy |
| 6 | `orders` | Customer orders | ✅ 3 policies |
| 7 | `order_items` | Line items per order | ✅ 1 policy |
| 8 | `reviews` | Merchant/product reviews | ✅ 2 policies |
| 9 | `favorites` | User favorites | ✅ 2 policies |
| 10 | `drivers` | Delivery drivers | ✅ 2 policies |
| 11 | `coupons` | Discount codes | ✅ 1 policy |
| 12 | `notifications` | User notifications | ✅ 2 policies |
| 13 | `activity_logs` | Audit trail | ✅ 2 policies |
| 14 | `platform_settings` | Global config | ✅ 2 policies |
| 15 | *(total)* | **14 tables** | **25+ policies** |

## Indexes (16)

```
idx_orders_user_id          idx_orders_merchant_id
idx_orders_status           idx_orders_created_at
idx_products_merchant_id    idx_products_category
idx_merchants_status        idx_merchants_type
idx_reviews_merchant_id     idx_reviews_product_id
idx_favorites_user_id       idx_notifications_user_id
idx_notifications_is_read   idx_activity_logs_timestamp
idx_coupons_code            idx_drivers_is_active
```

## Default Data

### Categories (8)
| Name | Arabic | Icon | Sort |
|------|--------|------|------|
| Food | طعام | restaurant | 1 |
| Grocery | بقالة | shopping_basket | 2 |
| Pharmacy | صيدلية | local_pharmacy | 3 |
| Electronics | إلكترونيات | devices | 4 |
| Furniture | أثاث | chair | 5 |
| Fashion | أزياء | checkroom | 6 |
| Flowers | زهور | local_florist | 7 |
| Bakery | مخبوزات | bakery_dining | 8 |

### Platform Settings (1 row)
- App name: "Delwaqty"
- Support email: support@delwaqty.com
- Maintenance mode: false

## Key Relationships

```
users ──< orders (user_id)
merchants ──< orders (merchant_id)
merchants ──< products (merchant_id)
orders ──< order_items (order_id)
products ──< order_items (product_id)
users ──< reviews (user_id)
users ──< favorites (user_id)
users ──< notifications (user_id)
users ──< drivers (user_id)
merchants ──< coupons (merchant_id)
```

## Setup Status

- [ ] Tables created in Supabase Dashboard
- [ ] RLS policies verified
- [ ] Default data inserted
- [ ] REST API tested with real data
- [ ] Admin repository connected
