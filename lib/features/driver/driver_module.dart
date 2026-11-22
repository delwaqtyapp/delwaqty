import 'package:delwaqty/features/driver/presentation/pages/driver_delivery_hub_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/core/auth/platform_capabilities.dart';
import 'package:delwaqty/features/driver/domain/repositories/driver_repository.dart';
import 'package:delwaqty/features/driver/domain/entities/driver_profile.dart';
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
import 'package:delwaqty/features/driver/presentation/pages/driver_access_page.dart';
import 'package:delwaqty/features/driver/presentation/pages/driver_delivery_detail_page.dart';

final supabaseDriverRepositoryImplProvider = Provider<DriverRepositoryImpl>((
  ref,
) {
  return DriverRepositoryImpl(
    ref.watch(supabaseDriverDataSourceProvider),
    ref.watch(supabaseDriverPlatformDataSourceProvider),
  );
});

final driverRepositoryProvider = Provider<DriverRepository>(
  (ref) => ref.watch(supabaseDriverRepositoryImplProvider),
);

final driverProfileProvider = FutureProvider.family<DriverProfile?, String>((
  ref,
  userId,
) async {
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

class DriverModule extends FeatureModule {
  @override
  String get id => 'driver';

  @override
  String name(BuildContext context) =>
      AppLocalizations.of(context).driverDashboard;

  @override
  IconData? get icon => Icons.grid_view_rounded;

  @override
  bool get isNavModule => true;

  @override
  int get navPriority => 10;

  @override
  StatefulShellBranch? buildBranch() {
    return StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/driver',
          builder: (context, state) => const DriverDashboardPage(),
        ),
      ],
    );
  }

  @override
  Set<ModuleCapability> get capabilities => {
    ModuleCapability.requiresMap,
    ModuleCapability.requiresDelivery,
  };

  @override
  List<DrawerEntry> get drawerEntries => [
    DrawerEntry(
      id: 'driver-dashboard',
      label: (ctx) => AppLocalizations.of(ctx).driverDashboard,
      icon: Icons.delivery_dining_outlined,
      onTap: (ctx, _) => ctx.go('/driver'),
    ),
    DrawerEntry(
      id: 'driver-delivery-hub',
      label: (ctx) => AppLocalizations.of(ctx).deliveryHub,
      icon: Icons.hub_outlined,
      onTap: (ctx, _) => ctx.push('/driver/hub'),
    ),
    DrawerEntry(
      id: 'driver-financial-center',
      label: (ctx) => AppLocalizations.of(ctx).financialCenter,
      icon: Icons.account_balance_wallet_outlined,
      onTap: (ctx, _) => ctx.push('/driver/financial-center'),
    ),
    DrawerEntry(
      id: 'driver-access',
      label: (ctx) => AppLocalizations.of(ctx).deliveryAccess,
      icon: Icons.shield_outlined,
      onTap: (ctx, _) => ctx.push('/driver/access'),
    ),
    DrawerEntry(
      id: 'driver-settings',
      label: (ctx) => AppLocalizations.of(ctx).settings,
      icon: Icons.settings_outlined,
      position: DrawerPosition.settings,
      onTap: (ctx, _) => ctx.push('/settings/privacy-security'),
    ),
    DrawerEntry(
      id: 'driver-support',
      label: (ctx) => AppLocalizations.of(ctx).support,
      icon: Icons.support_agent_rounded,
      position: DrawerPosition.footer,
      onTap: (ctx, _) => ctx.push('/support'),
    ),
  ];

  @override
  List<RouteBase> get standaloneRoutes => [
    GoRoute(
      path: '/driver/access',
      builder: (context, state) => const DriverAccessPage(),
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
      path: '/driver/delivery/:id',
      builder: (context, state) =>
          DriverDeliveryDetailPage(id: state.pathParameters['id']!),
    ),
  ];
}

/// Delivery hub (طلبات التوصيل) as a bottom-nav destination (owner D-1:
/// the driver app had no bottom nav on the dashboard).
class DriverHubNavModule extends FeatureModule {
  @override
  String get id => 'driver-hub-nav';

  @override
  String name(BuildContext context) => AppLocalizations.of(context).deliveryHub;

  @override
  IconData? get icon => Icons.local_shipping_rounded;

  @override
  bool get isNavModule => true;

  @override
  int get navPriority => 12;

  @override
  StatefulShellBranch? buildBranch() {
    return StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/driver/hub',
          builder: (context, state) => const DriverDeliveryHubPage(),
        ),
      ],
    );
  }
}

/// Driver financial center as a bottom-nav destination (the one money
/// surface in the driver app).
class DriverFinancialNavModule extends FeatureModule {
  @override
  String get id => 'driver-financial-nav';

  @override
  String name(BuildContext context) =>
      AppLocalizations.of(context).financialCenter;

  @override
  IconData? get icon => Icons.account_balance_wallet_outlined;

  @override
  bool get isNavModule => true;

  @override
  int get navPriority => 15;

  @override
  StatefulShellBranch? buildBranch() {
    return StatefulShellBranch(
      routes: [
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
      ],
    );
  }
}
