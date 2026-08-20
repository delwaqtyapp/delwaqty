import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:delwaqty/data/datasources/local/biometric_auth_store.dart';
import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/domain/repositories/auth_repository.dart';
import 'package:delwaqty/domain/repositories/user_repository.dart';
import 'package:delwaqty/domain/usecases/auth/auth_usecases.dart';
import 'package:delwaqty/domain/usecases/user/get_user.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/customer/settings/presentation/pages/privacy/fingerprint_login_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class _FakeAuthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => AuthState.authenticated(user: authUser);
}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUserRepository extends Mock implements UserRepository {}

late User authUser;
late MockAuthRepository mockAuthRepo;
late MockUserRepository mockUserRepo;
late BiometricAuthStore store;

final baseUser = User(
  id: 'user-123',
  email: 'user@example.com',
  createdAt: DateTime(2024, 1, 15),
);

Widget _buildTestApp() {
  return ProviderScope(
    overrides: [
      biometricAuthStoreProvider.overrideWithValue(store),
      authStateProvider.overrideWith(_FakeAuthNotifier.new),
      authRepositoryProvider.overrideWithValue(mockAuthRepo),
      userRepositoryProvider.overrideWithValue(mockUserRepo),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('en'),
      home: FingerprintLoginPage(),
    ),
  );
}

void main() {
  setUp(() {
    authUser = baseUser;
    mockAuthRepo = MockAuthRepository();
    mockUserRepo = MockUserRepository();
    store = BiometricAuthStore(const FlutterSecureStorage());
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    when(
      () => mockAuthRepo.updateBiometricEnabled(
        userId: any(named: 'userId'),
        enabled: any(named: 'enabled'),
      ),
    ).thenAnswer((_) async {});
    when(() => mockUserRepo.getCurrentUser()).thenAnswer((_) async => authUser);
  });

  testWidgets('shows fingerprint switch disabled when not saved', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    final switchTile = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(switchTile.value, isFalse);
  });

  testWidgets('shows fingerprint switch enabled when biometric saved', (
    tester,
  ) async {
    authUser = baseUser.copyWith(isBiometricEnabled: true);
    await store.saveCredentials(
      userId: 'user-123',
      email: 'user@example.com',
      password: 'secret123',
    );
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    final switchTile = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(switchTile.value, isTrue);
  });

  testWidgets('toggling off disables fingerprint login', (tester) async {
    authUser = baseUser.copyWith(isBiometricEnabled: true);
    await store.saveCredentials(
      userId: 'user-123',
      email: 'user@example.com',
      password: 'secret123',
    );
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    final switchTile = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(switchTile.value, isFalse);
    expect(await store.activeCredentials(), isNull);
    expect(find.text('Fingerprint login disabled'), findsOneWidget);
  });

  testWidgets('toggling on when biometric unavailable shows message', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());
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
