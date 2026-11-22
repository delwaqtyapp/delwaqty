import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/core/module/shell_customization.dart';
import 'package:delwaqty/core/module/feature_registry.dart';
import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/provider/availability/presentation/providers/provider_availability_providers.dart';
import 'package:delwaqty/features/provider/capability/domain/provider_capability.dart';
import 'package:delwaqty/features/provider/capability/domain/provider_profile.dart';
import 'package:delwaqty/features/provider/capability/presentation/providers/provider_capability_providers.dart';
import 'package:delwaqty/features/provider/merchant/domain/entities/merchant_order.dart';
import 'package:delwaqty/features/provider/merchant/domain/entities/merchant_stats.dart';
import 'package:delwaqty/features/provider/merchant/domain/repositories/merchant_dashboard_repository.dart';
import 'package:delwaqty/features/provider/merchant/merchant_module.dart';
import 'package:delwaqty/features/provider/merchant/presentation/pages/merchant_dashboard_page.dart';
import 'package:delwaqty/features/provider/merchant/presentation/pages/merchant_storefront_page.dart';
import 'package:delwaqty/features/provider/merchant/presentation/providers/merchant_providers.dart';
import 'package:delwaqty/features/provider/services/domain/provider_service_info.dart';
import 'package:delwaqty/features/provider/services/presentation/providers/provider_service_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/provider/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Router-level tests through the real `providerGoRouterProvider`: redirect,
/// deep links, notification links, loading/error guards and the owner
/// dashboard action. The router, guard and dashboard are real; the other
/// branch pages are markers.

class _FakeAuth extends AuthStateNotifier {
  _FakeAuth(this._initial);
  AuthState _initial;

  @override
  AuthState build() => _initial;

  void set(AuthState next) => state = next;
}

class _FakeDashboardRepo implements MerchantDashboardRepository {
  @override
  Future<MerchantStats> getMerchantStats(String merchantId) async =>
      const MerchantStats();

  @override
  Future<List<MerchantOrder>> getMerchantOrders(
    String merchantId, {
    String? status,
    int limit = 20,
    int offset = 0,
  }) async => const [];

  @override
  Future<void> updateOrderStatus(String orderId, String status) async {}

  @override
  Future<List<Map<String, dynamic>>> getMerchantProducts(
    String merchantId,
  ) async => const [];

  @override
  Future<void> createProduct(
    String merchantId,
    Map<String, dynamic> product,
  ) async {}

  @override
  Future<void> updateProduct(
    String productId,
    Map<String, dynamic> product,
  ) async {}

  @override
  Future<void> deleteProduct(String productId) async {}
}

Widget _marker(String path) => Scaffold(
  body: Center(child: Text('route:$path', key: ValueKey('page'))),
);

class _NavTab extends FeatureModule {
  _NavTab(this.id, this.path, this.priority, {this.builder});
  @override
  final String id;
  @override
  final String path;
  @override
  final int priority;
  final Widget Function()? builder;
  @override
  IconData get icon => Icons.circle;
  @override
  String name(BuildContext context) => id;
  @override
  bool get isNavModule => true;
  @override
  int get navPriority => priority;
  @override
  StatefulShellBranch buildBranch() => StatefulShellBranch(
    routes: [
      GoRoute(
        path: path,
        builder: (context, state) => builder?.call() ?? _marker(path),
      ),
    ],
  );
}

class _Standalone extends FeatureModule {
  _Standalone(this.paths);
  final List<String> paths;
  @override
  String get id => 'test-standalone';
  @override
  String name(BuildContext context) => id;
  @override
  IconData get icon => Icons.circle;
  @override
  bool get isNavModule => false;
  @override
  int get navPriority => 99;
  @override
  List<RouteBase> get standaloneRoutes => [
    for (final p in paths) GoRoute(path: p, builder: (_, _) => _marker(p)),
  ];
}

void main() {
  setUpAll(() {
    FeatureRegistry.instance
      ..registerAll([
        _NavTab(
          ProviderTabIds.dashboard,
          '/merchant-dashboard',
          10,
          builder: () => const MerchantDashboardPage(),
        ),
        _NavTab(ProviderTabIds.orders, '/provider-orders', 12),
        _NavTab(ProviderTabIds.bookings, '/provider-bookings', 13),
        _NavTab(ProviderTabIds.products, '/provider-products', 15),
        _NavTab(ProviderTabIds.services, '/provider-services', 16),
        _NavTab(ProviderTabIds.cashier, '/provider-cashier', 17),
        _NavTab(ProviderTabIds.financial, '/provider-financial-center', 20),
        _Standalone([
          '/splash',
          '/welcome',
          '/login',
          '/register',
          '/forgot-password',
          '/pending-verification',
          '/merchant-dashboard/products',
          '/merchant-dashboard/pos',
          '/merchant-dashboard/drugs',
          '/merchant-dashboard/reviews',
          '/merchant-dashboard/reservations',
        ]),
      ])
      ..freeze();
  });

  User user(String id, {String role = 'provider'}) => User(
    id: id,
    email: '$id@test.dev',
    role: role,
    createdAt: DateTime(2026),
  );

  List<Override> overridesFor(
    _FakeAuth fakeAuth,
    ProviderProfile profile, {
    ProviderProfilesState profilesState = const ProviderProfilesState(),
  }) => [
    authStateProvider.overrideWith(() => fakeAuth),
    providerProfileProvider.overrideWithValue(profile),
    shellNavConfigProvider.overrideWithValue(profile.toShellNavConfig()),
    providerCapabilitiesProvider.overrideWithValue(profile.capabilities),
    providerProfilesProvider.overrideWith((ref) async => profilesState),
    providerMerchantIdProvider.overrideWith((ref) async => ''),
    merchantDashboardRepositoryProvider.overrideWithValue(_FakeDashboardRepo()),
    providerAvailabilityProvider.overrideWith(
      (ref) async => <String, dynamic>{},
    ),
    storefrontProvider.overrideWith((ref) async => const StorefrontData()),
    providerServiceInfoProvider.overrideWith(
      (ref) async => const <ProviderServiceInfo>[],
    ),
  ];

  (ProviderContainer, _FakeAuth) makeContainer(
    ProviderProfile profile, {
    AuthState auth = const AuthState.unauthenticated(),
    ProviderProfilesState profilesState = const ProviderProfilesState(),
  }) {
    final fakeAuth = _FakeAuth(auth);
    final container = ProviderContainer(
      overrides: overridesFor(fakeAuth, profile, profilesState: profilesState),
    );
    addTearDown(container.dispose);
    return (container, fakeAuth);
  }

  (ProviderContainer, _FakeAuth) authedContainer(
    ProviderProfile profile, {
    ProviderProfilesState profilesState = const ProviderProfilesState(),
  }) => makeContainer(
    profile,
    auth: AuthState.authenticated(user: user('uid-router')),
    profilesState: profilesState,
  );

  /// Bounded pump: the dashboard's loading gate spins forever, so
  /// pumpAndSettle can time out. Router transitions need only a few frames.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<GoRouter> pumpApp(WidgetTester tester, ProviderContainer c) async {
    final router = c.read(providerGoRouterProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await settle(tester);
    return router;
  }

  String location(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.path;

  Future<void> expectStays(
    WidgetTester tester,
    GoRouter router,
    String path,
  ) async {
    router.go(path);
    await settle(tester);
    expect(location(router), path, reason: '$path should stay');
  }

  Future<void> expectBounces(
    WidgetTester tester,
    GoRouter router,
    String path,
  ) async {
    router.go(path);
    await settle(tester);
    expect(location(router), '/merchant-dashboard', reason: '$path bounce');
  }

  group('capability guard through the real providerGoRouterProvider', () {
    testWidgets('plumber: shop deep links bounce, service surfaces open', (
      tester,
    ) async {
      final (c, _) = authedContainer(
        ProviderProfile.forCategory(ProviderCategory.homeServices),
      );
      final router = await pumpApp(tester, c);

      await expectBounces(tester, router, '/provider-cashier');
      await expectBounces(tester, router, '/provider-products');
      await expectBounces(tester, router, '/merchant-dashboard/pos');
      await expectBounces(tester, router, '/merchant-dashboard/drugs');
      await expectBounces(tester, router, '/merchant-dashboard/products');
      await expectBounces(tester, router, '/provider-orders');

      await expectStays(tester, router, '/provider-services');
      await expectStays(tester, router, '/provider-bookings');
      await expectStays(tester, router, '/provider-financial-center');
      expect(find.text('route:/provider-financial-center'), findsOneWidget);
    });

    testWidgets('notification deep link (query string) follows the guard', (
      tester,
    ) async {
      final (c, _) = authedContainer(
        ProviderProfile.forCategory(ProviderCategory.homeServices),
      );
      final router = await pumpApp(tester, c);

      // Push-style link with a tracking query: still the cashier path.
      router.go('/provider-cashier?source=push_notification&id=42');
      await settle(tester);
      expect(location(router), '/merchant-dashboard');

      router.go('/provider-bookings?source=push_notification&id=42');
      await settle(tester);
      expect(location(router), '/provider-bookings');
      expect(find.text('route:/provider-bookings'), findsOneWidget);
    });

    testWidgets('restaurant: products open, services view bounces', (
      tester,
    ) async {
      final (c, _) = authedContainer(
        ProviderProfile.forCategory(ProviderCategory.restaurant),
      );
      final router = await pumpApp(tester, c);

      await expectStays(tester, router, '/merchant-dashboard/products');
      await expectStays(tester, router, '/merchant-dashboard/reservations');
      await expectStays(tester, router, '/provider-cashier');
      expect(find.text('route:/provider-cashier'), findsOneWidget);
      await expectBounces(tester, router, '/provider-services');
      await expectBounces(tester, router, '/merchant-dashboard/drugs');
    });

    testWidgets('owner: every surface opens, including /provider-services', (
      tester,
    ) async {
      final (c, _) = authedContainer(
        ProviderProfile.forCategory(ProviderCategory.owner),
      );
      final router = await pumpApp(tester, c);

      await expectStays(tester, router, '/provider-services');
      await expectStays(tester, router, '/provider-cashier');
      await expectStays(tester, router, '/provider-bookings');
      await expectStays(tester, router, '/merchant-dashboard/drugs');
      await expectStays(tester, router, '/merchant-dashboard/reviews');
      expect(find.text('route:/merchant-dashboard/reviews'), findsOneWidget);
    });

    testWidgets('loading profile fails closed but keeps dashboard and money', (
      tester,
    ) async {
      final (c, _) = authedContainer(ProviderProfile.loading());
      final router = await pumpApp(tester, c);

      await expectBounces(tester, router, '/provider-services');
      await expectBounces(tester, router, '/provider-orders');
      await expectBounces(tester, router, '/provider-cashier');
      await expectStays(tester, router, '/merchant-dashboard');
      await expectStays(tester, router, '/provider-financial-center');
    });

    testWidgets('failed profile lookup fails closed the same way', (
      tester,
    ) async {
      final (c, _) = authedContainer(ProviderProfile.failed());
      final router = await pumpApp(tester, c);

      await expectBounces(tester, router, '/provider-services');
      await expectBounces(tester, router, '/provider-bookings');
      await expectStays(tester, router, '/merchant-dashboard');
      await expectStays(tester, router, '/provider-financial-center');
    });

    testWidgets('account switch kicks the user out of a hidden surface', (
      tester,
    ) async {
      // Account A (restaurant) opens the cashier, then the same session
      // resolves to account B (plumber): the open cashier must close.
      final restaurant = ProviderProfile.forCategory(
        ProviderCategory.restaurant,
      );
      final (c, auth) = authedContainer(restaurant);
      final router = await pumpApp(tester, c);

      await expectStays(tester, router, '/provider-cashier');

      final plumber = ProviderProfile.forCategory(
        ProviderCategory.homeServices,
      );
      c.updateOverrides(overridesFor(auth, plumber));
      await settle(tester);

      expect(location(router), '/merchant-dashboard');
    });
  });

  group('auth redirects', () {
    testWidgets('signed out users land on welcome', (tester) async {
      final (c, _) = makeContainer(
        ProviderProfile.forCategory(ProviderCategory.restaurant),
      );
      final router = await pumpApp(tester, c);

      router.go('/provider-services');
      await settle(tester);
      expect(location(router), '/welcome');
      expect(find.text('route:/welcome'), findsOneWidget);
    });

    testWidgets('signed in users on an auth route go to the dashboard', (
      tester,
    ) async {
      final (c, _) = authedContainer(
        ProviderProfile.forCategory(ProviderCategory.restaurant),
      );
      final router = await pumpApp(tester, c);

      router.go('/login');
      await settle(tester);
      expect(location(router), '/merchant-dashboard');
      expect(find.byType(MerchantDashboardPage), findsOneWidget);
    });

    testWidgets('pending verification is held on its page', (tester) async {
      final (c, _) = makeContainer(
        ProviderProfile.loading(),
        auth: const AuthState.pendingVerification(),
      );
      final router = await pumpApp(tester, c);

      router.go('/merchant-dashboard');
      await settle(tester);
      expect(location(router), '/pending-verification');
      expect(find.text('route:/pending-verification'), findsOneWidget);
    });
  });

  group('owner dashboard action (#88)', () {
    testWidgets('tapping My services & prices reaches /provider-services', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final (c, _) = makeContainer(
        ProviderProfile.forCategory(ProviderCategory.owner),
        auth: AuthState.authenticated(user: user('owner-uid', role: 'owner')),
        profilesState: const ProviderProfilesState(
          isOwner: true,
          activeCategory: 'owner',
        ),
      );
      final router = await pumpApp(tester, c);

      router.go('/merchant-dashboard');
      await settle(tester);
      expect(find.byType(MerchantDashboardPage), findsOneWidget);

      final action = find.text('My services & prices');
      await tester.ensureVisible(action);
      await settle(tester);
      await tester.tap(action);
      await settle(tester);

      // No bounce: the guard lets the owner straight through.
      expect(location(router), '/provider-services');
      expect(find.text('route:/provider-services'), findsOneWidget);
    });
  });
}
