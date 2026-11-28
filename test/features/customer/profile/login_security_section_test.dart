import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:delwaqty/data/datasources/local/biometric_auth_store.dart';
import 'package:delwaqty/features/customer/profile/presentation/widgets/login_security_section.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

Widget _host(bool owner, List<String> reasons) => ProviderScope(
  overrides: [
    biometricAuthStoreProvider.overrideWithValue(
      BiometricAuthStore(const FlutterSecureStorage()),
    ),
  ],
  child: MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(
      body: LoginSecuritySection(
        userId: 'user-1',
        confirmOwner: (reason) async {
          reasons.add(reason);
          return owner;
        },
      ),
    ),
  ),
);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues(<String, String>{}));

  testWidgets('the saved password is hidden unless the device lock passes', (
    tester,
  ) async {
    final store = BiometricAuthStore(const FlutterSecureStorage());
    await store.saveCredentials(
      userId: 'user-1',
      identifier: 'person@example.com',
      password: 'TestOnlySecret123',
    );
    final reasons = <String>[];
    await tester.pumpWidget(_host(false, reasons));
    await tester.tap(find.text('Show my saved password'));
    await tester.pumpAndSettle();
    expect(reasons, hasLength(1));
    expect(find.text('TestOnlySecret123'), findsNothing);
    expect(find.text('Saved password'), findsNothing);
  });

  testWidgets('after the device lock the saved password is shown', (
    tester,
  ) async {
    final store = BiometricAuthStore(const FlutterSecureStorage());
    await store.saveCredentials(
      userId: 'user-1',
      identifier: 'person@example.com',
      password: 'TestOnlySecret123',
    );
    await tester.pumpWidget(_host(true, <String>[]));
    await tester.tap(find.text('Show my saved password'));
    await tester.pumpAndSettle();
    expect(find.text('TestOnlySecret123'), findsOneWidget);
  });

  testWidgets('with nothing saved the user is told so, not shown a blank', (
    tester,
  ) async {
    await tester.pumpWidget(_host(true, <String>[]));
    await tester.tap(find.text('Show my saved password'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No password is saved'), findsOneWidget);
  });

  testWidgets('setting a password asks the device lock first', (tester) async {
    final reasons = <String>[];
    await tester.pumpWidget(_host(false, reasons));
    await tester.tap(find.text('Set or change login password'));
    await tester.pumpAndSettle();
    expect(reasons, hasLength(1));
    expect(find.text('New Password'), findsNothing);
  });
}
