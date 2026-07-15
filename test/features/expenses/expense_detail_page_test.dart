import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/expenses/presentation/pages/expense_detail_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

Widget buildTestWidget({required String expenseId}) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ExpenseDetailPage(expenseId: expenseId)),
    ),
  );
}

void main() {
  group('ExpenseDetailPage', () {
    testWidgets('renders expense details', (tester) async {
      await tester.pumpWidget(buildTestWidget(expenseId: '1'));
      await tester.pumpAndSettle();

      expect(find.text('Expense Detail'), findsOneWidget);
      expect(find.text('Grocery Shopping'), findsOneWidget);
      expect(find.text('-\$85.50'), findsOneWidget);
    });

    testWidgets('shows category name', (tester) async {
      await tester.pumpWidget(buildTestWidget(expenseId: '1'));
      await tester.pumpAndSettle();

      expect(find.text('Groceries'), findsWidgets);
    });

    testWidgets('shows amount with correct format', (tester) async {
      await tester.pumpWidget(buildTestWidget(expenseId: '1'));
      await tester.pumpAndSettle();

      expect(find.text('-\$85.50'), findsOneWidget);
    });

    testWidgets('shows income amount with plus prefix', (tester) async {
      await tester.pumpWidget(buildTestWidget(expenseId: '4'));
      await tester.pumpAndSettle();

      expect(find.text('Salary'), findsOneWidget);
      expect(find.text('+\$5,000.00'), findsOneWidget);
    });

    testWidgets('shows date row', (tester) async {
      await tester.pumpWidget(buildTestWidget(expenseId: '1'));
      await tester.pumpAndSettle();

      expect(find.text('Date'), findsOneWidget);
    });

    testWidgets('shows category row', (tester) async {
      await tester.pumpWidget(buildTestWidget(expenseId: '1'));
      await tester.pumpAndSettle();

      expect(find.text('Category'), findsOneWidget);
    });

    testWidgets('shows type row', (tester) async {
      await tester.pumpWidget(buildTestWidget(expenseId: '1'));
      await tester.pumpAndSettle();

      expect(find.text('Type'), findsOneWidget);
    });

    testWidgets('shows note when present', (tester) async {
      await tester.pumpWidget(buildTestWidget(expenseId: '1'));
      await tester.pumpAndSettle();

      expect(find.text('Weekly groceries'), findsOneWidget);
    });

    testWidgets('shows edit button', (tester) async {
      await tester.pumpWidget(buildTestWidget(expenseId: '1'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
    });

    testWidgets('shows delete button', (tester) async {
      await tester.pumpWidget(buildTestWidget(expenseId: '1'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    });

    testWidgets('delete button shows confirmation dialog', (tester) async {
      await tester.pumpWidget(buildTestWidget(expenseId: '1'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Delete Expense'), findsOneWidget);
      expect(
        find.text(
          'Are you sure you want to delete this expense? This action cannot be undone.',
        ),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsWidgets);
    });

    testWidgets('cancel button dismisses delete dialog', (tester) async {
      await tester.pumpWidget(buildTestWidget(expenseId: '1'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Delete Expense'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Expense'), findsNothing);
    });

    testWidgets('shows recurring badge for recurring expense', (tester) async {
      await tester.pumpWidget(buildTestWidget(expenseId: '6'));
      await tester.pumpAndSettle();

      expect(find.text('Netflix Subscription'), findsOneWidget);
      expect(find.text('Recurring'), findsOneWidget);
      expect(find.text('Yes'), findsOneWidget);
    });

    testWidgets('does not show recurring for non-recurring expense', (tester) async {
      await tester.pumpWidget(buildTestWidget(expenseId: '1'));
      await tester.pumpAndSettle();

      expect(find.text('Recurring'), findsNothing);
    });

    testWidgets('shows not found state for invalid id', (tester) async {
      await tester.pumpWidget(buildTestWidget(expenseId: '999'));
      await tester.pumpAndSettle();

      expect(find.text('Expense not found'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('shows created at text', (tester) async {
      await tester.pumpWidget(buildTestWidget(expenseId: '1'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Created at:'), findsOneWidget);
    });
  });
}
