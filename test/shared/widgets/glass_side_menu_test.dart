import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/data/datasources/local/shared_preferences_service.dart';
import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/domain/enums/user_type.dart';
import 'package:delwaqty/domain/enums/verification_status.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/customer/home/home_module.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/app_shell.dart';
import 'package:delwaqty/shared/widgets/glass_side_menu.dart';

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

class _BubbleHarness extends StatelessWidget {
  const _BubbleHarness({required this.entries});

  final List<DrawerEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Consumer(
          builder: (context, ref, child) => FilledButton(
            onPressed: () =>
                GlassSideMenuController.open(context, ref, drawerEntries: entries),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }
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

Widget _wrap(
  WidgetTester tester, {
  required SharedPreferencesService prefsService,
  required AuthStateNotifier notifier,
  required Widget Function(BuildContext, WidgetRef, Widget?) builder,
}) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => notifier),
      sharedPreferencesProvider.overrideWith((ref) => prefsService),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: Consumer(builder: builder),
      ),
    ),
  );
}

void main() {
  late SharedPreferencesService prefsService;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefsService = SharedPreferencesService(
      await SharedPreferences.getInstance(),
    );
  });
  tearDown(() {
    GlassSideMenuController.resetForTesting();
  });
  testWidgets('bubble menu shows username and hides email', (tester) async {
    final notifier = _AuthenticatedAuthNotifier(
      _userFixture(
        fullName: 'John Doe',
        username: 'johndoe',
        email: 'john@example.com',
      ),
    );
    await tester.pumpWidget(
      _wrap(
        tester,
        prefsService: prefsService,
        notifier: notifier,
        builder: (context, ref, child) {
          final l10n = AppLocalizations.of(context);
          return Center(
            child: GlassMenuPanel(
              authState: ref.read(authStateProvider),
              l10n: l10n,
              themeMode: ThemeMode.light,
              locale: const Locale('en'),
              ref: ref,
              drawerEntries: const [],
              width: 240,
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('John Doe'), findsOneWidget);
    expect(find.text('@johndoe'), findsOneWidget);
    expect(find.text('john@example.com'), findsNothing);
    expect(find.text('Customer'), findsOneWidget);
  });

  testWidgets('bubble menu renders empty when no username', (tester) async {
    final notifier = _AuthenticatedAuthNotifier(
      _userFixture(email: 'sara@example.com'),
    );
    await tester.pumpWidget(
      _wrap(
        tester,
        prefsService: prefsService,
        notifier: notifier,
        builder: (context, ref, child) {
          final l10n = AppLocalizations.of(context);
          return Center(
            child: GlassMenuPanel(
              authState: ref.read(authStateProvider),
              l10n: l10n,
              themeMode: ThemeMode.light,
              locale: const Locale('en'),
              ref: ref,
              drawerEntries: const [],
              width: 240,
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('sara@example.com'), findsNothing);
    expect(find.text('User'), findsOneWidget);
    expect(find.text('Customer'), findsOneWidget);
  });

  testWidgets('bubble menu shows provider rank and verification badge', (
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
    await tester.pumpWidget(
      _wrap(
        tester,
        prefsService: prefsService,
        notifier: notifier,
        builder: (context, ref, child) {
          final l10n = AppLocalizations.of(context);
          return Center(
            child: GlassMenuPanel(
              authState: ref.read(authStateProvider),
              l10n: l10n,
              themeMode: ThemeMode.light,
              locale: const Locale('en'),
              ref: ref,
              drawerEntries: const [],
              width: 240,
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Provider'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
  });

  testWidgets('controller opens bubble overlay and dismisses on outside tap', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        tester,
        prefsService: prefsService,
        notifier: _FakeAuthNotifier(),
        builder: (context, ref, child) {
          return Center(
            child: FilledButton(
              onPressed: () =>
                  GlassSideMenuController.open(context, ref),
              child: const Text('open'),
            ),
          );
        },
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(GlassMenuPanel), findsOneWidget);
    expect(find.text('Dark Mode'), findsOneWidget);

    await tester.tapAt(const Offset(500, 300));
    await tester.pumpAndSettle();

    expect(find.byType(GlassMenuPanel), findsNothing);
  });

  testWidgets('controller open from a button anchor keeps panel visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        tester,
        prefsService: prefsService,
        notifier: _FakeAuthNotifier(),
        builder: (context, ref, child) {
          return Align(
            alignment: Alignment.topRight,
            child: Consumer(
              builder: (context, ref, child) {
                final key = GlobalKey();
                return IconButton(
                  key: key,
                  icon: const Icon(Icons.menu),
                  onPressed: () {
                    final box = key.currentContext?.findRenderObject()
                        as RenderBox?;
                    final anchor = box == null
                        ? null
                        : box.localToGlobal(Offset.zero) & box.size;
                    GlassSideMenuController.open(
                      context,
                      ref,
                      anchor: anchor,
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(find.byType(GlassMenuPanel), findsOneWidget);
    expect(find.text('Dark Mode'), findsOneWidget);
  });

  testWidgets('tapping a bubble tile closes the menu and navigates without crashing', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (c, s) => _BubbleHarness(entries: [
            DrawerEntry(
              id: 'services',
              label: (_) => 'Services',
              icon: Icons.grid_view_rounded,
              onTap: (ctx, ref) {
                Navigator.of(ctx).maybePop();
                ctx.go('/services');
              },
            ),
          ]),
        ),
        GoRoute(
          path: '/services',
          builder: (c, s) =>
              const Scaffold(body: Center(child: Text('ServicesPage'))),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(() => _FakeAuthNotifier()),
          sharedPreferencesProvider.overrideWith((ref) => prefsService),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(GlassMenuPanel), findsOneWidget);

    await tester.tap(find.text('Services'));
    await tester.pumpAndSettle();

    expect(find.byType(GlassMenuPanel), findsNothing);
    expect(find.text('ServicesPage'), findsOneWidget);
  });

  testWidgets('home module drawer entries no longer include the home tile', (
    tester,
  ) async {
    final entries = HomeModule().drawerEntries;
    expect(entries.any((e) => e.id == 'home'), isFalse);
    expect(entries.any((e) => e.id == 'services'), isTrue);
  });
}