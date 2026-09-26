import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_quick_actions_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

void main() {
  testWidgets('shows a Categories quick action tiled in the platform section', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: AdminQuickActionsPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Categories'), findsOneWidget);
    expect(find.byIcon(Icons.category_rounded), findsOneWidget);
  });
}