import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/core/module/feature_registry.dart';
import 'package:delwaqty/core/module/shell_customization.dart';
import 'package:delwaqty/features/provider/capability/domain/provider_capability.dart';
import 'package:delwaqty/features/provider/capability/domain/provider_profile.dart';
import 'package:delwaqty/features/provider/capability/presentation/providers/provider_capability_providers.dart';
import 'package:delwaqty/features/provider/services/domain/provider_service_info.dart';
import 'package:delwaqty/features/provider/services/presentation/pages/provider_services_page.dart';
import 'package:delwaqty/features/provider/services/presentation/providers/provider_service_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/app_shell.dart';
import 'package:delwaqty/shared/widgets/nav_pill_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeTab extends FeatureModule {
  _FakeTab(this.id, this.path, this.priority, this.icon);
  @override
  final String id;
  final String path;
  final int priority;
  @override
  final IconData icon;
  @override
  String name(BuildContext context) => id;
  @override
  bool get isNavModule => true;
  @override
  int get navPriority => priority;
  @override
  StatefulShellBranch? buildBranch() => StatefulShellBranch(
    routes: [
      GoRoute(
        path: path,
        builder: (context, state) => Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text(
              Localizations.localeOf(context).languageCode == 'ar'
                  ? 'شاشة: $id'
                  : 'page: $id',
            ),
          ),
          body: Center(child: Text(id, key: const ValueKey('page'))),
        ),
      ),
    ],
  );
}

void main() {
  setUpAll(() async {
    final font = FontLoader('Cairo')
      ..addFont(rootBundle.load('assets/fonts/Cairo-400.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Cairo-700.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    FeatureRegistry.instance
      ..registerAll([
        _FakeTab(ProviderTabIds.dashboard, '/d', 10, Icons.dashboard_rounded),
        _FakeTab(ProviderTabIds.orders, '/o', 12, Icons.receipt_long_rounded),
        _FakeTab(ProviderTabIds.bookings, '/b', 13, Icons.event_note_rounded),
        _FakeTab(ProviderTabIds.products, '/p', 15, Icons.inventory_2_rounded),
        _FakeTab(ProviderTabIds.services, '/s', 16, Icons.handyman_rounded),
        _FakeTab(ProviderTabIds.cashier, '/c', 17, Icons.point_of_sale_rounded),
        _FakeTab(
          ProviderTabIds.financial,
          '/f',
          20,
          Icons.account_balance_wallet_outlined,
        ),
      ])
      ..freeze();
  });

  const types = {
    'restaurant': 5,
    'grocery': 5,
    'plumbing': 4,
    'teacher': 4,
    'doctor': 4,
  };

  Widget app(String raw, {String lang = 'ar'}) {
    final profile = ProviderProfile.forCategory(
      ProviderCategory.normalize(raw),
    );
    final router = GoRouter(
      initialLocation: '/d',
      routes: [FeatureRegistry.instance.buildShellRoute()],
    );
    return ProviderScope(
      overrides: [
        shellNavConfigProvider.overrideWithValue(profile.toShellNavConfig()),
      ],
      child: RepaintBoundary(
        key: const ValueKey('capture'),
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          locale: Locale(lang),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: ThemeData(fontFamily: 'Cairo'),
          routerConfig: router,
        ),
      ),
    );
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  for (final e in types.entries) {
    testWidgets('${e.key}: shell shows ${e.value} tabs (Arabic RTL)', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(app(e.key));
      await tester.pumpAndSettle();
      expect(find.byType(NavPillButton), findsNWidgets(e.value));
      await expectLater(
        find.byKey(const ValueKey('capture')),
        matchesGoldenFile('goldens/shell_${e.key}_ar.png'),
      );
    });
  }

  testWidgets('no tab selection overflows in either language', (tester) async {
    phone(tester);
    for (final lang in ['ar', 'en']) {
      for (final raw in types.keys) {
        await tester.pumpWidget(app(raw, lang: lang));
        await tester.pumpAndSettle();
        final count = find.byType(NavPillButton).evaluate().length;
        for (var i = 0; i < count; i++) {
          await tester.tap(find.byType(NavPillButton).at(i));
          await tester.pumpAndSettle();
        }
      }
    }
  });

  for (final c in [('teacher', 1), ('plumbing', 2), ('restaurant', 2)]) {
    testWidgets('${c.$1}: selected tab shows its localized label', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(app(c.$1));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NavPillButton).at(c.$2));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey('capture')),
        matchesGoldenFile('goldens/shell_${c.$1}_tab${c.$2}_ar.png'),
      );
    });
  }

  testWidgets('plumber tabs open the right branches', (tester) async {
    phone(tester);
    await tester.pumpWidget(app('plumbing'));
    await tester.pumpAndSettle();
    final pills = find.byType(NavPillButton);
    // Order: dashboard, bookings, services, financial.
    final expected = [
      ProviderTabIds.dashboard,
      ProviderTabIds.bookings,
      ProviderTabIds.services,
      ProviderTabIds.financial,
    ];
    for (var i = 0; i < expected.length; i++) {
      await tester.tap(pills.at(i));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('page'))).data,
        expected[i],
      );
    }
    // No shop surfaces exist in the plumber's shell.
    expect(find.text(ProviderTabIds.cashier), findsNothing);
    expect(find.text(ProviderTabIds.products), findsNothing);
  });

  testWidgets('grocery cashier tab opens the cashier branch', (tester) async {
    phone(tester);
    await tester.pumpWidget(app('grocery'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(NavPillButton).at(3));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('page'))).data,
      ProviderTabIds.cashier,
    );
  });

  test('without a config every module stays visible, in order', () {
    final mods = FeatureRegistry.instance.navModules;
    final all = AppShell.visibleNav(mods, null);
    expect(all.map((e) => e.key), [0, 1, 2, 3, 4, 5, 6]);
    final some = AppShell.visibleNav(
      mods,
      const ShellNavConfig(
        visibleModuleIds: [ProviderTabIds.financial, ProviderTabIds.dashboard],
      ),
    );
    expect(some.map((e) => e.value.id), [
      ProviderTabIds.financial,
      ProviderTabIds.dashboard,
    ]);
    // Unknown ids never produce an empty bar.
    final fallback = AppShell.visibleNav(
      mods,
      const ShellNavConfig(visibleModuleIds: ['nope']),
    );
    expect(fallback.length, 7);
  });

  group('my services and prices view', () {
    Future<void> pumpServices(
      WidgetTester tester,
      String raw,
      List<ProviderServiceInfo> items,
    ) async {
      phone(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerProfileProvider.overrideWithValue(
              ProviderProfile.forCategory(ProviderCategory.normalize(raw)),
            ),
            providerServiceInfoProvider.overrideWith((ref) async => items),
          ],
          child: RepaintBoundary(
            key: const ValueKey('capture'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: const Locale('ar'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              theme: ThemeData(fontFamily: 'Cairo'),
              home: const ProviderServicesPage(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
    }

    testWidgets('plumber sees read-only prices', (tester) async {
      await pumpServices(tester, 'plumbing', const [
        ProviderServiceInfo(
          categoryType: 'plumbing',
          name: 'سباكة',
          description: 'تأسيس وصيانة',
          hourlyRate: 150,
          fixedPriceMin: 200,
          fixedPriceMax: 450,
          tags: ['تسريب', 'غسالات'],
        ),
      ]);
      expect(find.text('خدماتي وأسعارها'), findsOneWidget);
      expect(find.textContaining('150'), findsOneWidget);
      expect(find.textContaining('200'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      await expectLater(
        find.byKey(const ValueKey('capture')),
        matchesGoldenFile('goldens/services_plumbing_ar.png'),
      );
    });

    testWidgets('plumber 320 large text prices wrap', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpServices(tester, 'plumbing', const [
        ProviderServiceInfo(
          categoryType: 'plumbing',
          name: 'سباكة',
          description: 'تأسيس وصيانة',
          hourlyRate: 150,
          fixedPriceMin: 200,
          fixedPriceMax: 450,
          tags: ['تسريب', 'غسالات'],
        ),
      ]);
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('capture')),
        matchesGoldenFile('goldens/services_plumbing_ar_320_large.png'),
      );
    });

    testWidgets('teacher wording and unset price', (tester) async {
      await pumpServices(tester, 'teacher', const [
        ProviderServiceInfo(categoryType: 'teacher', name: 'مدرس رياضيات'),
      ]);
      expect(find.text('دروسي وأسعارها'), findsOneWidget);
      expect(find.text('السعر لسه ما اتحددش من الإدارة'), findsOneWidget);
      await expectLater(
        find.byKey(const ValueKey('capture')),
        matchesGoldenFile('goldens/services_teacher_ar.png'),
      );
    });

    testWidgets('empty state', (tester) async {
      await pumpServices(tester, 'teacher', const []);
      expect(find.text('لسه مفيش دروس متسجلة على حسابك'), findsOneWidget);
    });
  });
}
