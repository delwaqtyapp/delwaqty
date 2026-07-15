# Sprint 8: Generic Commerce Engine

**Status:** Complete
**Tests:** 259 → 443 (+184 new)
**Lint:** 0 errors, 0 warnings

---

## Summary

Built a **generic, merchant-type-agnostic Commerce Engine** that powers Food, Grocery, Pharmacy, Electronics, Furniture, Fashion, Flowers, Bakery, and any future merchant type — all through a single domain model.

Every screen, widget, and repository is **type-agnostic**. MerchantType is a data flag, not a code branch.

---

## Domain Models (15 Freezed entities)

| Entity | Purpose |
|---|---|
| `Merchant` | Any vendor (restaurant, pharmacy, store, etc.) with type, location, rating, capabilities |
| `Product` | Any sellable item with variants |
| `ProductVariant` | Size/color options for products |
| `CatalogCategory` | Merchant-specific menu/product categories |
| `Cart` / `CartItem` | Active shopping cart with coupon support |
| `Order` / `OrderItem` | Order history with status tracking |
| `Review` | Merchant ratings and comments |
| `Coupon` | Percentage, fixed, or free delivery discounts |
| `Favorite` | User favorites for merchants/products |
| `SearchFilter` | Sort/filter by price, rating, distance, delivery time |
| `Money` | Currency-aware money value |
| `GeoLocation` | Lat/lng with address |
| `ImageSet` | Thumbnail/medium/large image variants |
| `MerchantType` | enum: restaurant, grocery, pharmacy, flowers, bakery, electronics, furniture, fashion, home, other |

---

## Repository Interfaces (8)

| Repository | Methods |
|---|---|
| `MerchantRepository` | getMerchants, getMerchantById, getFeaturedMerchants, searchMerchants, getMerchantsByType |
| `ProductRepository` | getProducts, getProductById, getFeaturedProducts, searchProducts |
| `CatalogCategoryRepository` | getCategories, getCategoryById |
| `CartRepository` | getCurrentCart, addToCart, updateCartItem, removeFromCart, clearCart, applyCoupon, removeCoupon |
| `OrderRepository` | getOrders, getOrderById, createOrder, cancelOrder |
| `ReviewRepository` | getMerchantReviews, getReviewById, submitReview |
| `CouponRepository` | getAvailableCoupons, getCouponByCode, validateCoupon |
| `FavoriteRepository` | getFavorites, isFavorite, toggleFavorite |

---

## Mock Implementations (8)

Full mock implementations with sample data for 5 merchants (Al Baik, Tamimi Markets, Nahdi Pharmacy, Jarir Bookstore, IKEA) and 8 products.

---

## Presentation Widgets (7 generic, reusable)

| Widget | Purpose |
|---|---|
| `MerchantCard` | Displays merchant info, rating, type, delivery ETA, open/verified badges |
| `ProductCard` | Displays product name, price, discount badge, availability |
| `CartBadge` | Shopping cart icon with item count badge |
| `RatingStars` | Visual star rating display |
| `PriceTag` | Price with optional strikethrough for discounts |
| `DeliveryInfo` | Delivery time, fee, minimum order display |
| `MerchantTypeChip` | Tappable chip for merchant type filtering |

---

## Presentation Screens (6)

| Screen | Route | Description |
|---|---|---|
| `CommerceDiscoveryPage` | `/market` | Search bar, type filters, featured merchants, merchant grid |
| `MerchantDetailPage` | `/market/merchant/:id` | Merchant info, rating, delivery info, category tabs, product grid |
| `ProductDetailPage` | `/market/merchant/:id/product/:productId` | Product info, variant selector, quantity picker, add to cart |
| `CartPage` | `/market/cart` | Cart items, quantity controls, subtotal/delivery/discount/total, checkout button |
| `CheckoutPage` | `/market/checkout` | Address, payment method, coupon, place order |
| `OrdersPage` | `/market/orders` | Order history with status chips |

---

## Module System Updates

### New ModuleCapability flags (FeatureModule)

```dart
enum ModuleCapability {
  searchable,
  hasNotifications,
  hasLocation,
  hasPayments,
  hasAI,
  hasOfflineMode,
  hasDeepLinks,
  requiresMap,        // NEW
  requiresPayments,   // NEW
  requiresDelivery,   // NEW
  requiresChat,       // NEW
  requiresWallet,     // NEW
}
```

### CommerceModule registered
- Route: `/market` (standalone, not in shell)
- Capabilities: `hasDeepLinks`
- All 8 repositories as top-level providers

---

## Infrastructure Prepared

### Deep Link Support
- CommerceModule declares `hasDeepLinks` capability
- All commerce routes are standalone (not shell-wrapped), ready for deep link integration
- Route pattern: `/market/merchant/:id/product/:productId`

### Search Infrastructure
- `SearchFilter` entity with price, rating, distance, delivery time, tags, sort options
- MerchantRepository.searchMerchants() and ProductRepository.searchProducts() interfaces
- Mock implementations with text-based filtering

### Global Notification Infrastructure
- `hasNotifications` capability flag available for modules
- NotificationRepository already exists from Sprint 5
- CommerceModule ready to declare notification support when backend is connected

---

## Key Design Decisions

1. **Zero merchant-type branching** — All screens display the same UI for restaurants, pharmacies, electronics stores, etc. The `MerchantType` enum drives icons/labels only.

2. **Single cart for entire platform** — CartRepository is platform-wide. Switching merchants clears the cart (real-world behavior).

3. **Coupon system is generic** — Percentage, fixed amount, or free delivery coupons. Not tied to any merchant type.

4. **Orders track status lifecycle** — pending → confirmed → preparing → ready → in_transit → delivered (or cancelled).

5. **Provider pattern** — Each repository is a top-level `Provider`. Module-specific providers (cart state, order history) are in the module file.

6. **Explicit JSON serialization** — `build.yaml` configured with `explicit_to_json: true` for proper nested entity serialization.

---

## Files Created

```
lib/features/commerce/
├── commerce_module.dart
├── domain/
│   ├── entities/
│   │   ├── money.dart (+.freezed.dart, .g.dart)
│   │   ├── geo_location.dart (+.freezed.dart, .g.dart)
│   │   ├── image_set.dart (+.freezed.dart, .g.dart)
│   │   ├── merchant.dart (+.freezed.dart, .g.dart)
│   │   ├── product.dart (+.freezed.dart, .g.dart)
│   │   ├── catalog_category.dart (+.freezed.dart, .g.dart)
│   │   ├── cart.dart (+.freezed.dart, .g.dart)
│   │   ├── order.dart (+.freezed.dart, .g.dart)
│   │   ├── review.dart (+.freezed.dart, .g.dart)
│   │   ├── coupon.dart (+.freezed.dart, .g.dart)
│   │   ├── favorite.dart (+.freezed.dart, .g.dart)
│   │   └── search_filter.dart (+.freezed.dart, .g.dart)
│   └── repositories/
│       ├── merchant_repository.dart
│       ├── product_repository.dart
│       ├── catalog_category_repository.dart
│       ├── cart_repository.dart
│       ├── order_repository.dart
│       ├── review_repository.dart
│       ├── coupon_repository.dart
│       └── favorite_repository.dart
├── data/repositories/mock/
│   ├── mock_merchant_repository.dart
│   ├── mock_product_repository.dart
│   ├── mock_catalog_category_repository.dart
│   ├── mock_cart_repository.dart
│   ├── mock_order_repository.dart
│   ├── mock_review_repository.dart
│   ├── mock_coupon_repository.dart
│   └── mock_favorite_repository.dart
└── presentation/
    ├── pages/
    │   ├── commerce_discovery_page.dart
    │   ├── merchant_detail_page.dart
    │   ├── product_detail_page.dart
    │   ├── cart_page.dart
    │   ├── checkout_page.dart
    │   └── orders_page.dart
    └── widgets/
        ├── merchant_card.dart
        ├── product_card.dart
        ├── cart_badge.dart
        ├── rating_stars.dart
        ├── price_tag.dart
        ├── delivery_info.dart
        └── merchant_type_chip.dart

test/features/commerce/
├── commerce_module_test.dart
├── domain/
│   ├── entities_test.dart
│   └── repositories_test.dart
└── presentation/
    └── widgets_test.dart
```

Modified:
- `lib/core/module/feature_module.dart` — added 5 new capabilities
- `lib/module_registry.dart` — registered CommerceModule
- `build.yaml` — explicit_to_json config for freezed

---

## Test Results

| Metric | Before | After |
|---|---|---|
| Tests | 259 | 443 |
| New tests | — | 184 |
| Errors | 0 | 0 |
| Lint issues | 0 | 0 (info only) |
