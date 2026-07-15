import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/domain/entities/expense.dart';
import 'package:delwaqty/features/expenses/presentation/pages/add_expense_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

Widget buildTestWidget() {
  return const ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: AddExpensePage()),
    ),
  );
}

void main() {
  group('AddExpensePage', () {
    testWidgets('renders form fields', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Amount'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Date'), findsOneWidget);
      expect(find.text('Note'), findsOneWidget);
      expect(find.text('Type'), findsOneWidget);
    });

    testWidgets('renders segmented button for expense types', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(SegmentedButton<ExpenseType>), findsOneWidget);
      expect(find.text('Expense'), findsWidgets);
      expect(find.text('Income'), findsWidgets);
      expect(find.text('Transfer'), findsWidgets);
    });

    testWidgets('renders save button in app bar', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('validation: empty title shows error', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Title is required'), findsOneWidget);
    });

    testWidgets('validation: empty amount shows error', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'Test Title',
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Amount is required'), findsOneWidget);
    });

    testWidgets('validation: zero amount shows error', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, 'Test Title');
      await tester.enterText(textFields.at(1), '0');

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Amount must be greater than 0'), findsOneWidget);
    });

    testWidgets('validation: negative amount shows error', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, 'Test Title');
      await tester.enterText(textFields.at(1), '-5');

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Amount must be greater than 0'), findsOneWidget);
    });

    testWidgets('validation: non-numeric amount shows error', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, 'Test Title');
      await tester.enterText(textFields.at(1), 'abc');

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Amount must be greater than 0'), findsOneWidget);
    });

    testWidgets('can enter title text', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Lunch');
      expect(find.text('Lunch'), findsOneWidget);
    });

    testWidgets('can enter amount text', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(1), '25.50');
      expect(find.text('25.50'), findsOneWidget);
    });

    testWidgets('can enter note text', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).last, 'Some note');
      expect(find.text('Some note'), findsOneWidget);
    });

    testWidgets('valid form passes validation', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Test Expense');
      await tester.enterText(find.byType(TextFormField).at(1), '50');

      final categoryDropdown = find.byType(DropdownButtonFormField<String>);
      if (categoryDropdown.evaluate().isNotEmpty) {
        await tester.tap(categoryDropdown);
        await tester.pumpAndSettle();

        final firstCategory = find.text('Groceries');
        if (firstCategory.evaluate().isNotEmpty) {
          await tester.tap(firstCategory);
          await tester.pumpAndSettle();
        }
      }

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Title is required'), findsNothing);
      expect(find.text('Amount is required'), findsNothing);
    });
  });
}
