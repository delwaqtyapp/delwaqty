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

Widget _buildTestApp({
  required BiometricAuthStore store,
  required SharedPreferencesService prefsService,
}) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith(_FakeAuthNotifier.new),
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
}
