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
import 'package:delwaqty/data/repositories/merchant_repository_impl.dart';
import 'package:delwaqty/data/repositories/catalog_category_repository_impl.dart';
import 'package:delwaqty/data/repositories/product_repository_impl.dart';
import 'package:delwaqty/data/repositories/favorite_repository_impl.dart';
import 'package:delwaqty/data/repositories/order_repository_impl.dart';
import 'package:delwaqty/data/repositories/local_cart_repository.dart';
import 'package:delwaqty/data/datasources/remote/supabase_product_data_source.dart';
import 'package:delwaqty/data/datasources/remote/supabase_favorite_data_source.dart';
import 'package:delwaqty/data/datasources/remote/supabase_order_data_source.dart';
import 'package:delwaqty/data/datasources/remote/supabase_review_data_source.dart';
import 'package:delwaqty/data/datasources/remote/supabase_coupon_data_source.dart';
import 'package:delwaqty/data/repositories/review_repository_impl.dart';
import 'package:delwaqty/data/repositories/coupon_repository_impl.dart';
import 'package:delwaqty/features/commerce/presentation/pages/commerce_discovery_page.dart';
import 'package:delwaqty/features/commerce/presentation/pages/merchant_detail_page.dart';
import 'package:delwaqty/features/commerce/presentation/pages/product_detail_page.dart';
import 'package:delwaqty/features/commerce/presentation/pages/cart_page.dart';
import 'package:delwaqty/features/commerce/presentation/pages/checkout_page.dart';
import 'package:delwaqty/features/commerce/presentation/pages/orders_page.dart';
import 'package:delwaqty/features/commerce/presentation/pages/search_page.dart';
import 'package:delwaqty/features/commerce/presentation/pages/order_tracking_page.dart';
import 'package:delwaqty/features/commerce/presentation/pages/order_completed_page.dart';

// ─── Repository Providers ───

final merchantRepositoryProvider = Provider<MerchantRepository>(
  (ref) => ref.watch(merchantRepositoryImplProvider),
);

final productRepositoryImplProvider = Provider<ProductRepositoryImpl>((ref) {
  return ProductRepositoryImpl(ref.watch(supabaseProductDataSourceProvider));
});

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ref.watch(productRepositoryImplProvider),
);

final catalogCategoryRepositoryProvider = Provider<CatalogCategoryRepository>(
  (ref) => ref.watch(catalogCategoryRepositoryImplProvider),
);

final cartRepositoryProvider = Provider<CartRepository>(
  (ref) => ref.watch(localCartRepositoryProvider),
);

final orderRepositoryImplProvider = Provider<OrderRepositoryImpl>((ref) {
  return OrderRepositoryImpl(ref.watch(supabaseOrderDataSourceProvider));
});

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => ref.watch(orderRepositoryImplProvider),
);

final reviewRepositoryImplProvider = Provider<ReviewRepositoryImpl>((ref) {
  return ReviewRepositoryImpl(ref.watch(supabaseReviewDataSourceProvider));
});

final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => ref.watch(reviewRepositoryImplProvider),
);

final couponRepositoryImplProvider = Provider<CouponRepositoryImpl>((ref) {
  return CouponRepositoryImpl(ref.watch(supabaseCouponDataSourceProvider));
});

final couponRepositoryProvider = Provider<CouponRepository>(
  (ref) => ref.watch(couponRepositoryImplProvider),
);

final favoriteRepositoryImplProvider = Provider<FavoriteRepositoryImpl>((ref) {
  return FavoriteRepositoryImpl(ref.watch(supabaseFavoriteDataSourceProvider));
});

final favoriteRepositoryProvider = Provider<FavoriteRepository>(
  (ref) => ref.watch(favoriteRepositoryImplProvider),
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
  Set<ModuleCapability> get capabilities => {ModuleCapability.hasDeepLinks};

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
          builder: (context, state) =>
              MerchantDetailPage(merchantId: state.pathParameters['id']!),
          routes: [
            GoRoute(
              path: 'product/:productId',
              builder: (context, state) => ProductDetailPage(
                productId: state.pathParameters['productId']!,
                merchantId: state.pathParameters['id']!,
                merchantName: (state.extra as String?) ?? '',
              ),
            ),
          ],
        ),
        GoRoute(path: 'cart', builder: (context, state) => const CartPage()),
        GoRoute(
          path: 'checkout',
          builder: (context, state) => const CheckoutPage(),
        ),
        GoRoute(
          path: 'search',
          builder: (context, state) => const SearchPage(),
        ),
        GoRoute(
          path: 'orders',
          builder: (context, state) => const OrdersPage(),
        ),
        GoRoute(
          path: 'order-completed/:orderId',
          builder: (context, state) =>
              OrderCompletedPage(orderId: state.pathParameters['orderId']!),
        ),
        GoRoute(
          path: 'orders/:orderId/tracking',
          builder: (context, state) =>
              OrderTrackingPage(orderId: state.pathParameters['orderId']!),
        ),
      ],
    ),
  ];

  @override
  List<Override> providerOverrides(Ref ref) => [];
}
