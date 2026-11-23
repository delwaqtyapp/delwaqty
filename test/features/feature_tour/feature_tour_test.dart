import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/_shared/feature_tour/feature_tour_gate.dart';
import 'package:delwaqty/features/_shared/feature_tour/feature_tour_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: child,
  );
}

void main() {
  testWidgets('FeatureTourPage pages through steps and finishes', (
    tester,
  ) async {
    var done = false;
    const steps = [
      FeatureTourStep(
        icon: Icons.star,
        color: Colors.teal,
        title: 'Step one',
        body: 'First body',
      ),
      FeatureTourStep(
        icon: Icons.done,
        color: Colors.indigo,
        title: 'Step two',
        body: 'Second body',
      ),
    ];

    await tester.pumpWidget(
      _wrap(FeatureTourPage(steps: steps, onDone: () => done = true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Step one'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Step two'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(done, isTrue);
  });

  testWidgets('skip finishes the tour immediately', (tester) async {
    var done = false;
    final steps = buildCustomerTourSteps(
      lookupAppLocalizations(const Locale('en')),
    );

    await tester.pumpWidget(
      _wrap(FeatureTourPage(steps: steps, onDone: () => done = true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Skip'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(done, isTrue);
  });

  testWidgets('customer and merchant tours build all localized steps', (
    tester,
  ) async {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      final l10n = lookupAppLocalizations(locale);
      final customer = buildCustomerTourSteps(l10n);
      final merchant = buildMerchantProductGuideSteps(l10n);
      expect(customer, hasLength(5));
      expect(merchant, hasLength(5));
      for (final step in [...customer, ...merchant]) {
        expect(step.title, isNotEmpty);
        expect(step.body, isNotEmpty);
      }
    }
  });
}
