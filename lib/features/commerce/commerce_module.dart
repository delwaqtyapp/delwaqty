import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/commerce/domain/repositories/merchant_repository.dart';
import 'package:delwaqty/features/commerce/domain/repositories/product_repository.dart';
import 'package:delwaqty/features/commerce/domain/repositories/catalog_category_repository.dart';
import 'package:delwaqty/features/commerce/domain/repositories/cart_repository.dart';
import 'package:delwaqty/features/commerce/domain/repositories/order_repository.dart';
import 'package:delwaqty/features/commerce/domain/repositories/review_repository.dart';
import 'package:delwaqty/features/commerce/domain/repositories/coupon_repository.dart';
import 'package:delwaqty/features/commerce/domain/repositories/favorite_repository.dart';
import 'package:delwaqty/features/commerce/data/repositories/mock/mock_merchant_repository.dart';
import 'package:delwaqty/features/commerce/data/repositories/mock/mock_product_repository.dart';
import 'package:delwaqty/features/commerce/data/repositories/mock/mock_catalog_category_repository.dart';
import 'package:delwaqty/features/commerce/data/repositories/mock/mock_cart_repository.dart';
import 'package:delwaqty/features/commerce/data/repositories/mock/mock_order_repository.dart';
import 'package:delwaqty/features/commerce/data/repositories/mock/mock_review_repository.dart';
import 'package:delwaqty/features/commerce/data/repositories/mock/mock_coupon_repository.dart';
import 'package:delwaqty/features/commerce/data/repositories/mock/mock_favorite_repository.dart';
import 'package:delwaqty/features/commerce/presentation/pages/commerce_discovery_page.dart';
import 'package:delwaqty/features/commerce/presentation/pages/merchant_detail_page.dart';
import 'package:delwaqty/features/commerce/presentation/pages/product_detail_page.dart';
import 'package:delwaqty/features/commerce/presentation/pages/cart_page.dart';
import 'package:delwaqty/features/commerce/presentation/pages/checkout_page.dart';
import 'package:delwaqty/features/commerce/presentation/pages/orders_page.dart';

// ─── Repository Providers ───

final merchantRepositoryProvider = Provider<MerchantRepository>(
  (_) => MockMerchantRepository(),
);

final productRepositoryProvider = Provider<ProductRepository>(
  (_) => MockProductRepository(),
);

final catalogCategoryRepositoryProvider = Provider<CatalogCategoryRepository>(
  (_) => MockCatalogCategoryRepository(),
);

final cartRepositoryProvider = Provider<CartRepository>(
  (_) => MockCartRepository(),
);

final orderRepositoryProvider = Provider<OrderRepository>(
  (_) => MockOrderRepository(),
);

final reviewRepositoryProvider = Provider<ReviewRepository>(
  (_) => MockReviewRepository(),
);

final couponRepositoryProvider = Provider<CouponRepository>(
  (_) => MockCouponRepository(),
);

final favoriteRepositoryProvider = Provider<FavoriteRepository>(
  (_) => MockFavoriteRepository(),
);

// ─── Commerce Module ───

class CommerceModule extends FeatureModule {
  @override
  String get id => 'commerce';

  @override
  String name(BuildContext context) => 'Market';

  @override
  IconData? get icon => Icons.storefront_outlined;

  @override
  bool get isNavModule => false;

  @override
  int get navPriority => 0;

  @override
  Set<ModuleCapability> get capabilities => {
        ModuleCapability.hasDeepLinks,
      };

  @override
  List<String> get dependsOn => [];

  @override
  StatefulShellBranch? buildBranch() => null;

  @override
  List<RouteBase> get shellSubRoutes => [];

  @override
  List<RouteBase> get standaloneRoutes => [
        GoRoute(
          path: '/market',
          builder: (context, state) => const CommerceDiscoveryPage(),
          routes: [
            GoRoute(
              path: 'merchant/:id',
              builder: (context, state) => MerchantDetailPage(
                merchantId: state.pathParameters['id']!,
              ),
              routes: [
                GoRoute(
                  path: 'product/:productId',
                  builder: (context, state) => ProductDetailPage(
                    productId: state.pathParameters['productId']!,
                    merchantId: state.pathParameters['id']!,
                  ),
                ),
              ],
            ),
            GoRoute(
              path: 'cart',
              builder: (context, state) => const CartPage(),
            ),
            GoRoute(
              path: 'checkout',
              builder: (context, state) => const CheckoutPage(),
            ),
            GoRoute(
              path: 'orders',
              builder: (context, state) => const OrdersPage(),
            ),
          ],
        ),
      ];

  @override
  List<Override> providerOverrides(Ref ref) => [];
}
