import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:delwaqty/core/module/feature_registry.dart';
import 'package:delwaqty/core/theme/app_icons.dart';
import 'package:delwaqty/core/theme/theme_mode_provider.dart';
import 'package:delwaqty/customer/module_registry.dart';
import 'package:delwaqty/data/datasources/local/shared_preferences_service.dart';
import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/domain/repositories/profile_repository.dart';
import 'package:delwaqty/domain/usecases/profile/profile_usecases.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/campaigns/domain/entities/campaign.dart';
import 'package:delwaqty/features/_shared/campaigns/presentation/campaign_providers.dart';
import 'package:delwaqty/features/_shared/complaints/domain/entities/complaint.dart';
import 'package:delwaqty/features/_shared/complaints/domain/repositories/complaints_repository.dart';
import 'package:delwaqty/features/_shared/complaints/presentation/complaints_providers.dart';
import 'package:delwaqty/features/_shared/notifications/notifications_module.dart';
import 'package:delwaqty/features/customer/commerce/commerce_module.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/cart.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/order.dart';
import 'package:delwaqty/features/customer/commerce/domain/repositories/order_repository.dart';
import 'package:delwaqty/features/customer/home/domain/entities/platform_category.dart';
import 'package:delwaqty/features/customer/home/domain/home_domain.dart';
import 'package:delwaqty/features/customer/location/presentation/providers/location_provider.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/app_shell.dart';
import 'package:delwaqty/shared/widgets/glass_side_menu.dart';

/// Targets whose route lives OUTSIDE the shell: a top-level stub proves the
/// exact landing page and that no exit-app dialog is ever shown.
const _standaloneTargets = <String, String>{
  'services': '/services',
  'wallet': '/wallet',
  'notifications': '/notifications',
  'direct-delivery': '/direct-delivery',
};

/// Targets that live INSIDE the shell (buildBranch): the real page builds, so
/// we assert on its AppBar title instead of a stub.
const _branchTargets = <String, String>{
  'orders': 'myOrders',
  'my-complaints': 'myComplaints',
  'rewards': 'rewards',
  'profile': 'profile',
};

final _fakeUser = User(
  id: 'u1',
  email: 'user@delwaqty.app',
  username: 'user',
  createdAt: DateTime(2026),
);

class _FakeAuthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState.unauthenticated();
}

class _FakeLocationNotifier extends UserLocationNotifier {
  @override
  Future<UserLocation?> build() async => null;
}

class _FakeOrderRepository implements OrderRepository {
  @override
  Future<List<Order>> getOrders({
    OrderStatus? status,
    int limit = 20,
    int offset = 0,
  }) async =>
      [];

  @override
  Future<Order?> getOrderById(String id) async => null;

  @override
  Future<Order> createOrder({
    required String merchantId,
    required String merchantName,
    required List<CartItem> items,
    required double subtotal,
    required double deliveryFee,
    required double discount,
    required double total,
    String? deliveryAddress,
    String? paymentMethod,
    String? specialInstructions,
  }) =>
      throw UnimplementedError();

  @override
  Future<Order> cancelOrder({required String orderId, String? reason}) =>
      throw UnimplementedError();
}

class _FakeComplaintsRepository implements ComplaintsRepository {
  @override
  Future<List<Complaint>> getComplaints({String? status, String? type}) async =>
      [];

  @override
  Future<List<Complaint>> getMyComplaints(String userId) async => [];

  @override
  Future<Complaint> getComplaintById(String id) async => throw UnimplementedError();

  @override
  Future<Complaint> createComplaint(Complaint complaint) async =>
      throw UnimplementedError();

  @override
  Future<Complaint> updateComplaintStatus(
    String id,
    String status, {
    String? resolutionNote,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> escalateComplaint({required String id, required String reason}) async {}

  @override
  Future<void> addAdminNote(String id, String note) async {}

  @override
  Future<void> deleteComplaint(String id) async {}
}

class _FakeProfileRepository implements ProfileRepository {
  @override
  Future<User> getProfile(String userId) async => _fakeUser;

  @override
  Future<User> updateProfile({
    required String userId,
    required Map<String, dynamic> data,
  }) async =>
      _fakeUser;

  @override
  Future<User> updateDateOfBirth({
    required String userId,
    required DateTime? dateOfBirth,
  }) async =>
      _fakeUser;

  @override
  Future<String> uploadAvatar({
    required String userId,
    required List<int> bytes,
    required String fileName,
  }) async =>
      throw UnimplementedError();

  @override
  Future<String> uploadDocument({
    required String userId,
    required List<int> bytes,
    required String fileName,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> reapplyVerification({
    required String userId,
    required String idCardUrl,
    required String profilePhotoUrl,
  }) async {}

  @override
  Stream<User> watchProfile(String userId) => Stream.value(_fakeUser);
}

GoRouter _buildRouter() {
  final registry = FeatureRegistry.instance;
  final stubbed = _standaloneTargets.values.toSet();
  final realStandalone = registry.allStandaloneRoutes.where((route) {
    final path = route is GoRoute ? route.path : null;
    return path == null || !stubbed.contains(path);
  });
  final realShellSub = registry.allShellSubRoutes.where((route) {
    final path = route is GoRoute ? route.path : null;
    return path == null || !stubbed.contains(path);
  });
  return GoRouter(
    initialLocation: '/home',
    routes: [
      ...realStandalone,
      registry.buildShellRoute(),
      ...realShellSub,
      for (final entry in _standaloneTargets.entries)
        GoRoute(
          path: entry.value,
          builder: (context, state) => Scaffold(
            body: Center(child: Text('STUB:${entry.value}')),
          ),
        ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('ERROR:${state.matchedLocation}')),
    ),
  );
}

Widget _buildApp(SharedPreferencesService prefs) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith(_FakeAuthNotifier.new),
      sharedPreferencesProvider.overrideWith((ref) => prefs),
      userLocationProvider.overrideWith(_FakeLocationNotifier.new),
      nearbyMerchantsProvider.overrideWith((_) async => <Merchant>[]),
      activeCategoriesProvider.overrideWith((_) async => <PlatformCategory>[]),
      discoveryEntriesProvider.overrideWith((_) async => <DiscoveryEntry>[]),
      activeCampaignsProvider.overrideWith((_) async => <Campaign>[]),
      unreadCountProvider.overrideWith((_) async => 0),
      orderRepositoryProvider.overrideWithValue(_FakeOrderRepository()),
      complaintsRepositoryProvider.overrideWithValue(_FakeComplaintsRepository()),
      profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
    ],
    child: Consumer(
      builder: (context, ref, _) {
        const seed = Color(0xFF246BFD);
        return MaterialApp.router(
          routerConfig: _buildRouter(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: seed),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: seed,
              brightness: Brightness.dark,
            ),
          ),
          themeMode: ref.watch(themeModeProvider),
        );
      },
    ),
  );
}

void main() {
  setUpAll(registerAllModules);

  late AppLocalizations l10n;
  late SharedPreferencesService prefsService;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefsService = SharedPreferencesService(
      await SharedPreferences.getInstance(),
    );
  });

  tearDown(GlassSideMenuController.resetForTesting);

  /// The home page runs continuous animations (carousels, pulsing glows), so
  /// pumpAndSettle never settles; drive the animation clock with discrete
  /// pumps instead.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(_buildApp(prefsService));
    await settle(tester);
    expect(find.byType(AppShell), findsOneWidget);
    l10n = AppLocalizations.of(
      tester.element(find.byType(AppShell)),
    );
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byIcon(AppIcons.navDrawer));
    await settle(tester);
    expect(find.byType(GlassMenuPanel), findsOneWidget,
        reason: 'bubble menu should open from the home menu button');
  }

  String entryLabel(WidgetTester tester, String id) {
    final context = tester.element(find.byType(AppShell));
    final entry = FeatureRegistry.instance.allDrawerEntries
        .firstWhere((e) => e.id == id);
    return entry.label(context);
  }

  Future<void> scrollPanelIfNeeded(WidgetTester tester, String label) async {
    final panelScroll = find.descendant(
      of: find.byType(GlassMenuPanel),
      matching: find.byType(SingleChildScrollView),
    );
    final scrollRect = tester.getRect(panelScroll);
    final labelRect = tester.getRect(find.text(label));
    if (labelRect.bottom > scrollRect.bottom ||
        labelRect.top < scrollRect.top) {
      final deltaH = labelRect.center.dy - scrollRect.center.dy;
      await tester.drag(panelScroll, Offset(0, -deltaH));
      await settle(tester);
    }
  }

  Future<void> tapTile(WidgetTester tester, String label) async {
    await scrollPanelIfNeeded(tester, label);
    await tester.tap(find.text(label));
    await settle(tester);
  }

  for (final entry in _standaloneTargets.entries) {
    testWidgets('menu button "${entry.key}" -> ${entry.value} navigates '
        'without crashing or showing the exit dialog', (tester) async {
      await pumpApp(tester);
      await openMenu(tester);
      await tapTile(tester, entryLabel(tester, entry.key));

      expect(find.byType(GlassMenuPanel), findsNothing,
          reason: 'bubble must close after tapping "${entry.key}"');
      expect(find.text('STUB:${entry.value}'), findsOneWidget,
          reason: 'tapping "${entry.key}" must land on ${entry.value}');
      expect(find.byType(Dialog), findsNothing,
          reason: 'tapping "${entry.key}" must never open the exit dialog');

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byType(AppShell), findsOneWidget,
          reason: 'back from "${entry.key}" must return to the home shell, '
              'never exit the app');
      expect(find.text('STUB:${entry.value}'), findsNothing);
      await disposeApp(tester);
    });
  }

  for (final entry in _branchTargets.entries) {
    testWidgets('menu button "${entry.key}" opens the real page without '
        'crashing or showing the exit dialog', (tester) async {
      await pumpApp(tester);
      await openMenu(tester);
      await tapTile(tester, entryLabel(tester, entry.key));

      expect(find.byType(GlassMenuPanel), findsNothing,
          reason: 'bubble must close after tapping "${entry.key}"');
      expect(find.text('STUB:'), findsNothing,
          reason: '${entry.key} is a shell route, not a stub');
      expect(tester.takeException(), isNull,
          reason: 'the real ${entry.key} page must build cleanly');
      expect(find.byType(Dialog), findsNothing,
          reason: 'tapping "${entry.key}" must never open the exit dialog');

      final title = switch (entry.key) {
        'orders' => l10n.myOrders,
        'my-complaints' => l10n.myComplaints,
        'rewards' => l10n.rewards,
        _ => l10n.profile,
      };
      expect(find.text(title), findsWidgets,
          reason: 'the ${entry.key} page must actually open');

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byType(AppShell), findsOneWidget,
          reason: 'back from "${entry.key}" must return to the home shell, '
              'never exit the app');
      await disposeApp(tester);
    });
  }

  testWidgets('menu button "dark mode" animates the theme toggle without '
      'crashing', (tester) async {
    await pumpApp(tester);
    await openMenu(tester);
    await tapTile(tester, l10n.darkMode);

    expect(tester.takeException(), isNull,
        reason: 'tapping dark mode must not crash');
    expect(find.byType(Dialog), findsNothing);
    final appContext = tester.element(find.byType(AppShell));
    expect(Theme.of(appContext).brightness, Brightness.dark,
        reason: 'dark mode must actually switch on after the tap');
    await disposeApp(tester);
  });

  testWidgets('menu button "language" toggles the locale without crashing',
      (tester) async {
    await pumpApp(tester);
    await openMenu(tester);
    await tapTile(tester, l10n.language);

    expect(tester.takeException(), isNull,
        reason: 'tapping language must not crash');
    expect(find.byType(Dialog), findsNothing);
    await disposeApp(tester);
  });
}