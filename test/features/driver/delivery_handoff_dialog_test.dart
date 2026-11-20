import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/delivery_handoff_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Cairo',
    )..addFont(rootBundle.load('assets/fonts/Cairo-400.ttf'))).load();
  });
  for (final pickup in [true, false]) {
    testWidgets(
      'Arabic ${pickup ? 'pickup' : 'recipient'} handoff remains readable',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('capture'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: const Locale('ar'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              theme: ThemeData(fontFamily: 'Cairo'),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    child: const Text('Open'),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) =>
                          DeliveryHandoffDialog(pickup: pickup, code: '012345'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('012345'), findsOneWidget);
        expect(
          tester
              .widget<SelectableText>(find.byType(SelectableText))
              .textDirection,
          TextDirection.ltr,
        );
        await expectLater(
          find.byKey(const ValueKey('capture')),
          matchesGoldenFile(
            'goldens/handoff_${pickup ? 'pickup' : 'recipient'}_ar.png',
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('driver cannot submit a short code and no code is prefilled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const Scaffold(body: DeliveryHandoffInputDialog(pickup: false)),
      ),
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), '012345');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
}
