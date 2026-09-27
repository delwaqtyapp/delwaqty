import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delwaqty/data/datasources/local/shared_preferences_service.dart';
import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/domain/enums/user_type.dart';
import 'package:delwaqty/domain/enums/verification_status.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/gen/assets.gen.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/app_shell.dart';

class _FakeAuthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState.unauthenticated();
}

class _AuthenticatedAuthNotifier extends AuthStateNotifier {
  _AuthenticatedAuthNotifier(this.user);

  final User user;

  @override
  AuthState build() => AuthState.authenticated(user: user);
}

User _userFixture({
  String? username,
  String? avatarUrl,
  String? fullName,
  String email = 'user@example.com',
  String role = 'customer',
  UserType userType = UserType.customer,
  VerificationStatus verificationStatus = VerificationStatus.pending,
}) {
  return User(
    id: 'u1',
    email: email,
    fullName: fullName,
    username: username,
    avatarUrl: avatarUrl,
    role: role,
    userType: userType,
    verificationStatus: verificationStatus,
    createdAt: DateTime(2024),
  );
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

  Widget buildTestApp([AuthStateNotifier? notifier]) {
    return ProviderScope(
      overrides: [
        authStateProvider.overrideWith(() => notifier ?? _FakeAuthNotifier()),
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

  Future<void> openDrawer(WidgetTester tester) async {
    final shellScaffold = find.descendant(
      of: find.byType(AppShell),
      matching: find.byType(Scaffold),
    );
    tester.state<ScaffoldState>(shellScaffold.first).openDrawer();
    await tester.pumpAndSettle();
  }

  testWidgets('drawer header shows username and hides email', (tester) async {
    final notifier = _AuthenticatedAuthNotifier(
      _userFixture(
        fullName: 'John Doe',
        username: 'johndoe',
        email: 'john@example.com',
      ),
    );
    await tester.pumpWidget(buildTestApp(notifier));
    await openDrawer(tester);

    expect(find.text('John Doe'), findsOneWidget);
    expect(find.text('@johndoe'), findsOneWidget);
    expect(find.text('john@example.com'), findsNothing);
    expect(find.text('Customer'), findsOneWidget);
  });

  testWidgets('drawer renders empty instead of email when no username', (
    tester,
  ) async {
    final notifier = _AuthenticatedAuthNotifier(
      _userFixture(email: 'sara@example.com'),
    );
    await tester.pumpWidget(buildTestApp(notifier));
    await openDrawer(tester);

    expect(find.text('sara@example.com'), findsNothing);
    expect(find.text('User'), findsOneWidget);
    expect(find.text('Customer'), findsOneWidget);
  });

  testWidgets('drawer shows provider rank and verification badge', (
    tester,
  ) async {
    final notifier = _AuthenticatedAuthNotifier(
      _userFixture(
        fullName: 'Ali',
        username: 'ali',
        role: 'provider',
        userType: UserType.provider,
        verificationStatus: VerificationStatus.approved,
      ),
    );
    await tester.pumpWidget(buildTestApp(notifier));
    await openDrawer(tester);

    expect(find.text('Provider'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
  });

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
    final logoFinder = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(Image),
    );
    expect(logoFinder, findsOneWidget);
    final logoImage = tester.widget<Image>(logoFinder);
    expect(
      (logoImage.image as AssetImage).assetName,
      Assets.egypt.delwaqtyLogoMark.path,
    );
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

    expect(find.byType(Dialog), findsNothing);
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