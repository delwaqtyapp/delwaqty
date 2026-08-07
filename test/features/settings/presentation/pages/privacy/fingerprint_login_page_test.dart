import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delwaqty/data/datasources/local/saved_accounts_store.dart';
import 'package:delwaqty/data/datasources/local/shared_preferences_service.dart';
import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/settings/presentation/pages/privacy/fingerprint_login_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class _FakeAuthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => AuthState.authenticated(user: testUser);
}

final testUser = User(
  id: 'user-123',
  email: 'user@example.com',
  createdAt: DateTime(2024, 1, 15),
);

Widget _buildTestApp(SavedAccountsStore store) {
  return ProviderScope(
    overrides: [
      savedAccountsStoreProvider.overrideWithValue(store),
      authStateProvider.overrideWith(_FakeAuthNotifier.new),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('en'),
      home: FingerprintLoginPage(),
    ),
  );
}

Future<SavedAccountsStore> _buildStore() async {
  SharedPreferences.setMockInitialValues({});
  final instance = await SharedPreferences.getInstance();
  FlutterSecureStorage.setMockInitialValues(<String, String>{});
  return SavedAccountsStore(
    SharedPreferencesService(instance),
    const FlutterSecureStorage(),
  );
}

void main() {
  testWidgets('shows fingerprint switch disabled when not saved', (
    tester,
  ) async {
    final store = await _buildStore();
    await tester.pumpWidget(_buildTestApp(store));
    await tester.pumpAndSettle();

    final switchTile = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(switchTile.value, isFalse);
  });

  testWidgets('shows fingerprint switch enabled when biometric saved', (
    tester,
  ) async {
    final store = await _buildStore();
    await store.saveAccount(email: 'user@example.com');
    await store.setBiometric(
      email: 'user@example.com',
      password: 'secret123',
      enabled: true,
    );
    final saved = await store.loadAccounts();
    expect(saved.single.hasBiometric, isTrue);
    await tester.pumpWidget(_buildTestApp(store));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));

    final switchTile = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(switchTile.value, isTrue);
  });

  testWidgets('toggling off disables fingerprint login', (tester) async {
    final store = await _buildStore();
    await store.saveAccount(email: 'user@example.com');
    await store.setBiometric(
      email: 'user@example.com',
      password: 'secret123',
      enabled: true,
    );
    await tester.pumpWidget(_buildTestApp(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    final switchTile = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(switchTile.value, isFalse);
    final accounts = await store.loadAccounts();
    expect(accounts.single.hasBiometric, isFalse);
    expect(await store.biometricPassword('user@example.com'), isNull);
    expect(find.text('Fingerprint login disabled'), findsOneWidget);
  });

  testWidgets('toggling on when biometric unavailable shows message', (
    tester,
  ) async {
    final store = await _buildStore();
    await store.saveAccount(email: 'user@example.com');
    await tester.pumpWidget(_buildTestApp(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    final switchTile = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(switchTile.value, isFalse);
    expect(
      find.text('Biometric authentication is not available on this device'),
      findsOneWidget,
    );
  });
}
