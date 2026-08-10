import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/merchant/data/datasources/remote/supabase_merchant_dashboard_data_source.dart';
import 'package:delwaqty/features/merchant/data/repositories/merchant_dashboard_repository_impl.dart';
import 'package:delwaqty/features/merchant/domain/repositories/merchant_dashboard_repository.dart';
import 'package:delwaqty/features/merchant/presentation/pages/merchant_dashboard_page.dart';
import 'package:delwaqty/features/merchant/presentation/pages/merchant_orders_page.dart';
import 'package:delwaqty/features/merchant/presentation/pages/merchant_products_page.dart';
import 'package:delwaqty/features/merchant/presentation/pages/merchant_product_form_page.dart';
import 'package:delwaqty/features/merchant/presentation/pages/merchant_offers_page.dart';
import 'package:delwaqty/features/merchant/presentation/pages/merchant_branches_page.dart';
import 'package:delwaqty/features/merchant/presentation/pages/merchant_reservations_page.dart';
import 'package:delwaqty/features/merchant/presentation/pages/merchant_reviews_page.dart';

final merchantDashboardRepositoryImplProvider =
    Provider<MerchantDashboardRepositoryImpl>(
      (ref) => MerchantDashboardRepositoryImpl(
        ref.watch(supabaseMerchantDashboardDataSourceProvider),
      ),
    );

final merchantDashboardRepositoryProvider = Provider<MerchantDashboardRepository>(
  (ref) => ref.watch(merchantDashboardRepositoryImplProvider),
);

class MerchantModule extends FeatureModule {
  @override
  String get id => 'merchant';

  @override
  String name(BuildContext context) => 'Merchant Dashboard';

  @override
  IconData? get icon => Icons.store_outlined;

  @override
  bool get isNavModule => false;

  @override
  int get navPriority => 80;

  @override
  Set<ModuleCapability> get capabilities => {
    ModuleCapability.hasNotifications,
  };

  @override
  List<RouteBase> get standaloneRoutes => [
    GoRoute(
      path: '/merchant-dashboard',
      builder: (context, state) => const MerchantDashboardPage(),
      routes: [
        GoRoute(
          path: 'orders',
          builder: (context, state) => const MerchantOrdersPage(),
        ),
        GoRoute(
          path: 'products',
          builder: (context, state) => const MerchantProductsPage(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) =>
                  const MerchantProductFormPage(),
            ),
            GoRoute(
              path: ':id/edit',
              builder: (context, state) => MerchantProductFormPage(
                productId: state.pathParameters['id'],
              ),
            ),
          ],
        ),
        GoRoute(
          path: 'offers',
          builder: (context, state) => const MerchantOffersPage(),
        ),
        GoRoute(
          path: 'branches',
          builder: (context, state) => const MerchantBranchesPage(),
        ),
        GoRoute(
          path: 'reservations',
          builder: (context, state) => const MerchantReservationsPage(),
        ),
        GoRoute(
          path: 'reviews',
          builder: (context, state) => const MerchantReviewsPage(),
        ),
      ],
    ),
  ];

  @override
  List<Override> providerOverrides(Ref ref) => [];
}
