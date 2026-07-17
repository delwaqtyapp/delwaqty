import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/commerce/domain/entities/product.dart';
import 'package:delwaqty/features/commerce/domain/entities/cart.dart';
import 'package:delwaqty/features/commerce/domain/entities/order.dart';
import 'package:delwaqty/features/commerce/domain/entities/review.dart';
import 'package:delwaqty/features/commerce/domain/entities/coupon.dart';
import 'package:delwaqty/features/commerce/domain/entities/favorite.dart';
import 'package:delwaqty/features/commerce/domain/entities/catalog_category.dart';
import 'package:delwaqty/features/commerce/domain/entities/search_filter.dart';
import 'package:delwaqty/features/commerce/domain/entities/geo_location.dart';

void main() {
  final now = DateTime(2025, 6, 15);

  group('Merchant', () {
    test('fromJson creates Merchant from JSON', () {
      final json = {
        'id': 'm1',
        'name': 'Al Baik',
        'type': 'restaurant',
        'latitude': 24.7136,
        'longitude': 46.6753,
        'address': 'Olaya St',
        'city': 'Riyadh',
        'rating': 4.5,
        'ratingCount': 100,
        'imageUrl': 'https://example.com/img.jpg',
        'description': 'Famous restaurant',
        'isOpenNow': true,
        'isVerified': true,
        'isFeatured': false,
        'deliveryAvailable': true,
        'pickupAvailable': false,
        'estimatedDeliveryMinutes': 30,
        'deliveryFee': 10.0,
        'minimumOrder': 25.0,
        'tags': ['chicken'],
        'createdAt': now.toIso8601String(),
        'updatedAt': null,
      };

      final merchant = Merchant.fromJson(json);
      expect(merchant.id, 'm1');
      expect(merchant.name, 'Al Baik');
      expect(merchant.type, MerchantType.restaurant);
      expect(merchant.latitude, 24.7136);
      expect(merchant.longitude, 46.6753);
      expect(merchant.address, 'Olaya St');
      expect(merchant.city, 'Riyadh');
      expect(merchant.rating, 4.5);
      expect(merchant.ratingCount, 100);
      expect(merchant.isOpenNow, true);
      expect(merchant.isVerified, true);
      expect(merchant.deliveryAvailable, true);
      expect(merchant.pickupAvailable, false);
      expect(merchant.estimatedDeliveryMinutes, 30);
      expect(merchant.deliveryFee, 10.0);
      expect(merchant.minimumOrder, 25.0);
      expect(merchant.tags, ['chicken']);
      expect(merchant.updatedAt, isNull);
    });

    test('toJson serializes correctly', () {
      final merchant = Merchant(
        id: 'm1',
        name: 'Al Baik',
        type: MerchantType.restaurant,
        latitude: 24.7136,
        longitude: 46.6753,
        createdAt: now,
      );

      final json = merchant.toJson();
      expect(json['id'], 'm1');
      expect(json['name'], 'Al Baik');
      expect(json['type'], 'restaurant');
      expect(json['latitude'], 24.7136);
      expect(json['longitude'], 46.6753);
      expect(json['isOpenNow'], false);
      expect(json['isVerified'], false);
      expect(json['tags'], []);
    });

    test('fromJson roundtrip preserves data', () {
      final original = Merchant(
        id: 'm1',
        name: 'Al Baik',
        type: MerchantType.restaurant,
        latitude: 24.7136,
        longitude: 46.6753,
        rating: 4.5,
        ratingCount: 1250,
        isOpenNow: true,
        isVerified: true,
        isFeatured: true,
        deliveryAvailable: true,
        pickupAvailable: true,
        estimatedDeliveryMinutes: 30,
        deliveryFee: 10.0,
        minimumOrder: 25.0,
        tags: ['chicken', 'fast food'],
        createdAt: now,
      );

      final restored = Merchant.fromJson(original.toJson());
      expect(restored, original);
    });

    test('equality works correctly', () {
      final a = Merchant(
        id: 'm1',
        name: 'Al Baik',
        type: MerchantType.restaurant,
        latitude: 24.7136,
        longitude: 46.6753,
        createdAt: now,
      );
      final b = Merchant(
        id: 'm1',
        name: 'Al Baik',
        type: MerchantType.restaurant,
        latitude: 24.7136,
        longitude: 46.6753,
        createdAt: now,
      );
      final c = Merchant(
        id: 'm2',
        name: 'Other',
        type: MerchantType.grocery,
        latitude: 0,
        longitude: 0,
        createdAt: now,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith creates modified copy', () {
      final merchant = Merchant(
        id: 'm1',
        name: 'Al Baik',
        type: MerchantType.restaurant,
        latitude: 24.7136,
        longitude: 46.6753,
        createdAt: now,
      );

      final updated = merchant.copyWith(name: 'New Name', rating: 5.0);
      expect(updated.name, 'New Name');
      expect(updated.rating, 5.0);
      expect(updated.id, 'm1');
      expect(merchant.name, 'Al Baik');
    });

    test('defaults are applied correctly', () {
      final merchant = Merchant(
        id: 'm1',
        name: 'Al Baik',
        type: MerchantType.restaurant,
        latitude: 24.7136,
        longitude: 46.6753,
        createdAt: now,
      );

      expect(merchant.rating, 0.0);
      expect(merchant.ratingCount, 0);
      expect(merchant.isOpenNow, false);
      expect(merchant.isVerified, false);
      expect(merchant.isFeatured, false);
      expect(merchant.deliveryAvailable, false);
      expect(merchant.pickupAvailable, false);
      expect(merchant.tags, isEmpty);
    });

    test('MerchantType enum has all values', () {
      expect(MerchantType.values.length, 10);
      expect(MerchantType.restaurant.name, 'restaurant');
      expect(MerchantType.grocery.name, 'grocery');
      expect(MerchantType.pharmacy.name, 'pharmacy');
      expect(MerchantType.other.name, 'other');
    });
  });

  group('Product', () {
    test('fromJson creates Product from JSON', () {
      final json = {
        'id': 'p1',
        'merchantId': 'm1',
        'categoryId': 'c1',
        'name': 'Chicken Meal',
        'description': 'Crispy chicken',
        'price': 35.0,
        'originalPrice': 50.0,
        'imageUrl': 'https://example.com/img.jpg',
        'variants': [],
        'isAvailable': true,
        'isFeatured': false,
        'tags': ['chicken'],
        'createdAt': now.toIso8601String(),
        'updatedAt': null,
      };

      final product = Product.fromJson(json);
      expect(product.id, 'p1');
      expect(product.merchantId, 'm1');
      expect(product.categoryId, 'c1');
      expect(product.name, 'Chicken Meal');
      expect(product.price, 35.0);
      expect(product.originalPrice, 50.0);
      expect(product.isAvailable, true);
      expect(product.isFeatured, false);
      expect(product.variants, isEmpty);
    });

    test('toJson serializes correctly', () {
      final product = Product(
        id: 'p1',
        merchantId: 'm1',
        categoryId: 'c1',
        name: 'Chicken Meal',
        price: 35.0,
        createdAt: now,
      );

      final json = product.toJson();
      expect(json['id'], 'p1');
      expect(json['price'], 35.0);
      expect(json['isAvailable'], true);
      expect(json['tags'], []);
    });

    test('fromJson roundtrip preserves data', () {
      final original = Product(
        id: 'p1',
        merchantId: 'm1',
        categoryId: 'c1',
        name: 'Chicken Meal',
        price: 35.0,
        originalPrice: 50.0,
        isAvailable: true,
        isFeatured: true,
        tags: ['popular'],
        createdAt: now,
        variants: [
          ProductVariant(
            id: 'v1',
            productId: 'p1',
            name: 'Large',
            price: 45.0,
          ),
        ],
      );

      final restored = Product.fromJson(original.toJson());
      expect(restored, original);
    });

    test('copyWith creates modified copy', () {
      final product = Product(
        id: 'p1',
        merchantId: 'm1',
        categoryId: 'c1',
        name: 'Chicken Meal',
        price: 35.0,
        createdAt: now,
      );

      final updated = product.copyWith(name: 'New Meal', price: 40.0);
      expect(updated.name, 'New Meal');
      expect(updated.price, 40.0);
      expect(updated.id, 'p1');
    });

    test('defaults are applied correctly', () {
      final product = Product(
        id: 'p1',
        merchantId: 'm1',
        categoryId: 'c1',
        name: 'Chicken Meal',
        price: 35.0,
        createdAt: now,
      );

      expect(product.isAvailable, true);
      expect(product.isFeatured, false);
      expect(product.tags, isEmpty);
      expect(product.variants, isEmpty);
      expect(product.originalPrice, isNull);
    });

    test('equality works correctly', () {
      final a = Product(
        id: 'p1',
        merchantId: 'm1',
        categoryId: 'c1',
        name: 'Meal',
        price: 35.0,
        createdAt: now,
      );
      final b = Product(
        id: 'p1',
        merchantId: 'm1',
        categoryId: 'c1',
        name: 'Meal',
        price: 35.0,
        createdAt: now,
      );

      expect(a, equals(b));
    });
  });

  group('ProductVariant', () {
    test('fromJson creates ProductVariant from JSON', () {
      final json = {
        'id': 'v1',
        'productId': 'p1',
        'name': 'Large',
        'price': 45.0,
        'isAvailable': true,
      };

      final variant = ProductVariant.fromJson(json);
      expect(variant.id, 'v1');
      expect(variant.productId, 'p1');
      expect(variant.name, 'Large');
      expect(variant.price, 45.0);
      expect(variant.isAvailable, true);
    });

    test('toJson serializes correctly', () {
      final variant = ProductVariant(
        id: 'v1',
        productId: 'p1',
        name: 'Large',
        price: 45.0,
      );

      final json = variant.toJson();
      expect(json['id'], 'v1');
      expect(json['price'], 45.0);
      expect(json['isAvailable'], true);
    });

    test('equality and copyWith work correctly', () {
      final variant = ProductVariant(
        id: 'v1',
        productId: 'p1',
        name: 'Large',
        price: 45.0,
      );

      final copy = variant.copyWith(price: 50.0);
      expect(copy.price, 50.0);
      expect(copy.name, 'Large');
      expect(variant.price, 45.0);
    });
  });

  group('Cart', () {
    test('fromJson creates Cart from JSON', () {
      final json = {
        'id': 'cart_1',
        'merchantId': 'm1',
        'merchantName': 'Al Baik',
        'items': [
          {
            'id': 'ci1',
            'productId': 'p1',
            'productName': 'Chicken Meal',
            'variantName': null,
            'quantity': 2,
            'unitPrice': 35.0,
            'totalPrice': null,
            'specialInstructions': null,
          },
        ],
        'subtotal': 70.0,
        'deliveryFee': 10.0,
        'discount': 0.0,
        'total': 80.0,
        'couponCode': null,
        'specialInstructions': null,
        'updatedAt': now.toIso8601String(),
      };

      final cart = Cart.fromJson(json);
      expect(cart.id, 'cart_1');
      expect(cart.merchantId, 'm1');
      expect(cart.merchantName, 'Al Baik');
      expect(cart.items.length, 1);
      expect(cart.subtotal, 70.0);
      expect(cart.total, 80.0);
    });

    test('toJson serializes correctly', () {
      final cart = Cart(
        id: 'cart_1',
        merchantId: 'm1',
        merchantName: 'Al Baik',
        subtotal: 70.0,
        total: 80.0,
        updatedAt: now,
      );

      final json = cart.toJson();
      expect(json['id'], 'cart_1');
      expect(json['items'], isEmpty);
      expect(json['subtotal'], 70.0);
    });

    test('defaults are applied correctly', () {
      final cart = Cart(
        id: 'cart_1',
        merchantId: 'm1',
        merchantName: 'Al Baik',
        updatedAt: now,
      );

      expect(cart.items, isEmpty);
      expect(cart.subtotal, 0.0);
      expect(cart.deliveryFee, 0.0);
      expect(cart.discount, 0.0);
      expect(cart.total, 0.0);
      expect(cart.couponCode, isNull);
    });

    test('fromJson roundtrip preserves data', () {
      final original = Cart(
        id: 'cart_1',
        merchantId: 'm1',
        merchantName: 'Al Baik',
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
        discount: 5.0,
        total: 75.0,
        couponCode: 'SAVE10',
        specialInstructions: 'No onions',
        updatedAt: now,
      );

      final restored = Cart.fromJson(original.toJson());
      expect(restored, original);
    });
  });

  group('CartItem', () {
    test('fromJson creates CartItem from JSON', () {
      final json = {
        'id': 'ci1',
        'productId': 'p1',
        'productName': 'Chicken Meal',
        'variantName': 'Large',
        'quantity': 2,
        'unitPrice': 35.0,
        'totalPrice': 70.0,
        'specialInstructions': 'Extra sauce',
      };

      final item = CartItem.fromJson(json);
      expect(item.id, 'ci1');
      expect(item.productId, 'p1');
      expect(item.productName, 'Chicken Meal');
      expect(item.variantName, 'Large');
      expect(item.quantity, 2);
      expect(item.unitPrice, 35.0);
      expect(item.totalPrice, 70.0);
      expect(item.specialInstructions, 'Extra sauce');
    });

    test('toJson serializes correctly', () {
      final item = CartItem(
        id: 'ci1',
        productId: 'p1',
        productName: 'Meal',
        quantity: 1,
        unitPrice: 35.0,
      );

      final json = item.toJson();
      expect(json['id'], 'ci1');
      expect(json['quantity'], 1);
      expect(json['variantName'], isNull);
    });

    test('copyWith creates modified copy', () {
      final item = CartItem(
        id: 'ci1',
        productId: 'p1',
        productName: 'Meal',
        quantity: 1,
        unitPrice: 35.0,
      );

      final updated = item.copyWith(quantity: 3);
      expect(updated.quantity, 3);
      expect(updated.productName, 'Meal');
      expect(item.quantity, 1);
    });
  });

  group('Order', () {
    test('fromJson creates Order from JSON', () {
      final json = {
        'id': 'order_1',
        'merchantId': 'm1',
        'merchantName': 'Al Baik',
        'items': [],
        'subtotal': 70.0,
        'deliveryFee': 10.0,
        'discount': 0.0,
        'total': 80.0,
        'status': 'pending',
        'deliveryAddress': '123 Main St',
        'paymentMethod': 'credit_card',
        'specialInstructions': null,
        'confirmedAt': null,
        'preparingAt': null,
        'readyAt': null,
        'deliveredAt': null,
        'cancelledAt': null,
        'cancellationReason': null,
        'createdAt': now.toIso8601String(),
        'updatedAt': null,
      };

      final order = Order.fromJson(json);
      expect(order.id, 'order_1');
      expect(order.status, OrderStatus.pending);
      expect(order.subtotal, 70.0);
      expect(order.deliveryAddress, '123 Main St');
      expect(order.paymentMethod, 'credit_card');
    });

    test('toJson serializes correctly', () {
      final order = Order(
        id: 'order_1',
        merchantId: 'm1',
        merchantName: 'Al Baik',
        subtotal: 70.0,
        status: OrderStatus.confirmed,
        createdAt: now,
      );

      final json = order.toJson();
      expect(json['id'], 'order_1');
      expect(json['status'], 'confirmed');
      expect(json['deliveryFee'], 0.0);
    });

    test('OrderStatus enum has all values', () {
      expect(OrderStatus.values.length, 8);
      expect(OrderStatus.pending.name, 'pending');
      expect(OrderStatus.delivered.name, 'delivered');
      expect(OrderStatus.cancelled.name, 'cancelled');
    });

    test('fromJson roundtrip preserves data', () {
      final original = Order(
        id: 'order_1',
        merchantId: 'm1',
        merchantName: 'Al Baik',
        items: [
          OrderItem(
            productId: 'p1',
            productName: 'Meal',
            quantity: 2,
            unitPrice: 35.0,
            totalPrice: 70.0,
          ),
        ],
        subtotal: 70.0,
        deliveryFee: 10.0,
        total: 80.0,
        status: OrderStatus.preparing,
        createdAt: now,
      );

      final restored = Order.fromJson(original.toJson());
      expect(restored, original);
    });

    test('copyWith creates modified copy', () {
      final order = Order(
        id: 'order_1',
        merchantId: 'm1',
        merchantName: 'Al Baik',
        subtotal: 70.0,
        status: OrderStatus.pending,
        createdAt: now,
      );

      final updated = order.copyWith(
        status: OrderStatus.delivered,
        deliveredAt: now,
      );
      expect(updated.status, OrderStatus.delivered);
      expect(order.status, OrderStatus.pending);
    });
  });

  group('OrderItem', () {
    test('fromJson creates OrderItem from JSON', () {
      final json = {
        'productId': 'p1',
        'productName': 'Chicken Meal',
        'variantName': 'Large',
        'quantity': 2,
        'unitPrice': 35.0,
        'totalPrice': 70.0,
      };

      final item = OrderItem.fromJson(json);
      expect(item.productId, 'p1');
      expect(item.productName, 'Chicken Meal');
      expect(item.variantName, 'Large');
      expect(item.quantity, 2);
      expect(item.unitPrice, 35.0);
      expect(item.totalPrice, 70.0);
    });

    test('toJson serializes correctly', () {
      final item = OrderItem(
        productId: 'p1',
        productName: 'Meal',
        quantity: 1,
        unitPrice: 35.0,
        totalPrice: 35.0,
      );

      final json = item.toJson();
      expect(json['productId'], 'p1');
      expect(json['totalPrice'], 35.0);
    });
  });

  group('Review', () {
    test('fromJson creates Review from JSON', () {
      final json = {
        'id': 'r1',
        'merchantId': 'm1',
        'userId': 'u1',
        'userName': 'Ahmed',
        'rating': 4.5,
        'comment': 'Great food!',
        'imageUrls': ['https://example.com/img.jpg'],
        'createdAt': now.toIso8601String(),
      };

      final review = Review.fromJson(json);
      expect(review.id, 'r1');
      expect(review.merchantId, 'm1');
      expect(review.userId, 'u1');
      expect(review.userName, 'Ahmed');
      expect(review.rating, 4.5);
      expect(review.comment, 'Great food!');
      expect(review.imageUrls, ['https://example.com/img.jpg']);
    });

    test('toJson serializes correctly', () {
      final review = Review(
        id: 'r1',
        merchantId: 'm1',
        userId: 'u1',
        rating: 5.0,
        createdAt: now,
      );

      final json = review.toJson();
      expect(json['id'], 'r1');
      expect(json['rating'], 5.0);
      expect(json['imageUrls'], isEmpty);
    });

    test('defaults are applied correctly', () {
      final review = Review(
        id: 'r1',
        merchantId: 'm1',
        userId: 'u1',
        rating: 4.0,
      );

      expect(review.imageUrls, isEmpty);
      expect(review.comment, isNull);
      expect(review.createdAt, isNull);
    });

    test('fromJson roundtrip preserves data', () {
      final original = Review(
        id: 'r1',
        merchantId: 'm1',
        userId: 'u1',
        userName: 'Ahmed',
        rating: 4.5,
        comment: 'Great!',
        imageUrls: ['url1', 'url2'],
        createdAt: now,
      );

      final restored = Review.fromJson(original.toJson());
      expect(restored, original);
    });
  });

  group('Coupon', () {
    test('fromJson creates Coupon from JSON', () {
      final json = {
        'id': 'coupon_1',
        'code': 'SAVE10',
        'type': 'percentage',
        'value': 10,
        'minimumOrder': 30.0,
        'maximumDiscount': 50.0,
        'applicableMerchantIds': [],
        'usageLimit': null,
        'usedCount': null,
        'expiresAt': now.toIso8601String(),
        'isActive': true,
      };

      final coupon = Coupon.fromJson(json);
      expect(coupon.id, 'coupon_1');
      expect(coupon.code, 'SAVE10');
      expect(coupon.type, CouponType.percentage);
      expect(coupon.value, 10);
      expect(coupon.minimumOrder, 30.0);
      expect(coupon.maximumDiscount, 50.0);
      expect(coupon.isActive, true);
    });

    test('toJson serializes correctly', () {
      final coupon = Coupon(
        id: 'c1',
        code: 'FREEDEL',
        type: CouponType.freeDelivery,
        value: 0,
        expiresAt: now,
      );

      final json = coupon.toJson();
      expect(json['code'], 'FREEDEL');
      expect(json['type'], 'free_delivery');
      expect(json['isActive'], true);
    });

    test('CouponType enum has all values', () {
      expect(CouponType.values.length, 3);
      expect(CouponType.percentage.name, 'percentage');
      expect(CouponType.fixed.name, 'fixed');
      expect(CouponType.freeDelivery.name, 'freeDelivery');
    });

    test('defaults are applied correctly', () {
      final coupon = Coupon(
        id: 'c1',
        code: 'TEST',
        type: CouponType.percentage,
        value: 10,
      );

      expect(coupon.isActive, true);
      expect(coupon.minimumOrder, isNull);
      expect(coupon.maximumDiscount, isNull);
      expect(coupon.expiresAt, isNull);
      expect(coupon.merchantId, isNull);
      expect(coupon.branchId, isNull);
      expect(coupon.productId, isNull);
      expect(coupon.categoryId, isNull);
    });

    test('fromJson roundtrip preserves data', () {
      final original = Coupon(
        id: 'c1',
        code: 'SAVE10',
        description: 'Save 10 percent',
        type: CouponType.percentage,
        value: 10,
        minimumOrder: 30.0,
        maximumDiscount: 50.0,
        merchantId: 'm1',
        usageLimit: 100,
        usedCount: 5,
        expiresAt: now,
        isActive: true,
      );

      final restored = Coupon.fromJson(original.toJson());
      expect(restored, original);
    });
  });

  group('Favorite', () {
    test('fromJson creates Favorite from JSON', () {
      final json = {
        'id': 'fav_1',
        'targetId': 'm1',
        'type': 'merchant',
        'createdAt': now.toIso8601String(),
      };

      final favorite = Favorite.fromJson(json);
      expect(favorite.id, 'fav_1');
      expect(favorite.targetId, 'm1');
      expect(favorite.type, FavoriteType.merchant);
    });

    test('toJson serializes correctly', () {
      final favorite = Favorite(
        id: 'fav_1',
        targetId: 'p1',
        type: FavoriteType.product,
        createdAt: now,
      );

      final json = favorite.toJson();
      expect(json['type'], 'product');
      expect(json['targetId'], 'p1');
    });

    test('FavoriteType enum has all values', () {
      expect(FavoriteType.values.length, 2);
      expect(FavoriteType.merchant.name, 'merchant');
      expect(FavoriteType.product.name, 'product');
    });

    test('fromJson roundtrip preserves data', () {
      final original = Favorite(
        id: 'fav_1',
        targetId: 'm1',
        type: FavoriteType.merchant,
        createdAt: now,
      );

      final restored = Favorite.fromJson(original.toJson());
      expect(restored, original);
    });
  });

  group('CatalogCategory', () {
    test('fromJson creates CatalogCategory from JSON', () {
      final json = {
        'id': 'c1',
        'merchantId': 'm1',
        'name': 'Meals',
        'description': 'Main courses',
        'icon': 'meal',
        'imageUrl': 'https://example.com/img.jpg',
        'sortOrder': 0,
        'isVisible': true,
      };

      final category = CatalogCategory.fromJson(json);
      expect(category.id, 'c1');
      expect(category.merchantId, 'm1');
      expect(category.name, 'Meals');
      expect(category.description, 'Main courses');
      expect(category.icon, 'meal');
      expect(category.sortOrder, 0);
      expect(category.isVisible, true);
    });

    test('toJson serializes correctly', () {
      final category = CatalogCategory(
        id: 'c1',
        merchantId: 'm1',
        name: 'Meals',
      );

      final json = category.toJson();
      expect(json['id'], 'c1');
      expect(json['sortOrder'], 0);
      expect(json['isVisible'], true);
    });

    test('fromJson roundtrip preserves data', () {
      final original = CatalogCategory(
        id: 'c1',
        merchantId: 'm1',
        name: 'Meals',
        description: 'Delicious meals',
        icon: 'meal',
        imageUrl: 'url',
        sortOrder: 2,
        isVisible: false,
      );

      final restored = CatalogCategory.fromJson(original.toJson());
      expect(restored, original);
    });
  });

  group('SearchFilter', () {
    test('fromJson creates SearchFilter from JSON', () {
      final json = {
        'minPrice': 10.0,
        'maxPrice': 100.0,
        'minRating': 4.0,
        'maxDeliveryMinutes': 30,
        'maxDistanceKm': 5.0,
        'tags': ['fast food'],
        'sortBy': 'rating',
      };

      final filter = SearchFilter.fromJson(json);
      expect(filter.minPrice, 10.0);
      expect(filter.maxPrice, 100.0);
      expect(filter.minRating, 4.0);
      expect(filter.maxDeliveryMinutes, 30);
      expect(filter.maxDistanceKm, 5.0);
      expect(filter.tags, ['fast food']);
      expect(filter.sortBy, SortBy.rating);
    });

    test('toJson serializes correctly', () {
      final filter = SearchFilter(
        minPrice: 10.0,
        sortBy: SortBy.priceLow,
      );

      final json = filter.toJson();
      expect(json['minPrice'], 10.0);
      expect(json['sortBy'], 'price_low');
      expect(json['tags'], isEmpty);
    });

    test('SortBy enum has all values', () {
      expect(SortBy.values.length, 6);
      expect(SortBy.distance.name, 'distance');
      expect(SortBy.rating.name, 'rating');
      expect(SortBy.priceLow.name, 'priceLow');
    });

    test('defaults are applied correctly', () {
      final filter = SearchFilter();
      expect(filter.minPrice, isNull);
      expect(filter.maxPrice, isNull);
      expect(filter.minRating, isNull);
      expect(filter.tags, isEmpty);
      expect(filter.sortBy, SortBy.distance);
    });

    test('fromJson roundtrip preserves data', () {
      final original = SearchFilter(
        minPrice: 10.0,
        maxPrice: 100.0,
        minRating: 4.0,
        maxDeliveryMinutes: 30,
        maxDistanceKm: 5.0,
        tags: ['fast food'],
        sortBy: SortBy.rating,
      );

      final restored = SearchFilter.fromJson(original.toJson());
      expect(restored, original);
    });
  });

  group('GeoLocation', () {
    test('fromJson creates GeoLocation from JSON', () {
      final json = {
        'latitude': 24.7136,
        'longitude': 46.6753,
        'address': 'Olaya St',
        'city': 'Riyadh',
        'district': 'Al Olaya',
      };

      final location = GeoLocation.fromJson(json);
      expect(location.latitude, 24.7136);
      expect(location.longitude, 46.6753);
      expect(location.address, 'Olaya St');
      expect(location.city, 'Riyadh');
      expect(location.district, 'Al Olaya');
    });

    test('toJson serializes correctly', () {
      final location = GeoLocation(
        latitude: 24.7136,
        longitude: 46.6753,
      );

      final json = location.toJson();
      expect(json['latitude'], 24.7136);
      expect(json['longitude'], 46.6753);
      expect(json['address'], isNull);
    });

    test('fromJson roundtrip preserves data', () {
      final original = GeoLocation(
        latitude: 24.7136,
        longitude: 46.6753,
        address: 'Olaya St',
        city: 'Riyadh',
        district: 'Al Olaya',
      );

      final restored = GeoLocation.fromJson(original.toJson());
      expect(restored, original);
    });
  });
}
