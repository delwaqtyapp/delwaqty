import 'package:delwaqty/domain/entities/expense.dart';
import 'package:delwaqty/domain/repositories/expense_repository.dart';

class MockExpenseRepository implements ExpenseRepository {
  final List<Expense> _expenses = [
    Expense(
      id: '1',
      title: 'Grocery Shopping',
      amount: 85.50,
      categoryId: '1',
      date: DateTime.now().subtract(const Duration(days: 1)),
      note: 'Weekly groceries',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Expense(
      id: '2',
      title: 'Electric Bill',
      amount: 120.00,
      categoryId: '2',
      date: DateTime.now().subtract(const Duration(days: 3)),
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    Expense(
      id: '3',
      title: 'Coffee Shop',
      amount: 12.75,
      categoryId: '3',
      date: DateTime.now().subtract(const Duration(days: 5)),
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    Expense(
      id: '4',
      title: 'Salary',
      amount: 5000.00,
      categoryId: '4',
      date: DateTime.now().subtract(const Duration(days: 7)),
      type: ExpenseType.income,
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
    ),
    Expense(
      id: '5',
      title: 'Gas Station',
      amount: 45.00,
      categoryId: '5',
      date: DateTime.now().subtract(const Duration(days: 2)),
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    Expense(
      id: '6',
      title: 'Netflix Subscription',
      amount: 15.99,
      categoryId: '6',
      date: DateTime.now().subtract(const Duration(days: 10)),
      isRecurring: true,
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
    Expense(
      id: '7',
      title: 'Restaurant Dinner',
      amount: 65.00,
      categoryId: '3',
      date: DateTime.now().subtract(const Duration(days: 4)),
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
    Expense(
      id: '8',
      title: 'Online Shopping',
      amount: 199.99,
      categoryId: '7',
      date: DateTime.now().subtract(const Duration(days: 6)),
      createdAt: DateTime.now().subtract(const Duration(days: 6)),
    ),
  ];

  @override
  Future<List<Expense>> getExpenses({
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
    int limit = 20,
    int offset = 0,
  }) async {
    var filtered = List<Expense>.from(_expenses);

    if (startDate != null) {
      filtered = filtered.where((e) => e.date.isAfter(startDate)).toList();
    }
    if (endDate != null) {
      filtered = filtered.where((e) => e.date.isBefore(endDate)).toList();
    }
    if (categoryId != null) {
      filtered = filtered.where((e) => e.categoryId == categoryId).toList();
    }

    filtered.sort((a, b) => b.date.compareTo(a.date));

    if (offset >= filtered.length) return [];
    final end = (offset + limit).clamp(0, filtered.length);
    return filtered.sublist(offset, end);
  }

  @override
  Future<Expense> getExpenseById(String id) async {
    return _expenses.firstWhere((e) => e.id == id);
  }

  @override
  Future<Expense> createExpense({
    required String title,
    required double amount,
    required String categoryId,
    required DateTime date,
    String? note,
    String? receiptUrl,
    bool isRecurring = false,
    ExpenseType type = ExpenseType.expense,
  }) async {
    final expense = Expense(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      amount: amount,
      categoryId: categoryId,
      date: date,
      note: note,
      receiptUrl: receiptUrl,
      isRecurring: isRecurring,
      type: type,
      createdAt: DateTime.now(),
    );
    _expenses.add(expense);
    return expense;
  }

  @override
  Future<Expense> updateExpense({
    required String id,
    String? title,
    double? amount,
    String? categoryId,
    DateTime? date,
    String? note,
  }) async {
    final index = _expenses.indexWhere((e) => e.id == id);
    if (index == -1) throw Exception('Expense not found');

    final existing = _expenses[index];
    final updated = existing.copyWith(
      title: title ?? existing.title,
      amount: amount ?? existing.amount,
      categoryId: categoryId ?? existing.categoryId,
      date: date ?? existing.date,
      note: note ?? existing.note,
      updatedAt: DateTime.now(),
    );
    _expenses[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteExpense(String id) async {
    _expenses.removeWhere((e) => e.id == id);
  }

  @override
  Future<double> getTotalExpenses({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final expenses = await getExpenses(startDate: startDate, endDate: endDate);
    double total = 0;
    for (final e in expenses) {
      if (e.type == ExpenseType.expense) {
        total += e.amount;
      }
    }
    return total;
  }

  @override
  Future<Map<String, double>> getExpensesByCategory({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final expenses = await getExpenses(startDate: startDate, endDate: endDate);
    final map = <String, double>{};
    for (final expense in expenses) {
      if (expense.type == ExpenseType.expense) {
        map[expense.categoryId] =
            (map[expense.categoryId] ?? 0) + expense.amount;
      }
    }
    return map;
  }
}
