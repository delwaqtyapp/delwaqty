import 'package:delwaqty/domain/entities/expense.dart';

abstract class ExpenseRepository {
  Future<List<Expense>> getExpenses({
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
    int limit = 20,
    int offset = 0,
  });

  Future<Expense> getExpenseById(String id);

  Future<Expense> createExpense({
    required String title,
    required double amount,
    required String categoryId,
    required DateTime date,
    String? note,
    String? receiptUrl,
    bool isRecurring = false,
    ExpenseType type = ExpenseType.expense,
  });

  Future<Expense> updateExpense({
    required String id,
    String? title,
    double? amount,
    String? categoryId,
    DateTime? date,
    String? note,
  });

  Future<void> deleteExpense(String id);

  Future<double> getTotalExpenses({
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<Map<String, double>> getExpensesByCategory({
    DateTime? startDate,
    DateTime? endDate,
  });
}
