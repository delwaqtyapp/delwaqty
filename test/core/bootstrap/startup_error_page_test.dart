import 'package:delwaqty/config/config_validator.dart';
import 'package:delwaqty/core/bootstrap/startup_error_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('StartupErrorPage renders without a Directionality ancestor', (
    tester,
  ) async {
    // Regression: this page is runApp'ed directly (no MaterialApp), and its
    // Scrollable inserts a RawScrollbar that used to throw
    // 'No Directionality widget found' and render pure white on web.
    const result = ValidationResult(
      errors: ['FIREBASE_PROJECT_ID is missing or empty'],
      warnings: ['GOOGLE_MAPS_API_KEY is not set'],
    );

    await tester.pumpWidget(const StartupErrorPage(result: result));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Configuration Error'), findsOneWidget);
    expect(
      find.text('FIREBASE_PROJECT_ID is missing or empty'),
      findsOneWidget,
    );
  });
}
