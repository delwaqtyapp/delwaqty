import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/driver/domain/repositories/driver_repository.dart';
import 'package:delwaqty/features/driver/domain/entities/driver_profile.dart';
import 'package:delwaqty/features/driver/domain/entities/driver_delivery.dart';
import 'package:delwaqty/features/driver/data/datasources/remote/supabase_driver_data_source.dart';
import 'package:delwaqty/features/driver/data/datasources/remote/supabase_driver_platform_data_source.dart';
import 'package:delwaqty/features/driver/data/repositories/driver_repository_impl.dart';
import 'package:delwaqty/features/driver/presentation/pages/driver_dashboard_page.dart';
import 'package:delwaqty/features/driver/presentation/pages/driver_earnings_page.dart';
import 'package:delwaqty/features/driver/presentation/pages/driver_onboarding_page.dart';
import 'package:delwaqty/features/driver/presentation/pages/vehicle_management_page.dart';
import 'package:delwaqty/features/driver/presentation/pages/document_management_page.dart';

final supabaseDriverRepositoryImplProvider = Provider<DriverRepositoryImpl>((ref) {
  return DriverRepositoryImpl(
    ref.watch(supabaseDriverDataSourceProvider),
    ref.watch(supabaseDriverPlatformDataSourceProvider),
  );
});

final driverRepositoryProvider = Provider<DriverRepository>(
  (ref) => ref.watch(supabaseDriverRepositoryImplProvider),
);

final driverProfileProvider = FutureProvider.family<DriverProfile?, String>((ref, userId) async {
  final repo = ref.watch(driverRepositoryProvider);
  return repo.getProfile(userId);
});

final availableDeliveriesProvider = FutureProvider<List<DriverDelivery>>((ref) async {
  final repo = ref.watch(driverRepositoryProvider);
  return repo.getAvailableDeliveries();
});

class DriverModule extends FeatureModule {
  @override
  String get id => 'driver';

  @override
  String name(BuildContext context) => 'Driver';

  @override
  IconData? get icon => Icons.delivery_dining_outlined;

  @override
  bool get isNavModule => false;

  @override
  int get navPriority => 0;

  @override
  Set<ModuleCapability> get capabilities => {ModuleCapability.requiresMap, ModuleCapability.requiresDelivery};

  @override
  List<RouteBase> get standaloneRoutes => [
    GoRoute(
      path: '/driver',
      builder: (context, state) => const DriverDashboardPage(),
    ),
    GoRoute(
      path: '/driver/onboarding/:userId',
      builder: (context, state) => const DriverOnboardingPage(),
    ),
    GoRoute(
      path: '/driver/earnings',
      builder: (context, state) => const DriverEarningsPage(),
    ),
    GoRoute(
      path: '/driver/vehicles',
      builder: (context, state) => const VehicleManagementPage(),
    ),
    GoRoute(
      path: '/driver/documents',
      builder: (context, state) => const DocumentManagementPage(),
    ),
  ];
}
