import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/commerce/data/repositories/mock/mock_merchant_repository.dart';
import 'package:delwaqty/features/commerce/data/repositories/mock/mock_product_repository.dart';
import 'package:delwaqty/features/commerce/data/repositories/mock/mock_catalog_category_repository.dart';
import 'package:delwaqty/features/commerce/data/repositories/mock/mock_cart_repository.dart';
import 'package:delwaqty/features/commerce/data/repositories/mock/mock_order_repository.dart';
import 'package:delwaqty/features/commerce/data/repositories/mock/mock_review_repository.dart';
import 'package:delwaqty/features/commerce/data/repositories/mock/mock_coupon_repository.dart';
import 'package:delwaqty/features/commerce/data/repositories/mock/mock_favorite_repository.dart';
import 'package:delwaqty/features/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/commerce/domain/entities/cart.dart';
import 'package:delwaqty/features/commerce/domain/entities/order.dart';
import 'package:delwaqty/features/commerce/domain/entities/favorite.dart';
import 'package:delwaqty/features/commerce/domain/entities/search_filter.dart';

void main() {
  group('MockMerchantRepository', () {
    late MockMerchantRepository repo;

    setUp(() {
      repo = MockMerchantRepository();
    });

    test('getMerchants returns all merchants', () async {
      final merchants = await repo.getMerchants();
      expect(merchants, isNotEmpty);
      expect(merchants.length, 5);
    });

    test('getMerchants filters by type', () async {
      final merchants = await repo.getMerchants(type: MerchantType.restaurant);
      for (final m in merchants) {
        expect(m.type, MerchantType.restaurant);
      }
    });

    test('getMerchants filters by city', () async {
      final merchants = await repo.getMerchants(city: 'Riyadh');
      expect(merchants, isNotEmpty);
      for (final m in merchants) {
        expect(m.city, 'Riyadh');
      }
    });

    test('getMerchants filters by isOpenNow', () async {
      final open = await repo.getMerchants(isOpenNow: true);
      for (final m in open) {
        expect(m.isOpenNow, true);
      }
    });

    test('getMerchants filters by minRating', () async {
      final filtered = await repo.getMerchants(
        filter: SearchFilter(minRating: 4.3),
      );
      for (final m in filtered) {
        expect(m.rating, greaterThanOrEqualTo(4.3));
      }
    });

    test('getMerchants respects limit', () async {
      final merchants = await repo.getMerchants(limit: 2);
      expect(merchants.length, lessThanOrEqualTo(2));
    });

    test('getMerchants respects offset', () async {
      final all = await repo.getMerchants();
      final offset = await repo.getMerchants(offset: 3);
      expect(offset.length, all.length - 3);
    });

    test('getMerchantById returns merchant by id', () async {
      final merchant = await repo.getMerchantById('m1');
      expect(merchant, isNotNull);
      expect(merchant!.id, 'm1');
    });

    test('getMerchantById returns null for unknown id', () async {
      final merchant = await repo.getMerchantById('unknown');
      expect(merchant, isNull);
    });

    test('getFeaturedMerchants returns featured merchants', () async {
      final featured = await repo.getFeaturedMerchants();
      expect(featured, isNotEmpty);
      for (final m in featured) {
        expect(m.isFeatured, true);
      }
    });

    test('searchMerchants finds by name', () async {
      final results = await repo.searchMerchants('Baik');
      expect(results, isNotEmpty);
      expect(results.first.name, 'Al Baik');
    });

    test('searchMerchants finds by tag', () async {
      final results = await repo.searchMerchants('chicken');
      expect(results, isNotEmpty);
    });

    test('searchMerchants returns empty for no match', () async {
      final results = await repo.searchMerchants('xyznotfound');
      expect(results, isEmpty);
    });

    test('getMerchantsByType returns matching merchants', () async {
      final pharmacies = await repo.getMerchantsByType(MerchantType.pharmacy);
      expect(pharmacies.length, 1);
      expect(pharmacies.first.type, MerchantType.pharmacy);
    });
  });

  group('MockProductRepository', () {
    late MockProductRepository repo;

    setUp(() {
      repo = MockProductRepository();
    });

    test('getProducts returns products for merchant', () async {
      final products = await repo.getProducts(merchantId: 'm1');
      expect(products, isNotEmpty);
      for (final p in products) {
        expect(p.merchantId, 'm1');
      }
    });

    test('getProducts filters by categoryId', () async {
      final products = await repo.getProducts(
        merchantId: 'm1',
        categoryId: 'c1',
      );
      expect(products, isNotEmpty);
      for (final p in products) {
        expect(p.categoryId, 'c1');
      }
    });

    test('getProducts filters by isAvailable', () async {
      final products = await repo.getProducts(
        merchantId: 'm1',
        isAvailable: true,
      );
      for (final p in products) {
        expect(p.isAvailable, true);
      }
    });

    test('getProducts respects limit', () async {
      final products = await repo.getProducts(merchantId: 'm1', limit: 1);
      expect(products.length, lessThanOrEqualTo(1));
    });

    test('getProductById returns product', () async {
      final product = await repo.getProductById('p1');
      expect(product, isNotNull);
      expect(product!.id, 'p1');
    });

    test('getProductById returns null for unknown id', () async {
      final product = await repo.getProductById('unknown');
      expect(product, isNull);
    });

    test('getFeaturedProducts returns featured products', () async {
      final featured = await repo.getFeaturedProducts('m1');
      expect(featured, isNotEmpty);
      for (final p in featured) {
        expect(p.isFeatured, true);
        expect(p.merchantId, 'm1');
      }
    });

    test('searchProducts finds by name', () async {
      final results = await repo.searchProducts('Chicken');
      expect(results, isNotEmpty);
    });

    test('searchProducts finds by tag', () async {
      final results = await repo.searchProducts('chicken');
      expect(results, isNotEmpty);
    });

    test('searchProducts filters by merchantId', () async {
      final results = await repo.searchProducts('milk', merchantId: 'm2');
      expect(results, isNotEmpty);
      for (final p in results) {
        expect(p.merchantId, 'm2');
      }
    });

    test('searchProducts returns empty for no match', () async {
      final results = await repo.searchProducts('xyznotfound');
      expect(results, isEmpty);
    });
  });

  group('MockCatalogCategoryRepository', () {
    late MockCatalogCategoryRepository repo;

    setUp(() {
      repo = MockCatalogCategoryRepository();
    });

    test('getCategories returns categories for merchant', () async {
      final categories = await repo.getCategories('m1');
      expect(categories, isNotEmpty);
      expect(categories.length, 2);
      for (final c in categories) {
        expect(c.merchantId, 'm1');
      }
    });

    test('getCategories returns empty for unknown merchant', () async {
      final categories = await repo.getCategories('unknown');
      expect(categories, isEmpty);
    });

    test('getCategoryById returns category', () async {
      final category = await repo.getCategoryById('c1');
      expect(category, isNotNull);
      expect(category!.id, 'c1');
    });

    test('getCategoryById returns null for unknown id', () async {
      final category = await repo.getCategoryById('unknown');
      expect(category, isNull);
    });
  });

  group('MockCartRepository', () {
    late MockCartRepository repo;

    setUp(() {
      repo = MockCartRepository();
    });

    test('getCurrentCart returns null initially', () async {
      final cart = await repo.getCurrentCart();
      expect(cart, isNull);
    });

    test('addToCart creates new cart', () async {
      final cart = await repo.addToCart(
        merchantId: 'm1',
        merchantName: 'Al Baik',
        item: CartItem(
          id: 'ci1',
          productId: 'p1',
          productName: 'Chicken Meal',
          quantity: 2,
          unitPrice: 35.0,
        ),
      );

      expect(cart.merchantId, 'm1');
      expect(cart.items.length, 1);
      expect(cart.subtotal, 70.0);
      expect(cart.total, 70.0);
    });

    test('addToCart adds to existing cart', () async {
      await repo.addToCart(
        merchantId: 'm1',
        merchantName: 'Al Baik',
        item: CartItem(
          id: 'ci1',
          productId: 'p1',
          productName: 'Meal',
          quantity: 1,
          unitPrice: 35.0,
        ),
      );

      final cart = await repo.addToCart(
        merchantId: 'm1',
        merchantName: 'Al Baik',
        item: CartItem(
          id: 'ci2',
          productId: 'p2',
          productName: 'Sandwich',
          quantity: 1,
          unitPrice: 20.0,
        ),
      );

      expect(cart.items.length, 2);
      expect(cart.subtotal, 55.0);
    });

    test('addToCart merges same product', () async {
      await repo.addToCart(
        merchantId: 'm1',
        merchantName: 'Al Baik',
        item: CartItem(
          id: 'ci1',
          productId: 'p1',
          productName: 'Meal',
          quantity: 1,
          unitPrice: 35.0,
        ),
      );

      final cart = await repo.addToCart(
        merchantId: 'm1',
        merchantName: 'Al Baik',
        item: CartItem(
          id: 'ci2',
          productId: 'p1',
          productName: 'Meal',
          quantity: 2,
          unitPrice: 35.0,
        ),
      );

      expect(cart.items.length, 1);
      expect(cart.items.first.quantity, 3);
      expect(cart.subtotal, 105.0);
    });

    test('addToCart replaces cart for different merchant', () async {
      await repo.addToCart(
        merchantId: 'm1',
        merchantName: 'Al Baik',
        item: CartItem(
          id: 'ci1',
          productId: 'p1',
          productName: 'Meal',
          quantity: 1,
          unitPrice: 35.0,
        ),
      );

      final cart = await repo.addToCart(
        merchantId: 'm2',
        merchantName: 'Tamimi',
        item: CartItem(
          id: 'ci2',
          productId: 'p4',
          productName: 'Milk',
          quantity: 1,
          unitPrice: 12.5,
        ),
      );

      expect(cart.merchantId, 'm2');
      expect(cart.items.length, 1);
      expect(cart.subtotal, 12.5);
    });

    test('updateCartItem updates quantity', () async {
      await repo.addToCart(
        merchantId: 'm1',
        merchantName: 'Al Baik',
        item: CartItem(
          id: 'ci1',
          productId: 'p1',
          productName: 'Meal',
          quantity: 1,
          unitPrice: 35.0,
        ),
      );

      final cart = await repo.updateCartItem(
        cartItemId: 'ci1',
        quantity: 3,
      );

      expect(cart.items.first.quantity, 3);
      expect(cart.subtotal, 105.0);
    });

    test('updateCartItem removes item when quantity <= 0', () async {
      await repo.addToCart(
        merchantId: 'm1',
        merchantName: 'Al Baik',
        item: CartItem(
          id: 'ci1',
          productId: 'p1',
          productName: 'Meal',
          quantity: 1,
          unitPrice: 35.0,
        ),
      );

      final cart = await repo.updateCartItem(
        cartItemId: 'ci1',
        quantity: 0,
      );

      expect(cart.id, 'empty');
      expect(cart.items, isEmpty);
    });

    test('removeFromCart removes item', () async {
      await repo.addToCart(
        merchantId: 'm1',
        merchantName: 'Al Baik',
        item: CartItem(
          id: 'ci1',
          productId: 'p1',
          productName: 'Meal',
          quantity: 1,
          unitPrice: 35.0,
        ),
      );

      final cart = await repo.removeFromCart(cartItemId: 'ci1');
      expect(cart.id, 'empty');
    });

    test('clearCart empties the cart', () async {
      await repo.addToCart(
        merchantId: 'm1',
        merchantName: 'Al Baik',
        item: CartItem(
          id: 'ci1',
          productId: 'p1',
          productName: 'Meal',
          quantity: 1,
          unitPrice: 35.0,
        ),
      );

      final cart = await repo.clearCart();
      expect(cart.id, 'empty');
      expect(cart.items, isEmpty);

      final current = await repo.getCurrentCart();
      expect(current, isNull);
    });

    test('applyCoupon applies SAVE10 discount', () async {
      await repo.addToCart(
        merchantId: 'm1',
        merchantName: 'Al Baik',
        item: CartItem(
          id: 'ci1',
          productId: 'p1',
          productName: 'Meal',
          quantity: 1,
          unitPrice: 100.0,
        ),
      );

      final cart = await repo.applyCoupon('SAVE10');
      expect(cart.couponCode, 'SAVE10');
      expect(cart.discount, 10.0);
    });

    test('removeCoupon removes discount', () async {
      await repo.addToCart(
        merchantId: 'm1',
        merchantName: 'Al Baik',
        item: CartItem(
          id: 'ci1',
          productId: 'p1',
          productName: 'Meal',
          quantity: 1,
          unitPrice: 100.0,
        ),
      );

      await repo.applyCoupon('SAVE10');
      final cart = await repo.removeCoupon();
      expect(cart.couponCode, isNull);
      expect(cart.discount, 0);
    });
  });

  group('MockOrderRepository', () {
    late MockOrderRepository repo;

    setUp(() {
      repo = MockOrderRepository();
    });

    test('getOrders returns empty initially', () async {
      final orders = await repo.getOrders();
      expect(orders, isEmpty);
    });

    test('createOrder creates and returns order', () async {
      final order = await repo.createOrder(
        merchantId: 'm1',
        items: [
          CartItem(
            id: 'ci1',
            productId: 'p1',
            productName: 'Meal',
            quantity: 2,
            unitPrice: 35.0,
          ),
        ],
        subtotal: 70.0,
        deliveryFee: 10.0,
        discount: 0.0,
        total: 80.0,
      );

      expect(order.id, isNotEmpty);
      expect(order.status, OrderStatus.pending);
      expect(order.items.length, 1);
      expect(order.total, 80.0);
    });

    test('createOrder adds to orders list', () async {
      await repo.createOrder(
        merchantId: 'm1',
        items: [
          CartItem(
            id: 'ci1',
            productId: 'p1',
            productName: 'Meal',
            quantity: 1,
            unitPrice: 35.0,
          ),
        ],
        subtotal: 35.0,
        deliveryFee: 10.0,
        discount: 0.0,
        total: 45.0,
      );

      final orders = await repo.getOrders();
      expect(orders.length, 1);
    });

    test('getOrderById returns order', () async {
      final created = await repo.createOrder(
        merchantId: 'm1',
        items: [],
        subtotal: 0.0,
        deliveryFee: 0.0,
        discount: 0.0,
        total: 0.0,
      );

      final order = await repo.getOrderById(created.id);
      expect(order, isNotNull);
      expect(order!.id, created.id);
    });

    test('getOrderById returns null for unknown id', () async {
      final order = await repo.getOrderById('unknown');
      expect(order, isNull);
    });

    test('getOrders filters by status', () async {
      await repo.createOrder(
        merchantId: 'm1',
        items: [],
        subtotal: 0.0,
        deliveryFee: 0.0,
        discount: 0.0,
        total: 0.0,
      );

      final pending = await repo.getOrders(status: OrderStatus.pending);
      expect(pending, isNotEmpty);
      for (final o in pending) {
        expect(o.status, OrderStatus.pending);
      }
    });

    test('getOrders respects limit', () async {
      await repo.createOrder(
        merchantId: 'm1',
        items: [],
        subtotal: 0.0,
        deliveryFee: 0.0,
        discount: 0.0,
        total: 0.0,
      );
      await repo.createOrder(
        merchantId: 'm1',
        items: [],
        subtotal: 0.0,
        deliveryFee: 0.0,
        discount: 0.0,
        total: 0.0,
      );

      final orders = await repo.getOrders(limit: 1);
      expect(orders.length, 1);
    });

    test('cancelOrder cancels the order', () async {
      final created = await repo.createOrder(
        merchantId: 'm1',
        items: [],
        subtotal: 0.0,
        deliveryFee: 0.0,
        discount: 0.0,
        total: 0.0,
      );

      final cancelled = await repo.cancelOrder(
        orderId: created.id,
        reason: 'Changed mind',
      );

      expect(cancelled.status, OrderStatus.cancelled);
      expect(cancelled.cancellationReason, 'Changed mind');
      expect(cancelled.cancelledAt, isNotNull);
    });

    test('cancelOrder throws for unknown id', () async {
      expect(
        () => repo.cancelOrder(orderId: 'unknown'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('MockReviewRepository', () {
    late MockReviewRepository repo;

    setUp(() {
      repo = MockReviewRepository();
    });

    test('getMerchantReviews returns empty initially', () async {
      final reviews = await repo.getMerchantReviews('m1');
      expect(reviews, isEmpty);
    });

    test('submitReview creates and returns review', () async {
      final review = await repo.submitReview(
        merchantId: 'm1',
        rating: 4.5,
        comment: 'Great!',
      );

      expect(review.id, isNotEmpty);
      expect(review.merchantId, 'm1');
      expect(review.rating, 4.5);
      expect(review.comment, 'Great!');
      expect(review.userId, 'user_1');
      expect(review.userName, 'Current User');
    });

    test('getMerchantReviews returns reviews for merchant', () async {
      await repo.submitReview(merchantId: 'm1', rating: 5.0);
      await repo.submitReview(merchantId: 'm1', rating: 4.0);
      await repo.submitReview(merchantId: 'm2', rating: 3.0);

      final reviews = await repo.getMerchantReviews('m1');
      expect(reviews.length, 2);
      for (final r in reviews) {
        expect(r.merchantId, 'm1');
      }
    });

    test('getReviewById returns review', () async {
      final submitted = await repo.submitReview(
        merchantId: 'm1',
        rating: 4.0,
      );

      final review = await repo.getReviewById(submitted.id);
      expect(review, isNotNull);
      expect(review!.id, submitted.id);
    });

    test('getReviewById returns null for unknown id', () async {
      final review = await repo.getReviewById('unknown');
      expect(review, isNull);
    });
  });

  group('MockCouponRepository', () {
    late MockCouponRepository repo;

    setUp(() {
      repo = MockCouponRepository();
    });

    test('getAvailableCoupons returns active coupons', () async {
      final coupons = await repo.getAvailableCoupons();
      expect(coupons, isNotEmpty);
      for (final c in coupons) {
        expect(c.isActive, true);
      }
    });

    test('getCouponByCode returns coupon', () async {
      final coupon = await repo.getCouponByCode('SAVE10');
      expect(coupon, isNotNull);
      expect(coupon!.code, 'SAVE10');
    });

    test('getCouponByCode is case insensitive', () async {
      final coupon = await repo.getCouponByCode('save10');
      expect(coupon, isNotNull);
      expect(coupon!.code, 'SAVE10');
    });

    test('getCouponByCode returns null for unknown code', () async {
      final coupon = await repo.getCouponByCode('UNKNOWN');
      expect(coupon, isNull);
    });

    test('validateCoupon returns coupon when valid', () async {
      final coupon = await repo.validateCoupon('SAVE10', 50.0);
      expect(coupon, isNotNull);
      expect(coupon!.code, 'SAVE10');
    });

    test('validateCoupon returns null when below minimum order', () async {
      final coupon = await repo.validateCoupon('SAVE10', 10.0);
      expect(coupon, isNull);
    });

    test('validateCoupon returns null for unknown code', () async {
      final coupon = await repo.validateCoupon('UNKNOWN', 50.0);
      expect(coupon, isNull);
    });
  });

  group('MockFavoriteRepository', () {
    late MockFavoriteRepository repo;

    setUp(() {
      repo = MockFavoriteRepository();
    });

    test('getFavorites returns empty initially', () async {
      final favorites = await repo.getFavorites();
      expect(favorites, isEmpty);
    });

    test('toggleFavorite adds favorite', () async {
      await repo.toggleFavorite(
        targetId: 'm1',
        type: FavoriteType.merchant,
      );

      final favorites = await repo.getFavorites();
      expect(favorites.length, 1);
      expect(favorites.first.targetId, 'm1');
    });

    test('toggleFavorite removes existing favorite', () async {
      await repo.toggleFavorite(
        targetId: 'm1',
        type: FavoriteType.merchant,
      );
      await repo.toggleFavorite(
        targetId: 'm1',
        type: FavoriteType.merchant,
      );

      final favorites = await repo.getFavorites();
      expect(favorites, isEmpty);
    });

    test('isFavorite returns correct status', () async {
      expect(
        await repo.isFavorite('m1', FavoriteType.merchant),
        false,
      );

      await repo.toggleFavorite(
        targetId: 'm1',
        type: FavoriteType.merchant,
      );

      expect(
        await repo.isFavorite('m1', FavoriteType.merchant),
        true,
      );
    });

    test('getFavorites filters by type', () async {
      await repo.toggleFavorite(
        targetId: 'm1',
        type: FavoriteType.merchant,
      );
      await repo.toggleFavorite(
        targetId: 'p1',
        type: FavoriteType.product,
      );

      final merchants = await repo.getFavorites(type: FavoriteType.merchant);
      expect(merchants.length, 1);
      expect(merchants.first.type, FavoriteType.merchant);

      final products = await repo.getFavorites(type: FavoriteType.product);
      expect(products.length, 1);
      expect(products.first.type, FavoriteType.product);
    });
  });
}
