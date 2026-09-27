import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delwaqty/data/datasources/local/biometric_auth_store.dart';
import 'package:delwaqty/data/datasources/local/shared_preferences_service.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/auth/presentation/pages/login_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class _FakeAuthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState.unauthenticated();
}

class _ConfirmResendAuthNotifier extends AuthStateNotifier {
  String? lastResendEmail;

  @override
  AuthState build() => const AuthState.unauthenticated();

  @override
  Future<void> signIn({required String email, required String password}) async {
    state = const AuthState.error(message: 'Email not confirmed.');
  }

  @override
  Future<void> resendEmailConfirmation({required String email}) async {
    lastResendEmail = email;
  }
}

Widget _buildTestApp({
  required BiometricAuthStore store,
  required SharedPreferencesService prefsService,
  AuthStateNotifier Function()? notifier,
}) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith(notifier ?? _FakeAuthNotifier.new),
      biometricAuthStoreProvider.overrideWithValue(store),
      sharedPreferencesProvider.overrideWithValue(prefsService),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('en'),
      home: LoginPage(),
    ),
  );
}

void main() {
  late BiometricAuthStore store;
  late SharedPreferencesService prefsService;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    store = BiometricAuthStore(const FlutterSecureStorage());
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefsService = SharedPreferencesService(
      await SharedPreferences.getInstance(),
    );
  });

  testWidgets('hides the biometric button when no credentials are stored', (
    tester,
  ) async {
    await store.saveCredentials(
      userId: 'user-1',
      email: 'a@b.com',
      password: 'secret',
    );
    await store.clearForUser('user-1');

    await tester.pumpWidget(
      _buildTestApp(store: store, prefsService: prefsService),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.fingerprint_rounded), findsNothing);
    expect(find.text('Login with Fingerprint'), findsNothing);
  });

  testWidgets(
    'offers a resend-activation dialog when sign-in says the email is not confirmed',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          store: store,
          prefsService: prefsService,
          notifier: _ConfirmResendAuthNotifier.new,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email or username'),
        'a@b.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        '12345678',
      );

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Check your email'), findsOneWidget);
      expect(find.text('Resend activation email'), findsOneWidget);

      await tester.tap(find.text('Resend activation email'));
      await tester.pumpAndSettle();

      final notifier = ProviderScope.containerOf(
        tester.element(find.byType(LoginPage)),
      ).read(authStateProvider.notifier) as _ConfirmResendAuthNotifier;
      expect(notifier.lastResendEmail, 'a@b.com');
      expect(find.textContaining('We sent a confirmation link to a@b.com'),
          findsOneWidget);
    },
  );
}
