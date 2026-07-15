import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/data/repositories/mock/mock_expense_repository.dart';

void main() {
  late MockExpenseRepository repo;

  setUp(() {
    repo = MockExpenseRepository();
  });

  group('MockExpenseRepository', () {
    test('getExpenses returns expenses', () async {
      final expenses = await repo.getExpenses();
      expect(expenses, isNotEmpty);
    });

    test('getExpenses filters by category', () async {
      final expenses = await repo.getExpenses(categoryId: '1');
      for (final e in expenses) {
        expect(e.categoryId, '1');
      }
    });

    test('getExpenses respects limit', () async {
      final expenses = await repo.getExpenses(limit: 3);
      expect(expenses.length, lessThanOrEqualTo(3));
    });

    test('getExpenseById returns correct expense', () async {
      final expense = await repo.getExpenseById('1');
      expect(expense.id, '1');
    });

    test('createExpense adds new expense', () async {
      final expense = await repo.createExpense(
        title: 'New Expense',
        amount: 50.0,
        categoryId: '1',
        date: DateTime.now(),
      );
      expect(expense.title, 'New Expense');
      expect(expense.amount, 50.0);
    });

    test('deleteExpense removes expense', () async {
      await repo.deleteExpense('1');
      expect(
        () => repo.getExpenseById('1'),
        throwsA(isA<StateError>()),
      );
    });

    test('getTotalExpenses returns sum', () async {
      final total = await repo.getTotalExpenses();
      expect(total, greaterThan(0));
    });

    test('getExpensesByCategory returns map', () async {
      final byCategory = await repo.getExpensesByCategory();
      expect(byCategory, isNotEmpty);
    });
  });
}
