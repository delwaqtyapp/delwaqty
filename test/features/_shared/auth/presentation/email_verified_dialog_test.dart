import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/_shared/auth/presentation/email_verified_dialog.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

Widget _buildHost({Locale locale = const Locale('ar')}) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showEmailVerifiedDialog(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows email-verified confirmation in Arabic and dismisses',
      (tester) async {
    await tester.pumpWidget(_buildHost());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('تم تفعيل بريدك الإلكتروني'), findsOneWidget);
    expect(
      find.textContaining('تم تأكيد بريدك الإلكتروني وتفعيل حسابك'),
      findsOneWidget,
    );
    expect(find.text('حسنًا، المتابعة'), findsOneWidget);

    await tester.tap(find.text('حسنًا، المتابعة'));
    await tester.pumpAndSettle();
    expect(find.text('تم تفعيل بريدك الإلكتروني'), findsNothing);
  });

  testWidgets('shows email-verified confirmation in English', (tester) async {
    await tester.pumpWidget(_buildHost(locale: const Locale('en')));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Your email is confirmed'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });
}