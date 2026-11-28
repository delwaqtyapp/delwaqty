import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/unconfirmed_phone_banner.dart';

Widget _host(bool needs) => ProviderScope(
  overrides: [
    customerPhoneNeedsConfirmationProvider('cust-1')
        .overrideWith((ref) async => needs),
  ],
  child: const MaterialApp(
    locale: Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(body: UnconfirmedPhoneBanner(customerId: 'cust-1')),
  ),
);

void main() {
  testWidgets('shows the banner and confirm button when the server says so', (
    tester,
  ) async {
    await tester.pumpWidget(_host(true));
    await tester.pumpAndSettle();
    expect(find.text('Phone number not confirmed'), findsOneWidget);
    expect(find.text('The number is right, confirm'), findsOneWidget);
  });

  testWidgets('hidden when the customer is confirmed or the role may not act', (
    tester,
  ) async {
    await tester.pumpWidget(_host(false));
    await tester.pumpAndSettle();
    expect(find.text('Phone number not confirmed'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('an empty customer id never asks the server', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(body: UnconfirmedPhoneBanner(customerId: '')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Phone number not confirmed'), findsNothing);
  });
}
