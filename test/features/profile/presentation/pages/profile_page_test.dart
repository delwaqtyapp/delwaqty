import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:delwaqty/data/datasources/local/shared_preferences_service.dart';
import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/domain/enums/verification_status.dart';
import 'package:delwaqty/domain/repositories/profile_repository.dart';
import 'package:delwaqty/domain/usecases/profile/profile_usecases.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/customer/profile/presentation/pages/profile_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/app_shell.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

final _user = User(
  id: 'u1',
  email: 'customer@example.com',
  fullName: 'Test Customer',
  username: 'customer',
  phone: '01000000000',
  verificationStatus: VerificationStatus.approved,
  createdAt: DateTime(2024),
);

class _FakeAuthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => AuthState.authenticated(user: _user);
}

Widget _buildTestApp(ProfileRepository repo, SharedPreferencesService prefs) {
  return ProviderScope(
    overrides: [
      profileRepositoryProvider.overrideWithValue(repo),
      sharedPreferencesProvider.overrideWithValue(prefs),
      authStateProvider.overrideWith(_FakeAuthNotifier.new),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('en'),
      home: ProfilePage(),
    ),
  );
}

Widget _buildTestAppWithBottomNav(
  ProfileRepository repo,
  SharedPreferencesService prefs,
) {
  const navHeight = 72.0;
  return ProviderScope(
    overrides: [
      profileRepositoryProvider.overrideWithValue(repo),
      sharedPreferencesProvider.overrideWithValue(prefs),
      authStateProvider.overrideWith(_FakeAuthNotifier.new),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('en'),
      home: Scaffold(
        extendBody: true,
        body: ProfilePage(),
        bottomNavigationBar: SizedBox(height: navHeight),
      ),
    ),
  );
}

void main() {
  late _MockProfileRepository mockRepo;
  late SharedPreferencesService prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = SharedPreferencesService(
      await SharedPreferences.getInstance(),
    );
    mockRepo = _MockProfileRepository();
    when(
      () => mockRepo.watchProfile(any()),
    ).thenAnswer((_) => Stream.value(_user));
  });

  void Function(FlutterErrorDetails)? ignoreVisualAssertions(
    void Function(FlutterErrorDetails)? original,
  ) {
    return (FlutterErrorDetails details) {
      final message = details.exception.toString();
      if (message.contains('ListTile') &&
          message.contains('ink splashes may be invisible')) {
        return;
      }
      original?.call(details);
    };
  }

  testWidgets('saves edited profile fields without crashing', (tester) async {
    final oldHandler = FlutterError.onError;
    FlutterError.onError = ignoreVisualAssertions(oldHandler);
    addTearDown(() => FlutterError.onError = oldHandler);

    when(
      () => mockRepo.updateProfile(
        userId: any(named: 'userId'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((_) async => _user);

    await tester.pumpWidget(_buildTestApp(mockRepo, prefs));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Edit Profile'), findsOneWidget);
    await tester.ensureVisible(find.text('Edit Profile'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Edit Profile'),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AlertDialog), findsOneWidget);

    expect(find.text('Save Changes'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).at(0),
      'Updated Name',
    );
    await tester.pump();

    await tester.tap(find.text('Save Changes'));
    await tester.pump(const Duration(milliseconds: 400));

    verify(
      () => mockRepo.updateProfile(
        userId: 'u1',
        data: any(named: 'data'),
      ),
    ).called(1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clearing optional fields sends null for them', (tester) async {
    final oldHandler = FlutterError.onError;
    FlutterError.onError = ignoreVisualAssertions(oldHandler);
    addTearDown(() => FlutterError.onError = oldHandler);

    when(
      () => mockRepo.updateProfile(
        userId: any(named: 'userId'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((_) async => _user);

    await tester.pumpWidget(_buildTestApp(mockRepo, prefs));
    await tester.pump(const Duration(milliseconds: 800));

    await tester.tap(find.text('Edit Profile'));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(find.byType(TextField).at(0), 'Only Name');
    await tester.enterText(find.byType(TextField).at(1), '');
    await tester.enterText(find.byType(TextField).at(2), '');
    await tester.pump();

    await tester.tap(find.text('Save Changes'));
    await tester.pump(const Duration(milliseconds: 400));

    verify(
      () => mockRepo.updateProfile(
        userId: 'u1',
        data: {
          'full_name': 'Only Name',
          'username': null,
          'phone': null,
        },
      ),
    ).called(1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'logout button stays above the bottom navigation bar when scrolled to the end',
    (tester) async {
      final oldHandler = FlutterError.onError;
      FlutterError.onError = ignoreVisualAssertions(oldHandler);
      addTearDown(() => FlutterError.onError = oldHandler);

      tester.view.physicalSize = const Size(800, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildTestAppWithBottomNav(mockRepo, prefs));
      await tester.pump(const Duration(milliseconds: 800));

      const navHeight = 72.0;
      final navTop =
          tester.view.physicalSize.height /
              tester.view.devicePixelRatio -
          navHeight;

      final listView = tester.widget<ListView>(find.byType(ListView));
      final bottomPadding = (listView.padding as EdgeInsets).bottom;
      expect(bottomPadding, greaterThanOrEqualTo(kFloatingNavClearance));

      await tester.fling(find.byType(ListView), const Offset(0, -3000), 3000);
      await tester.pumpAndSettle();

      final logoutRect = tester.getBottomRight(find.text('Logout'));
      expect(logoutRect.dy, lessThan(navTop));
    },
  );
}
