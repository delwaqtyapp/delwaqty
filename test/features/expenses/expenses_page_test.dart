import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/expenses/presentation/pages/expenses_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

Widget buildTestWidget() {
  return const ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ExpensesPage(),
    ),
  );
}

void main() {
  group('ExpensesPage', () {
    testWidgets('renders with loading skeleton', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
    });

    testWidgets('renders expense list from mock data', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Grocery Shopping'), findsOneWidget);
      expect(find.text('Electric Bill'), findsOneWidget);
      expect(find.text('Coffee Shop'), findsOneWidget);
      expect(find.text('Salary'), findsOneWidget);
    });

    testWidgets('filter chips are present', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expense'), findsOneWidget);
      expect(find.text('Transfer'), findsOneWidget);
    });

    testWidgets('Income filter shows only income expenses', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();

      expect(find.text('Salary'), findsOneWidget);
      expect(find.text('Grocery Shopping'), findsNothing);
      expect(find.text('Electric Bill'), findsNothing);
    });

    testWidgets('Expense filter shows only expense type expenses', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Expense'));
      await tester.pumpAndSettle();

      expect(find.text('Grocery Shopping'), findsOneWidget);
      expect(find.text('Electric Bill'), findsOneWidget);
      expect(find.text('Coffee Shop'), findsOneWidget);
      expect(find.text('Gas Station'), findsOneWidget);
      expect(find.text('Netflix Subscription'), findsOneWidget);
      expect(find.text('Restaurant Dinner'), findsOneWidget);
      expect(find.text('Online Shopping'), findsOneWidget);
      expect(find.text('Salary'), findsNothing);
    });

    testWidgets('tapping selected filter deselects it', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();

      expect(find.text('Salary'), findsOneWidget);

      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();

      expect(find.text('Salary'), findsOneWidget);
      expect(find.text('Grocery Shopping'), findsOneWidget);
    });

    testWidgets('search bar filters expenses by title', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Coffee');
      await tester.pumpAndSettle();

      expect(find.text('Coffee Shop'), findsOneWidget);
      expect(find.text('Grocery Shopping'), findsNothing);
      expect(find.text('Electric Bill'), findsNothing);
    });

    testWidgets('search is case insensitive', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'salary');
      await tester.pumpAndSettle();

      expect(find.text('Salary'), findsOneWidget);
    });

    testWidgets('clearing search shows all expenses', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Coffee');
      await tester.pumpAndSettle();

      expect(find.text('Coffee Shop'), findsOneWidget);
      expect(find.text('Grocery Shopping'), findsNothing);

      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      expect(find.text('Grocery Shopping'), findsOneWidget);
      expect(find.text('Coffee Shop'), findsOneWidget);
    });

    testWidgets('FAB is present', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });

    testWidgets('empty state shows when filtering yields no results', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Transfer'));
      await tester.pumpAndSettle();

      expect(find.text('No expenses yet'), findsOneWidget);
    });

    testWidgets('shows expense amount with correct format', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('-\$85.50'), findsOneWidget);
      expect(find.text('-\$120.00'), findsOneWidget);
    });
  });
}
