import 'dart:io';

import 'package:delwaqty/features/admin/presentation/widgets/driver_document_review_dialog.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('Cairo')
      ..addFont(rootBundle.load('assets/fonts/Cairo-400.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  final docs = [
    {
      'doc_type': 'driving_license',
      'status': 'pending',
      'file_url': 'private/license.jpg',
    },
    {
      'doc_type': 'vehicle_registration',
      'status': 'pending',
      'file_url': 'private/registration.jpg',
    },
  ];

  Future<void> openReview(
    WidgetTester tester,
    List<Map<String, dynamic>> documents,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final imageBytes = File('test/fixtures/private_document.png')
        .readAsBytesSync();
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
              builder: (context) {
                return TextButton(
                  onPressed: () => showDialog<bool>(
                    context: context,
                    builder: (_) => DriverDocumentReviewDialog(
                      documents: documents,
                      loadDocument: (_) async => imageBytes,
                    ),
                  ),
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        MemoryImage(imageBytes),
        tester.element(find.byType(Scaffold).first),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('approval requires both documents and review acknowledgement', (
    tester,
  ) async {
    await openReview(tester, docs);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await expectLater(
      find.byKey(const ValueKey('capture')),
      matchesGoldenFile('goldens/driver_document_review_ar.png'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing document blocks approval and stays readable', (
    tester,
  ) async {
    await openReview(tester, docs.take(1).toList());
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).onChanged,
      isNull,
    );
    await expectLater(
      find.byKey(const ValueKey('capture')),
      matchesGoldenFile('goldens/driver_document_review_missing_ar.png'),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('missing private document paths cannot be approved', (
    tester,
  ) async {
    await openReview(
      tester,
      docs.map((doc) => {...doc, 'file_url': ''}).toList(),
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).onChanged,
      isNull,
    );
  });
}
