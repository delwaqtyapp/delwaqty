import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/domain/entities/expense.dart';
import 'package:delwaqty/domain/entities/category.dart';
import 'package:delwaqty/domain/repositories/expense_repository.dart';
import 'package:delwaqty/domain/repositories/category_repository.dart';
import 'package:delwaqty/data/repositories/mock/mock_expense_repository.dart';
import 'package:delwaqty/data/repositories/mock/mock_category_repository.dart';
import 'package:delwaqty/features/expenses/presentation/pages/expenses_page.dart';
import 'package:delwaqty/features/expenses/presentation/pages/add_expense_page.dart';
import 'package:delwaqty/features/expenses/presentation/pages/expense_detail_page.dart';
import 'package:delwaqty/features/categories/presentation/pages/categories_page.dart';
import 'package:delwaqty/features/categories/presentation/pages/add_category_page.dart';
import 'package:delwaqty/features/reports/presentation/pages/reports_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return MockExpenseRepository();
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return MockCategoryRepository();
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

final totalExpensesProvider = FutureProvider.autoDispose<double>((ref) async {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.getTotalExpenses();
});

final expensesByCategoryProvider =
    FutureProvider.autoDispose<Map<String, double>>((ref) async {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.getExpensesByCategory();
});

class ExpensesModule extends FeatureModule {
  @override
  String get id => 'expenses';

  @override
  String name(BuildContext context) => AppLocalizations.of(context).expenses;

  @override
  IconData get icon => Icons.receipt_long_outlined;

  @override
  bool get isNavModule => true;

  @override
  int get navPriority => 20;

  @override
  StatefulShellBranch? buildBranch() {
    return StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/expenses',
          name: 'expenses',
          builder: (context, state) => const ExpensesPage(),
        ),
      ],
    );
  }

  @override
  List<RouteBase> get shellSubRoutes => [
        GoRoute(
          path: '/expenses/add',
          name: 'add-expense',
          builder: (context, state) => const AddExpensePage(),
        ),
        GoRoute(
          path: '/expenses/:id/edit',
          name: 'edit-expense',
          builder: (context, state) => AddExpensePage(
            expenseId: state.pathParameters['id'],
          ),
        ),
        GoRoute(
          path: '/expenses/:id',
          name: 'expense-detail',
          builder: (context, state) => ExpenseDetailPage(
            expenseId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/categories',
          name: 'categories',
          builder: (context, state) => const CategoriesPage(),
        ),
        GoRoute(
          path: '/categories/add',
          name: 'add-category',
          builder: (context, state) {
            final category = state.extra as Category?;
            return AddCategoryPage(existingCategory: category);
          },
        ),
        GoRoute(
          path: '/reports',
          name: 'reports',
          builder: (context, state) => const ReportsPage(),
        ),
      ];

  @override
  List<Override> providerOverrides(Ref ref) => [
        expenseRepositoryProvider.overrideWithValue(MockExpenseRepository()),
        categoryRepositoryProvider.overrideWithValue(MockCategoryRepository()),
      ];

  @override
  List<DrawerEntry> get drawerEntries => [
        DrawerEntry(
          id: 'expenses',
          label: (ctx) => AppLocalizations.of(ctx).expenses,
          icon: Icons.receipt_long_outlined,
          onTap: (ctx, ref) {
            Navigator.of(ctx).pop();
            ctx.go('/expenses');
          },
        ),
        DrawerEntry(
          id: 'categories',
          label: (ctx) => AppLocalizations.of(ctx).categories,
          icon: Icons.category_outlined,
          onTap: (ctx, ref) {
            Navigator.of(ctx).pop();
            ctx.push('/categories');
          },
        ),
        DrawerEntry(
          id: 'reports',
          label: (ctx) => AppLocalizations.of(ctx).reports,
          icon: Icons.bar_chart_outlined,
          onTap: (ctx, ref) {
            Navigator.of(ctx).pop();
            ctx.push('/reports');
          },
        ),
      ];
}
