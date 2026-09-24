import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_category.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_provider.dart';
import 'package:delwaqty/features/customer/home_services/presentation/pages/home_services_page.dart';
import 'package:delwaqty/features/customer/home_services/presentation/pages/service_booking_page.dart';
import 'package:delwaqty/features/customer/home_services/presentation/pages/service_providers_page.dart';
import 'package:delwaqty/features/customer/home_services/presentation/pages/service_reviews_page.dart';

class HomeServicesModule extends FeatureModule {
  HomeServicesModule();

  @override
  String get id => 'home_services';

  @override
  String name(BuildContext context) => 'Home Services';

  @override
  IconData? get icon => Icons.home_repair_service_rounded;

  @override
  bool get isNavModule => false;

  @override
  int get navPriority => 0;

  @override
  List<RouteBase> get standaloneRoutes => [
    GoRoute(
      path: '/home-services',
      name: 'home-services',
      builder: (context, state) => const HomeServicesPage(),
    ),
    GoRoute(
      path: '/home-services/category/:categoryType',
      name: 'home-services-category',
      builder: (context, state) {
        final categoryTypeName = state.pathParameters['categoryType']!;
        final categoryType = ServiceCategoryType.values.firstWhere(
          (e) => e.name == categoryTypeName,
          orElse: () => ServiceCategoryType.other,
        );
        final provider = state.extra is ServiceProvider
            ? state.extra as ServiceProvider
            : null;
        return ServiceBookingPage(
          categoryType: categoryType,
          preselectedProvider: provider,
        );
      },
    ),
    GoRoute(
      path: '/home-services/providers/:categoryType',
      name: 'home-services-providers',
      builder: (context, state) {
        final name = state.pathParameters['categoryType']!;
        final type = ServiceCategoryType.values.firstWhere(
          (e) => e.name == name,
          orElse: () => ServiceCategoryType.plumbing,
        );
        return ServiceProvidersPage(initialType: type);
      },
    ),
    GoRoute(
      path: '/home-services/reviews/:categoryType',
      name: 'home-services-reviews',
      builder: (context, state) => ServiceReviewsPage(
        categoryType: state.pathParameters['categoryType']!,
        providerId: state.extra is ServiceProvider
            ? (state.extra as ServiceProvider).id
            : null,
        providerName: state.extra is ServiceProvider
            ? (state.extra as ServiceProvider).name
            : null,
      ),
    ),
  ];
}
