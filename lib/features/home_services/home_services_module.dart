import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/home_services/domain/entities/service_category.dart';
import 'package:delwaqty/features/home_services/presentation/pages/home_services_page.dart';
import 'package:delwaqty/features/home_services/presentation/pages/service_booking_page.dart';

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
            return ServiceBookingPage(categoryType: categoryType);
          },
        ),
      ];
}
