import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/customer/commerce/domain/repositories/merchant_repository.dart';
import 'package:delwaqty/features/customer/commerce/domain/repositories/product_repository.dart';
import 'package:delwaqty/features/customer/commerce/domain/repositories/catalog_category_repository.dart';
import 'package:delwaqty/features/customer/commerce/domain/repositories/cart_repository.dart';
import 'package:delwaqty/features/customer/commerce/domain/repositories/order_repository.dart';
import 'package:delwaqty/features/customer/commerce/domain/repositories/review_repository.dart';
import 'package:delwaqty/features/customer/commerce/domain/repositories/coupon_repository.dart';
import 'package:delwaqty/features/customer/commerce/domain/repositories/favorite_repository.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/product.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/catalog_category.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/cart.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/order.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/review.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/coupon.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/favorite.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/search_filter.dart';

class MockMerchantRepository extends Mock implements MerchantRepository {}
class MockProductRepository extends Mock implements ProductRepository {}
class MockCatalogCategoryRepository extends Mock implements CatalogCategoryRepository {}
class MockCartRepository extends Mock implements CartRepository {}
class MockOrderRepository extends Mock implements OrderRepository {}
class MockReviewRepository extends Mock implements ReviewRepository {}
class MockCouponRepository extends Mock implements CouponRepository {}
class MockFavoriteRepository extends Mock implements FavoriteRepository {}

final _testMerchants = [
  Merchant(
    id: 'm1', name: 'Al Baik', type: MerchantType.restaurant,
    latitude: 24.7, longitude: 46.7, city: 'Riyadh',
    rating: 4.5, isOpenNow: true, isFeatured: true,
    tags: ['chicken', 'fast food'], createdAt: DateTime(2024),
  ),
  Merchant(
    id: 'm2', name: 'Tamimi', type: MerchantType.grocery,
    latitude: 24.6, longitude: 46.7, city: 'Riyadh',
    rating: 4.0, isOpenNow: true, isFeatured: false,
    tags: ['groceries'], createdAt: DateTime(2024),
  ),
  Merchant(
    id: 'm3', name: 'Al Nahdi', type: MerchantType.pharmacy,
    latitude: 24.5, longitude: 46.7, city: 'Riyadh',
    rating: 4.8, isOpenNow: false, isFeatured: true,
    tags: ['pharmacy'], createdAt: DateTime(2024),
  ),
  Merchant(
    id: 'm4', name: 'Barn\'s Coffee', type: MerchantType.restaurant,
    latitude: 24.7, longitude: 46.7, city: 'Jeddah',
    rating: 4.2, isOpenNow: true, isFeatured: false,
    tags: ['coffee', 'drinks'], createdAt: DateTime(2024),
  ),
  Merchant(
    id: 'm5', name: 'Pizza Hut', type: MerchantType.restaurant,
    latitude: 24.8, longitude: 46.7, city: 'Riyadh',
    rating: 3.9, isOpenNow: false, isFeatured: false,
    tags: ['pizza'], createdAt: DateTime(2024),
  ),
];

final _testProducts = [
  Product(
    id: 'p1', merchantId: 'm1', categoryId: 'c1',
    name: 'Chicken Meal', price: 35.0, isAvailable: true, isFeatured: true,
    tags: ['chicken'], createdAt: DateTime(2024),
  ),
  Product(
    id: 'p2', merchantId: 'm1', categoryId: 'c1',
    name: 'Spicy Sandwich', price: 20.0, isAvailable: true,
    tags: ['sandwich'], createdAt: DateTime(2024),
  ),
  Product(
    id: 'p3', merchantId: 'm1', categoryId: 'c2',
    name: 'Cola', price: 5.0, isAvailable: true,
    tags: ['drink'], createdAt: DateTime(2024),
  ),
  Product(
    id: 'p4', merchantId: 'm2', categoryId: 'c3',
    name: 'Milk', price: 12.5, isAvailable: true,
    tags: ['dairy'], createdAt: DateTime(2024),
  ),
];

final _testCategories = [
  CatalogCategory(id: 'c1', merchantId: 'm1', name: 'Meals', sortOrder: 0),
  CatalogCategory(id: 'c2', merchantId: 'm1', name: 'Drinks', sortOrder: 1),
  CatalogCategory(id: 'c3', merchantId: 'm2', name: 'Dairy', sortOrder: 0),
];

final _testCoupons = [
  Coupon(id: 'cp1', code: 'SAVE10', type: CouponType.percentage, value: 10, minimumOrder: 50, isActive: true, createdAt: DateTime(2024)),
  Coupon(id: 'cp2', code: 'FLAT20', type: CouponType.fixed, value: 20, minimumOrder: 100, isActive: true, createdAt: DateTime(2024)),
];

void main() {
  setUpAll(() {
    registerFallbackValue(FavoriteType.merchant);
    registerFallbackValue(OrderStatus.pending);
    registerFallbackValue(MerchantType.restaurant);
    registerFallbackValue(const CartItem(id: '', productId: '', productName: '', quantity: 0, unitPrice: 0));
    registerFallbackValue(CouponType.percentage);
    registerFallbackValue(const SearchFilter());
  });

  group('MerchantRepository', () {
    late MockMerchantRepository repo;

    setUp(() {
      repo = MockMerchantRepository();
      when(() => repo.getMerchants(
        type: any(named: 'type'), city: any(named: 'city'),
        isOpenNow: any(named: 'isOpenNow'), filter: any(named: 'filter'),
        limit: any(named: 'limit'), offset: any(named: 'offset'),
      )).thenAnswer((_) async => _testMerchants);
      when(() => repo.getMerchants(
        type: any(named: 'type'), city: any(named: 'city'),
        isOpenNow: any(named: 'isOpenNow'), filter: any(named: 'filter'),
        limit: any(named: 'limit'), offset: any(named: 'offset'),
      )).thenAnswer((invocation) async {
        final type = invocation.namedArguments[#type] as MerchantType?;
        final city = invocation.namedArguments[#city] as String?;
        final isOpenNow = invocation.namedArguments[#isOpenNow] as bool?;
        final filter = invocation.namedArguments[#filter] as SearchFilter?;
        final limit = invocation.namedArguments[#limit] as int? ?? 20;
        final offset = invocation.namedArguments[#offset] as int? ?? 0;
        var results = List<Merchant>.from(_testMerchants);
        if (type != null) results = results.where((m) => m.type == type).toList();
        if (city != null) results = results.where((m) => m.city == city).toList();
        if (isOpenNow != null) results = results.where((m) => m.isOpenNow == isOpenNow).toList();
        if (filter?.minRating != null) results = results.where((m) => m.rating >= filter!.minRating!).toList();
        final sliced = results.skip(offset).take(limit).toList();
        return sliced;
      });
      when(() => repo.getMerchantById(any())).thenAnswer((invocation) async {
        final id = invocation.positionalArguments[0] as String;
        return _testMerchants.where((m) => m.id == id).firstOrNull;
      });
      when(() => repo.getFeaturedMerchants()).thenAnswer(
        (_) async => _testMerchants.where((m) => m.isFeatured).toList(),
      );
      when(() => repo.searchMerchants(any())).thenAnswer((invocation) async {
        final q = (invocation.positionalArguments[0] as String).toLowerCase();
        return _testMerchants.where((m) =>
          m.name.toLowerCase().contains(q) ||
          m.tags.any((t) => t.toLowerCase().contains(q))
        ).toList();
      });
      when(() => repo.getMerchantsByType(any())).thenAnswer((invocation) async {
        final type = invocation.positionalArguments[0] as MerchantType;
        return _testMerchants.where((m) => m.type == type).toList();
      });
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

  group('ProductRepository', () {
    late MockProductRepository repo;

    setUp(() {
      repo = MockProductRepository();
      when(() => repo.getProducts(
        merchantId: any(named: 'merchantId'),
        categoryId: any(named: 'categoryId'),
        isAvailable: any(named: 'isAvailable'),
        limit: any(named: 'limit'), offset: any(named: 'offset'),
      )).thenAnswer((invocation) async {
        final merchantId = invocation.namedArguments[#merchantId] as String;
        final categoryId = invocation.namedArguments[#categoryId] as String?;
        final isAvailable = invocation.namedArguments[#isAvailable] as bool?;
        final limit = invocation.namedArguments[#limit] as int? ?? 20;
        var results = _testProducts.where((p) => p.merchantId == merchantId).toList();
        if (categoryId != null) results = results.where((p) => p.categoryId == categoryId).toList();
        if (isAvailable != null) results = results.where((p) => p.isAvailable == isAvailable).toList();
        return results.take(limit).toList();
      });
      when(() => repo.getProductById(any())).thenAnswer((invocation) async {
        final id = invocation.positionalArguments[0] as String;
        return _testProducts.where((p) => p.id == id).firstOrNull;
      });
      when(() => repo.getFeaturedProducts(any())).thenAnswer((invocation) async {
        final merchantId = invocation.positionalArguments[0] as String;
        return _testProducts.where((p) => p.merchantId == merchantId && p.isFeatured).toList();
      });
      when(() => repo.searchProducts(any(), merchantId: any(named: 'merchantId'))).thenAnswer((invocation) async {
        final q = (invocation.positionalArguments[0] as String).toLowerCase();
        final merchantId = invocation.namedArguments[#merchantId] as String?;
        return _testProducts.where((p) {
          if (merchantId != null && p.merchantId != merchantId) return false;
          return p.name.toLowerCase().contains(q) || p.tags.any((t) => t.contains(q));
        }).toList();
      });
    });

    test('getProducts returns products for merchant', () async {
      final products = await repo.getProducts(merchantId: 'm1');
      expect(products, isNotEmpty);
      for (final p in products) {
        expect(p.merchantId, 'm1');
      }
    });

    test('getProducts filters by categoryId', () async {
      final products = await repo.getProducts(merchantId: 'm1', categoryId: 'c1');
      expect(products, isNotEmpty);
      for (final p in products) {
        expect(p.categoryId, 'c1');
      }
    });

    test('getProducts filters by isAvailable', () async {
      final products = await repo.getProducts(merchantId: 'm1', isAvailable: true);
      for (final p in products) {
        expect(p.isAvailable, true);
      }
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

  group('CatalogCategoryRepository', () {
    late MockCatalogCategoryRepository repo;

    setUp(() {
      repo = MockCatalogCategoryRepository();
      when(() => repo.getCategories(any())).thenAnswer((invocation) async {
        final merchantId = invocation.positionalArguments[0] as String;
        return _testCategories.where((c) => c.merchantId == merchantId).toList();
      });
      when(() => repo.getCategoryById(any())).thenAnswer((invocation) async {
        final id = invocation.positionalArguments[0] as String;
        return _testCategories.where((c) => c.id == id).firstOrNull;
      });
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

  group('CartRepository', () {
    late MockCartRepository repo;
    Cart? _currentCart;

    setUp(() {
      repo = MockCartRepository();
      _currentCart = null;

      when(() => repo.getCurrentCart()).thenAnswer((_) async => _currentCart);

      when(() => repo.addToCart(
        merchantId: any(named: 'merchantId'),
        merchantName: any(named: 'merchantName'),
        item: any(named: 'item'),
      )).thenAnswer((invocation) async {
        final merchantId = invocation.namedArguments[#merchantId] as String;
        final merchantName = invocation.namedArguments[#merchantName] as String;
        final item = invocation.namedArguments[#item] as CartItem;
        if (_currentCart == null || _currentCart!.merchantId != merchantId) {
          _currentCart = Cart(
            id: 'cart_1', merchantId: merchantId, merchantName: merchantName,
            items: [item], subtotal: item.unitPrice * item.quantity,
            total: item.unitPrice * item.quantity, updatedAt: DateTime.now(),
          );
        } else {
          final existing = _currentCart!.items.where((i) => i.productId == item.productId).toList();
          if (existing.isNotEmpty) {
            final merged = _currentCart!.items.map((i) =>
              i.productId == item.productId
                ? CartItem(id: i.id, productId: i.productId, productName: i.productName, quantity: i.quantity + item.quantity, unitPrice: i.unitPrice)
                : i
            ).toList();
            final sub = merged.fold<double>(0, (sum, i) => sum + i.unitPrice * i.quantity);
            _currentCart = _currentCart!.copyWith(items: merged, subtotal: sub, total: sub, updatedAt: DateTime.now());
          } else {
            final newItems = [..._currentCart!.items, item];
            final sub = newItems.fold<double>(0, (sum, i) => sum + i.unitPrice * i.quantity);
            _currentCart = _currentCart!.copyWith(items: newItems, subtotal: sub, total: sub, updatedAt: DateTime.now());
          }
        }
        return _currentCart!;
      });

      when(() => repo.updateCartItem(
        cartItemId: any(named: 'cartItemId'),
        quantity: any(named: 'quantity'),
      )).thenAnswer((invocation) async {
        final cartItemId = invocation.namedArguments[#cartItemId] as String;
        final quantity = invocation.namedArguments[#quantity] as int;
        if (quantity <= 0) {
          final newItems = _currentCart!.items.where((i) => i.id != cartItemId).toList();
          if (newItems.isEmpty) {
            _currentCart = Cart(
              id: 'empty', merchantId: '', merchantName: '',
              items: [], subtotal: 0, total: 0, updatedAt: DateTime.now(),
            );
          } else {
            final sub = newItems.fold<double>(0, (sum, i) => sum + i.unitPrice * i.quantity);
            _currentCart = _currentCart!.copyWith(items: newItems, subtotal: sub, total: sub, updatedAt: DateTime.now());
          }
        } else {
          final newItems = _currentCart!.items.map((i) =>
            i.id == cartItemId ? CartItem(id: i.id, productId: i.productId, productName: i.productName, quantity: quantity, unitPrice: i.unitPrice) : i
          ).toList();
          final sub = newItems.fold<double>(0, (sum, i) => sum + i.unitPrice * i.quantity);
          _currentCart = _currentCart!.copyWith(items: newItems, subtotal: sub, total: sub, updatedAt: DateTime.now());
        }
        return _currentCart!;
      });

      when(() => repo.removeFromCart(cartItemId: any(named: 'cartItemId'))).thenAnswer((invocation) async {
        _currentCart = Cart(
          id: 'empty', merchantId: '', merchantName: '',
          items: [], subtotal: 0, total: 0, updatedAt: DateTime.now(),
        );
        return _currentCart!;
      });

      when(() => repo.clearCart()).thenAnswer((_) async {
        final empty = Cart(
          id: 'empty', merchantId: '', merchantName: '',
          items: [], subtotal: 0, total: 0, updatedAt: DateTime.now(),
        );
        _currentCart = null;
        return empty;
      });

      when(() => repo.applyCoupon(any(), discount: any(named: 'discount'))).thenAnswer((invocation) async {
        final code = invocation.positionalArguments[0] as String;
        if (code == 'SAVE10') {
          final sub = _currentCart!.subtotal;
          _currentCart = _currentCart!.copyWith(
            couponCode: 'SAVE10', discount: sub * 0.1,
            total: sub - sub * 0.1, updatedAt: DateTime.now(),
          );
        }
        return _currentCart!;
      });

      when(() => repo.removeCoupon()).thenAnswer((_) async {
        final sub = _currentCart!.subtotal;
        _currentCart = _currentCart!.copyWith(
          couponCode: null, discount: 0,
          total: sub, updatedAt: DateTime.now(),
        );
        return _currentCart!;
      });
    });

    test('getCurrentCart returns null initially', () async {
      final cart = await repo.getCurrentCart();
      expect(cart, isNull);
    });

    test('addToCart creates new cart', () async {
      final cart = await repo.addToCart(
        merchantId: 'm1', merchantName: 'Al Baik',
        item: CartItem(id: 'ci1', productId: 'p1', productName: 'Chicken Meal', quantity: 2, unitPrice: 35.0),
      );
      expect(cart.merchantId, 'm1');
      expect(cart.items.length, 1);
      expect(cart.subtotal, 70.0);
      expect(cart.total, 70.0);
    });

    test('addToCart merges same product', () async {
      await repo.addToCart(
        merchantId: 'm1', merchantName: 'Al Baik',
        item: CartItem(id: 'ci1', productId: 'p1', productName: 'Meal', quantity: 1, unitPrice: 35.0),
      );
      final cart = await repo.addToCart(
        merchantId: 'm1', merchantName: 'Al Baik',
        item: CartItem(id: 'ci2', productId: 'p1', productName: 'Meal', quantity: 2, unitPrice: 35.0),
      );
      expect(cart.items.length, 1);
      expect(cart.items.first.quantity, 3);
      expect(cart.subtotal, 105.0);
    });

    test('addToCart replaces cart for different merchant', () async {
      await repo.addToCart(
        merchantId: 'm1', merchantName: 'Al Baik',
        item: CartItem(id: 'ci1', productId: 'p1', productName: 'Meal', quantity: 1, unitPrice: 35.0),
      );
      final cart = await repo.addToCart(
        merchantId: 'm2', merchantName: 'Tamimi',
        item: CartItem(id: 'ci2', productId: 'p4', productName: 'Milk', quantity: 1, unitPrice: 12.5),
      );
      expect(cart.merchantId, 'm2');
      expect(cart.items.length, 1);
      expect(cart.subtotal, 12.5);
    });

    test('updateCartItem updates quantity', () async {
      await repo.addToCart(
        merchantId: 'm1', merchantName: 'Al Baik',
        item: CartItem(id: 'ci1', productId: 'p1', productName: 'Meal', quantity: 1, unitPrice: 35.0),
      );
      final cart = await repo.updateCartItem(cartItemId: 'ci1', quantity: 3);
      expect(cart.items.first.quantity, 3);
      expect(cart.subtotal, 105.0);
    });

    test('updateCartItem removes item when quantity <= 0', () async {
      await repo.addToCart(
        merchantId: 'm1', merchantName: 'Al Baik',
        item: CartItem(id: 'ci1', productId: 'p1', productName: 'Meal', quantity: 1, unitPrice: 35.0),
      );
      final cart = await repo.updateCartItem(cartItemId: 'ci1', quantity: 0);
      expect(cart.id, 'empty');
      expect(cart.items, isEmpty);
    });

    test('removeFromCart removes item', () async {
      await repo.addToCart(
        merchantId: 'm1', merchantName: 'Al Baik',
        item: CartItem(id: 'ci1', productId: 'p1', productName: 'Meal', quantity: 1, unitPrice: 35.0),
      );
      final cart = await repo.removeFromCart(cartItemId: 'ci1');
      expect(cart.id, 'empty');
    });

    test('clearCart empties the cart', () async {
      await repo.addToCart(
        merchantId: 'm1', merchantName: 'Al Baik',
        item: CartItem(id: 'ci1', productId: 'p1', productName: 'Meal', quantity: 1, unitPrice: 35.0),
      );
      final cart = await repo.clearCart();
      expect(cart.id, 'empty');
      expect(cart.items, isEmpty);
      final current = await repo.getCurrentCart();
      expect(current, isNull);
    });

    test('applyCoupon applies SAVE10 discount', () async {
      await repo.addToCart(
        merchantId: 'm1', merchantName: 'Al Baik',
        item: CartItem(id: 'ci1', productId: 'p1', productName: 'Meal', quantity: 1, unitPrice: 100.0),
      );
      final cart = await repo.applyCoupon('SAVE10');
      expect(cart.couponCode, 'SAVE10');
      expect(cart.discount, 10.0);
    });

    test('removeCoupon removes discount', () async {
      await repo.addToCart(
        merchantId: 'm1', merchantName: 'Al Baik',
        item: CartItem(id: 'ci1', productId: 'p1', productName: 'Meal', quantity: 1, unitPrice: 100.0),
      );
      await repo.applyCoupon('SAVE10');
      final cart = await repo.removeCoupon();
      expect(cart.couponCode, isNull);
      expect(cart.discount, 0);
    });
  });

  group('OrderRepository', () {
    late MockOrderRepository repo;
    final _orders = <String, Order>{};
    var _nextId = 1;

    setUp(() {
      repo = MockOrderRepository();
      _orders.clear();
      _nextId = 1;

      when(() => repo.getOrders(
        status: any(named: 'status'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      )).thenAnswer((invocation) async {
        final status = invocation.namedArguments[#status] as OrderStatus?;
        final limit = invocation.namedArguments[#limit] as int? ?? 20;
        var results = _orders.values.toList();
        if (status != null) results = results.where((o) => o.status == status).toList();
        return results.take(limit).toList();
      });

      when(() => repo.getOrderById(any())).thenAnswer((invocation) async {
        final id = invocation.positionalArguments[0] as String;
        return _orders[id];
      });

      when(() => repo.createOrder(
        merchantId: any(named: 'merchantId'),
        merchantName: any(named: 'merchantName'),
        items: any(named: 'items'),
        subtotal: any(named: 'subtotal'),
        deliveryFee: any(named: 'deliveryFee'),
        discount: any(named: 'discount'),
        total: any(named: 'total'),
        deliveryAddress: any(named: 'deliveryAddress'),
        paymentMethod: any(named: 'paymentMethod'),
        specialInstructions: any(named: 'specialInstructions'),
      )).thenAnswer((invocation) async {
        final cartItems = invocation.namedArguments[#items] as List<CartItem>;
        final orderItems = cartItems.map((ci) => OrderItem(
          productId: ci.productId, productName: ci.productName,
          quantity: ci.quantity, unitPrice: ci.unitPrice,
          totalPrice: ci.unitPrice * ci.quantity,
        )).toList();
        final order = Order(
          id: 'ord_${_nextId++}',
          merchantId: invocation.namedArguments[#merchantId] as String,
          merchantName: invocation.namedArguments[#merchantName] as String,
          items: orderItems,
          subtotal: invocation.namedArguments[#subtotal] as double,
          deliveryFee: invocation.namedArguments[#deliveryFee] as double,
          discount: invocation.namedArguments[#discount] as double,
          total: invocation.namedArguments[#total] as double,
          status: OrderStatus.pending,
          createdAt: DateTime.now(),
        );
        _orders[order.id] = order;
        return order;
      });

      when(() => repo.cancelOrder(
        orderId: any(named: 'orderId'),
        reason: any(named: 'reason'),
      )).thenAnswer((invocation) async {
        final orderId = invocation.namedArguments[#orderId] as String;
        final reason = invocation.namedArguments[#reason] as String?;
        final order = _orders[orderId];
        if (order == null) throw StateError('Order not found');
        final cancelled = order.copyWith(
          status: OrderStatus.cancelled,
          cancellationReason: reason,
          cancelledAt: DateTime.now(),
        );
        _orders[orderId] = cancelled;
        return cancelled;
      });
    });

    test('getOrders returns empty initially', () async {
      final orders = await repo.getOrders();
      expect(orders, isEmpty);
    });

    test('createOrder creates and returns order', () async {
      final order = await repo.createOrder(
        merchantId: 'm1', merchantName: 'Test Merchant',
        items: [CartItem(id: 'ci1', productId: 'p1', productName: 'Meal', quantity: 2, unitPrice: 35.0)],
        subtotal: 70.0, deliveryFee: 10.0, discount: 0.0, total: 80.0,
      );
      expect(order.id, isNotEmpty);
      expect(order.status, OrderStatus.pending);
      expect(order.items.length, 1);
      expect(order.total, 80.0);
    });

    test('createOrder adds to orders list', () async {
      await repo.createOrder(
        merchantId: 'm1', merchantName: 'Test Merchant',
        items: [], subtotal: 0, deliveryFee: 0, discount: 0, total: 0,
      );
      final orders = await repo.getOrders();
      expect(orders.length, 1);
    });

    test('getOrderById returns order', () async {
      final created = await repo.createOrder(
        merchantId: 'm1', merchantName: 'Test Merchant',
        items: [], subtotal: 0, deliveryFee: 0, discount: 0, total: 0,
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
        merchantId: 'm1', merchantName: 'Test Merchant',
        items: [], subtotal: 0, deliveryFee: 0, discount: 0, total: 0,
      );
      final pending = await repo.getOrders(status: OrderStatus.pending);
      expect(pending, isNotEmpty);
      for (final o in pending) {
        expect(o.status, OrderStatus.pending);
      }
    });

    test('cancelOrder cancels the order', () async {
      final created = await repo.createOrder(
        merchantId: 'm1', merchantName: 'Test Merchant',
        items: [], subtotal: 0, deliveryFee: 0, discount: 0, total: 0,
      );
      final cancelled = await repo.cancelOrder(orderId: created.id, reason: 'Changed mind');
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

  group('ReviewRepository', () {
    late MockReviewRepository repo;
    final _reviews = <String, Review>{};

    setUp(() {
      repo = MockReviewRepository();
      _reviews.clear();

      when(() => repo.getMerchantReviews(any())).thenAnswer((invocation) async {
        final merchantId = invocation.positionalArguments[0] as String;
        return _reviews.values.where((r) => r.merchantId == merchantId).toList();
      });

      when(() => repo.getReviewById(any())).thenAnswer((invocation) async {
        final id = invocation.positionalArguments[0] as String;
        return _reviews[id];
      });

      when(() => repo.submitReview(
        merchantId: any(named: 'merchantId'),
        userId: any(named: 'userId'),
        productId: any(named: 'productId'),
        orderId: any(named: 'orderId'),
        rating: any(named: 'rating'),
        comment: any(named: 'comment'),
        imageUrls: any(named: 'imageUrls'),
      )).thenAnswer((invocation) async {
        final review = Review(
          id: 'rev_${_reviews.length + 1}',
          merchantId: invocation.namedArguments[#merchantId] as String,
          userId: invocation.namedArguments[#userId] as String,
          rating: invocation.namedArguments[#rating] as double,
          comment: invocation.namedArguments[#comment] as String?,
          createdAt: DateTime.now(),
        );
        _reviews[review.id] = review;
        return review;
      });
    });

    test('getMerchantReviews returns empty initially', () async {
      final reviews = await repo.getMerchantReviews('m1');
      expect(reviews, isEmpty);
    });

    test('submitReview creates and returns review', () async {
      final review = await repo.submitReview(
        merchantId: 'm1', userId: 'user_1', rating: 4.5, comment: 'Great!',
      );
      expect(review.id, isNotEmpty);
      expect(review.merchantId, 'm1');
      expect(review.rating, 4.5);
      expect(review.comment, 'Great!');
      expect(review.userId, 'user_1');
    });

    test('getMerchantReviews returns reviews for merchant', () async {
      await repo.submitReview(merchantId: 'm1', userId: 'u1', rating: 5.0);
      await repo.submitReview(merchantId: 'm1', userId: 'u2', rating: 4.0);
      await repo.submitReview(merchantId: 'm2', userId: 'u3', rating: 3.0);
      final reviews = await repo.getMerchantReviews('m1');
      expect(reviews.length, 2);
      for (final r in reviews) {
        expect(r.merchantId, 'm1');
      }
    });

    test('getReviewById returns review', () async {
      final submitted = await repo.submitReview(
        merchantId: 'm1', userId: 'user_1', rating: 4.0,
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

  group('CouponRepository', () {
    late MockCouponRepository repo;

    setUp(() {
      repo = MockCouponRepository();
      when(() => repo.getAvailableCoupons()).thenAnswer(
        (_) async => _testCoupons.where((c) => c.isActive).toList(),
      );
      when(() => repo.getCouponByCode(any())).thenAnswer((invocation) async {
        final code = (invocation.positionalArguments[0] as String).toUpperCase();
        return _testCoupons.where((c) => c.code == code).firstOrNull;
      });
      when(() => repo.validateCoupon(any(), any())).thenAnswer((invocation) async {
        final code = (invocation.positionalArguments[0] as String).toUpperCase();
        final total = invocation.positionalArguments[1] as double;
        final coupon = _testCoupons.where((c) => c.code == code).firstOrNull;
        if (coupon == null) return null;
        if (coupon.minimumOrder != null && total < coupon.minimumOrder!) return null;
        return coupon;
      });
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

  group('FavoriteRepository', () {
    late MockFavoriteRepository repo;
    final _favs = <String, Favorite>{};

    setUp(() {
      repo = MockFavoriteRepository();
      _favs.clear();

      when(() => repo.getFavorites(type: any(named: 'type'))).thenAnswer((invocation) async {
        final type = invocation.namedArguments[#type] as FavoriteType?;
        var results = _favs.values.toList();
        if (type != null) results = results.where((f) => f.type == type).toList();
        return results;
      });

      when(() => repo.isFavorite(any(), any())).thenAnswer((invocation) async {
        final targetId = invocation.positionalArguments[0] as String;
        final type = invocation.positionalArguments[1] as FavoriteType;
        return _favs.values.any((f) => f.targetId == targetId && f.type == type);
      });

      when(() => repo.toggleFavorite(
        targetId: any(named: 'targetId'),
        type: any(named: 'type'),
      )).thenAnswer((invocation) async {
        final targetId = invocation.namedArguments[#targetId] as String;
        final type = invocation.namedArguments[#type] as FavoriteType;
        final existing = _favs.values.where((f) => f.targetId == targetId && f.type == type).firstOrNull;
        if (existing != null) {
          _favs.remove(existing.id);
        } else {
          final fav = Favorite(
            id: 'fav_${_favs.length + 1}',
            targetId: targetId, type: type, createdAt: DateTime.now(),
          );
          _favs[fav.id] = fav;
        }
      });
    });

    test('getFavorites returns empty initially', () async {
      final favorites = await repo.getFavorites();
      expect(favorites, isEmpty);
    });

    test('toggleFavorite adds favorite', () async {
      await repo.toggleFavorite(targetId: 'm1', type: FavoriteType.merchant);
      final favorites = await repo.getFavorites();
      expect(favorites.length, 1);
      expect(favorites.first.targetId, 'm1');
    });

    test('toggleFavorite removes existing favorite', () async {
      await repo.toggleFavorite(targetId: 'm1', type: FavoriteType.merchant);
      await repo.toggleFavorite(targetId: 'm1', type: FavoriteType.merchant);
      final favorites = await repo.getFavorites();
      expect(favorites, isEmpty);
    });

    test('isFavorite returns correct status', () async {
      expect(await repo.isFavorite('m1', FavoriteType.merchant), false);
      await repo.toggleFavorite(targetId: 'm1', type: FavoriteType.merchant);
      expect(await repo.isFavorite('m1', FavoriteType.merchant), true);
    });

    test('getFavorites filters by type', () async {
      await repo.toggleFavorite(targetId: 'm1', type: FavoriteType.merchant);
      await repo.toggleFavorite(targetId: 'p1', type: FavoriteType.product);
      final merchants = await repo.getFavorites(type: FavoriteType.merchant);
      expect(merchants.length, 1);
      expect(merchants.first.type, FavoriteType.merchant);
      final products = await repo.getFavorites(type: FavoriteType.product);
      expect(products.length, 1);
      expect(products.first.type, FavoriteType.product);
    });
  });
}
