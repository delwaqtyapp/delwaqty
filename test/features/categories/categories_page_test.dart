import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/categories/presentation/pages/categories_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

Widget buildTestWidget() {
  return const ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CategoriesPage(),
    ),
  );
}

void main() {
  testWidgets('renders category grid', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('shows first row of category names', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Utilities'), findsOneWidget);
  });

  testWidgets('scrolls to reveal more categories', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Shopping'),
      300,
      scrollable: scrollable,
    );
    expect(find.text('Shopping'), findsOneWidget);
  });

  testWidgets('FAB is present', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('shows app bar with title', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Categories'), findsOneWidget);
  });

  testWidgets('shows add button in app bar', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add_rounded), findsWidgets);
  });

  testWidgets('category cards have icons', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.shopping_cart_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
  });
}
