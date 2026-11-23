import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/provider/merchant/data/datasources/remote/supabase_merchant_dashboard_data_source.dart';
import 'package:delwaqty/features/provider/merchant/data/repositories/merchant_dashboard_repository_impl.dart';
import 'package:delwaqty/features/provider/merchant/domain/repositories/merchant_dashboard_repository.dart';
import 'package:delwaqty/features/provider/merchant/presentation/pages/merchant_dashboard_page.dart';
import 'package:delwaqty/features/provider/merchant/presentation/pages/merchant_orders_page.dart';
import 'package:delwaqty/features/provider/merchant/presentation/pages/merchant_pos_page.dart';
import 'package:delwaqty/features/provider/merchant/presentation/pages/merchant_drug_import_page.dart';
import 'package:delwaqty/features/provider/merchant/presentation/pages/merchant_products_page.dart';
import 'package:delwaqty/features/provider/merchant/presentation/pages/merchant_inventory_page.dart';
import 'package:delwaqty/features/provider/merchant/presentation/pages/merchant_storefront_page.dart';
import 'package:delwaqty/features/provider/merchant/presentation/pages/merchant_product_form_page.dart';
import 'package:delwaqty/features/provider/merchant/presentation/pages/merchant_product_modifiers_page.dart';
import 'package:delwaqty/features/provider/merchant/presentation/pages/merchant_offers_page.dart';
import 'package:delwaqty/features/provider/merchant/presentation/pages/merchant_branches_page.dart';
import 'package:delwaqty/features/provider/merchant/presentation/pages/merchant_reservations_page.dart';
import 'package:delwaqty/features/provider/merchant/presentation/pages/merchant_reviews_page.dart';
import 'package:delwaqty/features/provider/merchant/presentation/pages/provider_banners_page.dart';
import 'package:delwaqty/features/provider/availability/presentation/pages/provider_availability_page.dart';
import 'package:delwaqty/features/provider/verification/presentation/pages/provider_verification_page.dart';
import 'package:delwaqty/features/provider/documents/presentation/pages/provider_documents_page.dart';
import 'package:delwaqty/features/provider/services/presentation/pages/provider_services_page.dart';
import 'package:delwaqty/features/provider/capability/domain/provider_profile.dart';
import 'package:delwaqty/features/provider/capability/presentation/providers/provider_capability_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

final merchantDashboardRepositoryImplProvider =
    Provider<MerchantDashboardRepositoryImpl>(
      (ref) => MerchantDashboardRepositoryImpl(
        ref.watch(supabaseMerchantDashboardDataSourceProvider),
      ),
    );

final merchantDashboardRepositoryProvider =
    Provider<MerchantDashboardRepository>(
      (ref) => ref.watch(merchantDashboardRepositoryImplProvider),
    );

class MerchantModule extends FeatureModule {
  @override
  String get id => 'merchant';

  @override
  String name(BuildContext context) =>
      AppLocalizations.of(context).merchantDashboard;

  @override
  IconData? get icon => Icons.store_outlined;

  @override
  bool get isNavModule => true;

  @override
  int get navPriority => 10;

  @override
  Set<ModuleCapability> get capabilities => {ModuleCapability.hasNotifications};

  @override
  StatefulShellBranch? buildBranch() {
    return StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/merchant-dashboard',
          builder: (context, state) => const MerchantDashboardPage(),
          routes: [
            GoRoute(
              path: 'orders',
              builder: (context, state) => const MerchantOrdersPage(),
            ),
            GoRoute(
              path: 'drugs',
              builder: (context, state) => const MerchantDrugImportPage(),
            ),
            GoRoute(
              path: 'pos',
              builder: (context, state) => const MerchantPosPage(),
            ),
            GoRoute(
              path: 'storefront',
              builder: (context, state) => const MerchantStorefrontPage(),
            ),
            GoRoute(
              path: 'inventory',
              builder: (context, state) => const MerchantInventoryPage(),
            ),
            GoRoute(
              path: 'products',
              builder: (context, state) => const MerchantProductsPage(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const MerchantProductFormPage(),
                ),
                GoRoute(
                  path: ':id/edit',
                  builder: (context, state) => MerchantProductFormPage(
                    productId: state.pathParameters['id'],
                  ),
                ),
                GoRoute(
                  path: ':id/modifiers',
                  builder: (context, state) => MerchantProductModifiersPage(
                    productId: state.pathParameters['id']!,
                  ),
                ),
              ],
            ),
            GoRoute(
              path: 'offers',
              builder: (context, state) => const MerchantOffersPage(),
            ),
            GoRoute(
              path: 'banners',
              builder: (context, state) => const ProviderBannersPage(),
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
      ],
    );
  }

  @override
  List<DrawerEntry> get drawerEntries => [
    DrawerEntry(
      id: 'merchant-storefront',
      label: (ctx) => AppLocalizations.of(ctx).storefront,
      icon: Icons.storefront_outlined,
      onTap: (ctx, _) => ctx.push('/merchant-dashboard/storefront'),
    ),
    DrawerEntry(
      id: 'merchant-branches',
      label: (ctx) => AppLocalizations.of(ctx).branches,
      icon: Icons.location_city_outlined,
      onTap: (ctx, _) => ctx.push('/merchant-dashboard/branches'),
    ),
    DrawerEntry(
      id: 'provider-availability',
      label: (ctx) => AppLocalizations.of(ctx).availability,
      icon: Icons.schedule_outlined,
      onTap: (ctx, _) => ctx.push('/provider-availability'),
    ),
    DrawerEntry(
      id: 'provider-financial-center',
      label: (ctx) => AppLocalizations.of(ctx).financialCenter,
      icon: Icons.account_balance_wallet_outlined,
      onTap: (ctx, _) => ctx.push('/provider-financial-center'),
    ),
    DrawerEntry(
      id: 'merchant-reviews',
      label: (ctx) => AppLocalizations.of(ctx).reviews,
      icon: Icons.rate_review_outlined,
      onTap: (ctx, _) => ctx.push('/merchant-dashboard/reviews'),
    ),
    DrawerEntry(
      id: 'provider-support',
      label: (ctx) => AppLocalizations.of(ctx).support,
      icon: Icons.support_agent_rounded,
      position: DrawerPosition.footer,
      onTap: (ctx, _) => ctx.push('/support'),
    ),
  ];

  @override
  List<Override> providerOverrides(Ref ref) => [];

  @override
  List<RouteBase> get standaloneRoutes => [
    GoRoute(
      path: '/provider-availability',
      builder: (context, state) => const ProviderAvailabilityPage(),
    ),
    GoRoute(
      path: '/provider-verification',
      builder: (context, state) => const ProviderVerificationPage(),
    ),
    GoRoute(
      path: '/provider-documents',
      builder: (context, state) => const ProviderDocumentsPage(),
    ),
  ];
}

class ProviderOrdersNavModule extends FeatureModule {
  @override
  String get id => 'provider-orders-nav';

  @override
  String name(BuildContext context) => AppLocalizations.of(context).orders;

  @override
  IconData? get icon => Icons.receipt_long_rounded;

  @override
  bool get isNavModule => true;

  @override
  int get navPriority => 12;

  @override
  StatefulShellBranch? buildBranch() {
    return StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/provider-orders',
          builder: (context, state) => const MerchantOrdersPage(),
        ),
      ],
    );
  }
}

class ProviderProductsNavModule extends FeatureModule {
  @override
  String get id => 'provider-products-nav';

  @override
  String name(BuildContext context) => AppLocalizations.of(context).products;

  @override
  IconData? get icon => Icons.inventory_2_rounded;

  @override
  bool get isNavModule => true;

  @override
  int get navPriority => 15;

  @override
  StatefulShellBranch? buildBranch() {
    return StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/provider-products',
          builder: (context, state) => const MerchantProductsPage(),
        ),
      ],
    );
  }
}

/// Bookings tab for service-type accounts (home services, teachers,
/// doctors): service jobs or appointments, never table reservations.
class ProviderBookingsNavModule extends FeatureModule {
  @override
  String get id => 'provider-bookings-nav';

  @override
  String name(BuildContext context) =>
      AppLocalizations.of(context).serviceBookingsTitle;

  @override
  IconData? get icon => Icons.event_note_rounded;

  @override
  bool get isNavModule => true;

  @override
  int get navPriority => 13;

  @override
  StatefulShellBranch? buildBranch() {
    return StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/provider-bookings',
          builder: (context, state) => const _ProviderBookingsTab(),
        ),
      ],
    );
  }
}

/// "My services and prices" tab for service-type accounts.
class ProviderServicesNavModule extends FeatureModule {
  @override
  String get id => 'provider-services-nav';

  @override
  String name(BuildContext context) =>
      AppLocalizations.of(context).serviceBookingsTitle;

  @override
  IconData? get icon => Icons.handyman_rounded;

  @override
  bool get isNavModule => true;

  @override
  int get navPriority => 16;

  @override
  StatefulShellBranch? buildBranch() {
    return StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/provider-services',
          builder: (context, state) => const ProviderServicesPage(),
        ),
      ],
    );
  }
}

/// Cashier tab for account types that sell at a counter.
class ProviderCashierNavModule extends FeatureModule {
  @override
  String get id => 'provider-cashier-nav';

  @override
  String name(BuildContext context) => AppLocalizations.of(context).posCashier;

  @override
  IconData? get icon => Icons.point_of_sale_rounded;

  @override
  bool get isNavModule => true;

  @override
  int get navPriority => 17;

  @override
  StatefulShellBranch? buildBranch() {
    return StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/provider-cashier',
          builder: (context, state) => const MerchantPosPage(),
        ),
      ],
    );
  }
}

class _ProviderBookingsTab extends ConsumerWidget {
  const _ProviderBookingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(providerProfileProvider);
    final lang = AppLocalizations.of(context);
    return MerchantReservationsPage(
      mode: ReservationsMode.services,
      showBack: false,
      title: profile.label(ProviderLabel.bookingsTitle, lang),
    );
  }
}
