import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/expenses/expenses_module.dart';
import 'package:delwaqty/features/notifications/notifications_module.dart';
import 'package:delwaqty/data/repositories/mock/mock_expense_repository.dart';
import 'package:delwaqty/data/repositories/mock/mock_category_repository.dart';
import 'package:delwaqty/data/repositories/mock/mock_notification_repository.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        expenseRepositoryProvider.overrideWithValue(MockExpenseRepository()),
        categoryRepositoryProvider.overrideWithValue(MockCategoryRepository()),
        notificationRepositoryProvider.overrideWithValue(MockNotificationRepository()),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('Repository providers', () {
    test('expenseRepositoryProvider returns MockExpenseRepository', () {
      final repo = container.read(expenseRepositoryProvider);
      expect(repo, isA<MockExpenseRepository>());
    });

    test('categoryRepositoryProvider returns MockCategoryRepository', () {
      final repo = container.read(categoryRepositoryProvider);
      expect(repo, isA<MockCategoryRepository>());
    });

    test('notificationRepositoryProvider returns MockNotificationRepository', () {
      final repo = container.read(notificationRepositoryProvider);
      expect(repo, isA<MockNotificationRepository>());
    });

    test('expensesProvider returns list of expenses', () async {
      final expenses = await container.read(expensesProvider.future);
      expect(expenses, isNotEmpty);
    });

    test('categoriesProvider returns list of categories', () async {
      final categories = await container.read(categoriesProvider.future);
      expect(categories, isNotEmpty);
    });

    test('notificationsProvider returns list of notifications', () async {
      final notifications = await container.read(notificationsProvider.future);
      expect(notifications, isNotEmpty);
    });

    test('unreadCountProvider returns count', () async {
      final count = await container.read(unreadCountProvider.future);
      expect(count, greaterThanOrEqualTo(0));
    });

    test('totalExpensesProvider returns total', () async {
      final total = await container.read(totalExpensesProvider.future);
      expect(total, greaterThanOrEqualTo(0.0));
    });

    test('expensesByCategoryProvider returns map', () async {
      final byCategory = await container.read(expensesByCategoryProvider.future);
      expect(byCategory, isA<Map<String, double>>());
    });
  });
}
