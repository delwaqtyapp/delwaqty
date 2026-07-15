import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/domain/entities/expense.dart';
import 'package:delwaqty/domain/entities/category.dart';
import 'package:delwaqty/domain/entities/app_notification.dart';
import 'package:delwaqty/domain/repositories/expense_repository.dart';
import 'package:delwaqty/domain/repositories/category_repository.dart';
import 'package:delwaqty/domain/repositories/notification_repository.dart';
import 'package:delwaqty/data/repositories/mock/mock_expense_repository.dart';
import 'package:delwaqty/data/repositories/mock/mock_category_repository.dart';
import 'package:delwaqty/data/repositories/mock/mock_notification_repository.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return MockExpenseRepository();
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return MockCategoryRepository();
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return MockNotificationRepository();
});

final expensesProvider =
    FutureProvider.autoDispose<List<Expense>>((ref) async {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.getExpenses();
});

final categoriesProvider =
    FutureProvider.autoDispose<List<Category>>((ref) async {
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.getCategories();
});

final notificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getNotifications();
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getUnreadCount();
});

final totalExpensesProvider = FutureProvider.autoDispose<double>((ref) async {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.getTotalExpenses();
});

final expensesByCategoryProvider =
    FutureProvider.autoDispose<Map<String, double>>((ref) async {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.getExpensesByCategory();
});
