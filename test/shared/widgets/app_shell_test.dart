import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delwaqty/data/datasources/local/shared_preferences_service.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/app_shell.dart';

class _FakeAuthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState.unauthenticated();
}

const _homeLabel = 'HOME_STUB';
const _searchLabel = 'SEARCH_STUB';

Widget _stub(String label) {
  return Scaffold(
    body: Center(
      child: Text(label, style: const TextStyle(fontSize: 24)),
    ),
  );
}

void main() {
  late SharedPreferencesService prefsService;
  late GoRouter router;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefsService = SharedPreferencesService(
      await SharedPreferences.getInstance(),
    );
    router = GoRouter(
      initialLocation: '/home',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/home', builder: (c, s) => _stub(_homeLabel)),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/search', builder: (c, s) => _stub(_searchLabel)),
              ],
            ),
          ],
        ),
      ],
    );
  });

  Widget buildTestApp() {
    return ProviderScope(
      overrides: [
        authStateProvider.overrideWith(_FakeAuthNotifier.new),
        sharedPreferencesProvider.overrideWithValue(prefsService),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
      ),
    );
  }

  testWidgets('back on a non-home tab returns to the home tab', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    router.go('/search');
    await tester.pumpAndSettle();
    expect(find.text(_searchLabel), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(_homeLabel), findsOneWidget);
    expect(find.text(_searchLabel), findsNothing);
  });

  testWidgets('back on the home tab shows the exit confirmation dialog', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();
    expect(find.text(_homeLabel), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Exit app'), findsNWidgets(2));
    expect(
      find.text('Are you sure you want to exit the app?'),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('cancelling the exit dialog keeps the app open on home', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(_homeLabel), findsOneWidget);
  });

  testWidgets('confirming the exit dialog requests the system pop', (
    tester,
  ) async {
    final popCalls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemNavigator.pop') {
          popCalls.add(call.method);
        }
        return null;
      },
    );

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Exit app').last);
    await tester.pump();

    expect(popCalls, contains('SystemNavigator.pop'));
  });
}