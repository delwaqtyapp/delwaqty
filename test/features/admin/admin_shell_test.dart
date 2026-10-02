import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delwaqty/core/localization/admin_locale_provider.dart';
import 'package:delwaqty/data/datasources/local/shared_preferences_service.dart';
import 'package:delwaqty/features/admin/admin_shell.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<Widget> harness() async {
    final prefsService = SharedPreferencesService(
      await SharedPreferences.getInstance(),
    );
    final router = GoRouter(
      initialLocation: '/admin',
      routes: [
        GoRoute(
          path: '/admin',
          builder: (context, state) {
            return const AdminShell(child: SizedBox.expand());
          },
        ),
        GoRoute(
          path: '/admin/members',
          builder: (context, state) {
            return const AdminShell(child: SizedBox.expand());
          },
        ),
        GoRoute(
          path: '/admin/analytics',
          builder: (context, state) {
            return const AdminShell(child: SizedBox.expand());
          },
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => prefsService),
        adminLocaleProvider.overrideWith(AdminLocaleNotifier.new),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ar')],
      ),
    );
  }

  testWidgets('phone layout renders the floating pill bottom nav with active tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1290, 2823);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await harness());
    await tester.pumpAndSettle();

    expect(find.byType(AdminShell), findsOneWidget);
    expect(find.text('Command Center'), findsWidgets);
    expect(find.byIcon(Icons.people_rounded), findsWidgets);
    expect(find.byIcon(Icons.receipt_long_rounded), findsWidgets);
    expect(find.byIcon(Icons.bolt_rounded), findsWidgets);
  });

  testWidgets('wide layout renders the premium sidebar with groups', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 941);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await harness());
    await tester.pumpAndSettle();

    expect(find.byType(AdminShell), findsOneWidget);
    expect(find.text('Admin Panel'), findsWidgets);
    expect(find.text('Command Center'), findsWidgets);
    expect(find.text('Analytics'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Financial Center'),
      200,
      scrollable: find.descendant(
        of: find.byKey(const Key('adminSidebarScroll')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Financial Center'), findsWidgets);
  });

  testWidgets('tapping a wide-sidebar tile navigates to the target route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 941);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Analytics'));
    await tester.pumpAndSettle();

    expect(
      GoRouterState.of(tester.element(find.byType(AdminShell))).matchedLocation,
      '/admin/analytics',
    );
  });
}