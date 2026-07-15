import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/domain/entities/expense.dart';

void main() {
  group('Expense', () {
    test('fromJson creates Expense from JSON', () {
      final json = {
        'id': '1',
        'title': 'Test',
        'amount': 10.0,
        'categoryId': 'cat1',
        'date': '2024-01-15T10:00:00.000',
        'note': 'note',
        'receiptUrl': null,
        'isRecurring': false,
        'type': 'expense',
        'createdAt': '2024-01-15T10:00:00.000',
        'updatedAt': null,
      };

      final expense = Expense.fromJson(json);
      expect(expense.id, '1');
      expect(expense.title, 'Test');
      expect(expense.amount, 10.0);
      expect(expense.type, ExpenseType.expense);
    });

    test('toJson serializes correctly', () {
      final expense = Expense(
        id: '1',
        title: 'Test',
        amount: 10.0,
        categoryId: 'cat1',
        date: DateTime(2024, 1, 15),
        createdAt: DateTime(2024, 1, 15),
      );

      final json = expense.toJson();
      expect(json['id'], '1');
      expect(json['title'], 'Test');
      expect(json['amount'], 10.0);
    });

    test('ExpenseType enum has correct values', () {
      expect(ExpenseType.values.length, 3);
      expect(ExpenseType.expense, isNotNull);
      expect(ExpenseType.income, isNotNull);
      expect(ExpenseType.transfer, isNotNull);
    });
  });
}
