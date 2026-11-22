import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/social_auth_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in ['en', 'ar']) {
    testWidgets('only Google social sign-in is available in $locale', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale(locale),
          home: Scaffold(body: SocialAuthButtons(onGoogle: () => calls++)),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(SocialAuthButtons));
      final l10n = AppLocalizations.of(context);
      expect(find.text(l10n.loginWithFacebook), findsNothing);
      expect(find.text(l10n.loginWithGoogle), findsOneWidget);
      await tester.tap(find.text(l10n.loginWithGoogle));
      expect(calls, 1);
    });
  }
}
