import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _RecordingAuthNotifier extends AuthStateNotifier {
  String? lastEmail;
  String? lastPassword;

  @override
  AuthState build() => const AuthState.unauthenticated();

  @override
  Future<void> signIn({required String email, required String password}) async {
    lastEmail = email;
    lastPassword = password;
  }
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
      identifier: '01001112233',
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
        find.widgetWithText(TextFormField, 'Phone Number or Username'),
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
      expect(
        find.textContaining('We sent a confirmation link to a@b.com'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'biometric login replays the stored login identifier, never an email (441)',
    (tester) async {
      const channel = MethodChannel('plugins.flutter.io/local_auth');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'canCheckBiometrics':
              case 'isDeviceSupported':
                return true;
              case 'getAvailableBiometrics':
                return <String>['fingerprint'];
              case 'authenticate':
                return true;
              default:
                return null;
            }
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      await store.saveCredentials(
        userId: 'user-1',
        identifier: '01001112233',
        password: 'secret',
      );

      await tester.pumpWidget(
        _buildTestApp(
          store: store,
          prefsService: prefsService,
          notifier: _RecordingAuthNotifier.new,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.fingerprint_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.fingerprint_rounded));
      await tester.pumpAndSettle();

      final notifier = ProviderScope.containerOf(
        tester.element(find.byType(LoginPage)),
      ).read(authStateProvider.notifier) as _RecordingAuthNotifier;
      expect(notifier.lastEmail, '01001112233');
      expect(notifier.lastPassword, 'secret');
    },
  );

  testWidgets('biometric login ignores a legacy email-keyed credential (441)', (
    tester,
  ) async {
    const channel = MethodChannel('plugins.flutter.io/local_auth');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'canCheckBiometrics':
            case 'isDeviceSupported':
              return true;
            case 'getAvailableBiometrics':
              return <String>['fingerprint'];
            case 'authenticate':
              return true;
            default:
              return null;
          }
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    const storage = FlutterSecureStorage();
    await storage.write(
      key: 'auth_biometric_user-1',
      value: '{"email":"phone_201001112233@delwaqty.app","password":"secret","userId":"user-1"}',
    );
    await storage.write(key: 'auth_biometric_active_user', value: 'user-1');
    await storage.write(key: 'auth_biometric_index', value: '["user-1"]');

    await tester.pumpWidget(
      _buildTestApp(
        store: store,
        prefsService: prefsService,
        notifier: _RecordingAuthNotifier.new,
      ),
    );
    await tester.pumpAndSettle();

    // The only stored credential is email-keyed: discarded on read,
    // so no fingerprint sign-in is offered.
    expect(find.byIcon(Icons.fingerprint_rounded), findsNothing);
  });
}
