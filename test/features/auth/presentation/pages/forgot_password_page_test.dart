import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/_shared/auth/presentation/pages/forgot_password_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'WhatsApp confirmation precedes a real password reset; no email flow',
    (tester) async {
      final submissions = <List<String>>[];
      var verifications = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            whatsappResetVerifierProvider.overrideWithValue((
              context,
              phone,
            ) async {
              verifications++;
              expect(phone, '01000000001');
              return 'test-private-challenge';
            }),
            whatsappPasswordResetProvider.overrideWithValue((
              phone,
              challenge,
              password,
            ) async {
              submissions.add([phone, challenge, password]);
            }),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: ForgotPasswordPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.email_outlined), findsNothing);
      expect(find.widgetWithText(TextFormField, 'New Password'), findsNothing);
      await tester.enterText(find.byType(TextFormField), '01000000001');
      await tester.ensureVisible(find.text('Verify via WhatsApp'));
      await tester.tap(find.text('Verify via WhatsApp'));
      await tester.pumpAndSettle();
      expect(verifications, 1);
      expect(submissions, isEmpty);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New Password'),
        'ExampleTestPassword123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        'ExampleTestPassword123',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Reset Password').last);
      await tester.tap(find.text('Reset Password').last);
      await tester.pumpAndSettle();
      expect(submissions, [
        ['01000000001', 'test-private-challenge', 'ExampleTestPassword123'],
      ]);
      expect(
        find.text('Your password has been changed. You can sign in now.'),
        findsOneWidget,
      );
    },
  );
  testWidgets('rapid reset taps start only one WhatsApp challenge', (
    tester,
  ) async {
    final reply = Completer<String?>();
    var requests = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          whatsappResetVerifierProvider.overrideWithValue((context, phone) {
            requests++;
            return reply.future;
          }),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: ForgotPasswordPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '01000000001');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final tap = tester
        .widget<InkWell>(
          find
              .ancestor(
                of: find.text('Verify via WhatsApp'),
                matching: find.byType(InkWell),
              )
              .first,
        )
        .onTap!;
    tap();
    tap();
    expect(requests, 1);
    reply.complete(null);
    await tester.pumpAndSettle();
  });
}
