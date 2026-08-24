import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/core/auth/platform_capabilities.dart';
import 'package:delwaqty/features/driver/domain/repositories/driver_repository.dart';
import 'package:delwaqty/features/driver/domain/entities/driver_profile.dart';
import 'package:delwaqty/features/driver/domain/entities/driver_delivery.dart';
import 'package:delwaqty/features/driver/data/datasources/remote/supabase_driver_data_source.dart';
import 'package:delwaqty/features/driver/data/datasources/remote/supabase_driver_platform_data_source.dart';
import 'package:delwaqty/features/driver/data/repositories/driver_repository_impl.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/driver/presentation/pages/driver_dashboard_page.dart';
import 'package:delwaqty/features/driver/presentation/pages/driver_earnings_page.dart';
import 'package:delwaqty/features/driver/presentation/pages/driver_onboarding_page.dart';
import 'package:delwaqty/features/driver/presentation/pages/vehicle_management_page.dart';
import 'package:delwaqty/features/driver/presentation/pages/document_management_page.dart';
import 'package:delwaqty/features/driver/financial/presentation/pages/driver_financial_center_page.dart';
import 'package:delwaqty/features/driver/financial/presentation/pages/driver_topup_request_page.dart';
import 'package:delwaqty/features/driver/presentation/pages/driver_delivery_detail_page.dart';

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
  final profile = await repo.getProfile(userId);
  if (profile != null) return profile;
  // Owner bypass: a global owner (users.role='owner') is authorized to operate
  // Delivery without a dedicated driver registration row. This keeps the Owner
  // inside the Delivery app even when the provisioning RPC has not been applied
  // to the live database yet. Backend RLS remains authoritative for real ops.
  final isOwner = await isOwnerByRole(Supabase.instance.client, userId);
  if (isOwner) {
    return DriverProfile(
      id: userId,
      userId: userId,
      rating: 5.0,
      createdAt: DateTime.now(),
      onboardingCompleted: true,
      verificationStatus: 'approved',
    );
  }
  return null;
});

final availableDeliveriesProvider = FutureProvider<List<DriverDelivery>>((ref) async {
  final repo = ref.watch(driverRepositoryProvider);
  return repo.getAvailableDeliveries();
});

class DriverModule extends FeatureModule {
  @override
  String get id => 'driver';

  @override
  String name(BuildContext context) => AppLocalizations.of(context).delivery;

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
    GoRoute(
      path: '/driver/financial-center',
      builder: (context, state) => const DriverFinancialCenterPage(),
      routes: [
        GoRoute(
          path: 'topup',
          builder: (context, state) => const DriverTopupRequestPage(),
        ),
      ],
    ),
    GoRoute(
      path: '/driver/delivery/:id',
      builder: (context, state) =>
          DriverDeliveryDetailPage(id: state.pathParameters['id']!),
    ),
  ];
}
