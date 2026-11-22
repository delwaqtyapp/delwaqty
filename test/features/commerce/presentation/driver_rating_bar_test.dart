import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/driver_rating_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Cairo',
    )..addFont(rootBundle.load('assets/fonts/Cairo-400.ttf'))).load();
  });

  Widget app({
    int rating = 0,
    ValueChanged<int>? onRatingChanged,
    VoidCallback? onSubmit,
  }) {
    return RepaintBoundary(
      key: const ValueKey('capture'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData(fontFamily: 'Cairo'),
        home: Scaffold(
          body: DriverRatingBar(
            rating: rating,
            onRatingChanged: onRatingChanged ?? (_) {},
            controller: TextEditingController(),
            onSubmit: onSubmit ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets('submit stays disabled until a star is picked', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final submit = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(submit.onPressed, isNull);
  });

  testWidgets('Arabic stars+comment submit fires after picking stars', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var rating = 0;
    var submitted = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData(fontFamily: 'Cairo'),
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: RepaintBoundary(
              key: const ValueKey('capture'),
              child: DriverRatingBar(
                rating: rating,
                onRatingChanged: (r) => setState(() => rating = r),
                controller: TextEditingController(),
                onSubmit: () => submitted++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Five stars render; tapping the fourth selects 4.
    expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(5));
    await tester.tap(find.byIcon(Icons.star_outline_rounded).at(3));
    await tester.pumpAndSettle();
    expect(rating, 4);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));

    final submit = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(submit.onPressed, isNotNull);
    await tester.tap(find.byType(FilledButton));
    expect(submitted, 1);
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const ValueKey('capture')),
      matchesGoldenFile('goldens/driver_rating_ar.png'),
    );
    expect(tester.takeException(), isNull);
  });
}
