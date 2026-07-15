import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/domain/entities/expense.dart';
import 'package:delwaqty/domain/entities/category.dart';
import 'package:delwaqty/features/expenses/expenses_module.dart';
import 'package:delwaqty/shared/widgets/stat_card.dart';
import 'package:delwaqty/shared/widgets/section_header.dart';
import 'package:delwaqty/shared/widgets/loading_skeleton.dart';
import 'package:delwaqty/shared/widgets/empty_state.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final expensesAsync = ref.watch(expensesProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final totalAsync = ref.watch(totalExpensesProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(expensesProvider);
          ref.invalidate(totalExpensesProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  l10n.welcome,
                  style: context.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: totalAsync.when(
                  data: (total) => _buildSummaryCards(context, total, l10n),
                  loading: () => _buildLoadingCards(context),
                  error: (e, _) => const SizedBox.shrink(),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
            SliverToBoxAdapter(
              child: SectionHeader(
                title: l10n.settings,
                actionLabel: 'See All',
                onAction: () {},
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 8),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 100,
                child: categoriesAsync.when(
                  data: (categories) => _buildCategoriesList(
                    context,
                    categories,
                  ),
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (e, _) => const SizedBox.shrink(),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 16),
            ),
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Recent Activity',
                actionLabel: 'See All',
                onAction: () {},
              ),
            ),
            expensesAsync.when(
              data: (expenses) {
                if (expenses.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: 'No expenses yet',
                      message:
                          'Start tracking your expenses by adding your first entry.',
                      actionLabel: 'Add Expense',
                      onAction: () {},
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final expense = expenses[index];
                      return _ExpenseTile(
                        expense: expense,
                        categories: categoriesAsync.valueOrNull ?? [],
                      );
                    },
                    childCount: expenses.length > 5 ? 5 : expenses.length,
                  ),
                );
              },
              loading: () => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => const SkeletonListTile(),
                  childCount: 5,
                ),
              ),
              error: (e, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Error loading expenses',
                  message: e.toString(),
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(expensesProvider),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(
    BuildContext context,
    double total,
    AppLocalizations l10n,
  ) {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            title: 'Total Spent',
            value: '\$${total.toStringAsFixed(2)}',
            icon: Icons.account_balance_wallet_rounded,
            trend: '-12%',
            trendIsPositive: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            title: 'Budget Left',
            value: '\$${(2000 - total).clamp(0, 2000).toStringAsFixed(2)}',
            icon: Icons.savings_rounded,
            color: Colors.green,
            trend: '15%',
            trendIsPositive: true,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingCards(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: SkeletonCard(height: 100)),
        SizedBox(width: 12),
        Expanded(child: SkeletonCard(height: 100)),
      ],
    );
  }

  Widget _buildCategoriesList(
    BuildContext context,
    List<Category> categories,
  ) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: categories.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        final category = categories[index];
        return _CategoryChip(category: category);
      },
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: category.categoryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: category.categoryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.category_rounded,
            size: 24,
            color: category.categoryColor,
          ),
          const SizedBox(height: 4),
          Text(
            category.name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: category.categoryColor,
                  fontWeight: FontWeight.w500,
                ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({
    required this.expense,
    required this.categories,
  });

  final Expense expense;
  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    final category = categories.where((c) => c.id == expense.categoryId);
    final categoryName = category.isNotEmpty ? category.first.name : 'Other';
    final categoryColor = category.isNotEmpty
        ? category.first.categoryColor
        : Theme.of(context).colorScheme.primary;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: categoryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.receipt_rounded,
          color: categoryColor,
          size: 22,
        ),
      ),
      title: Text(
        expense.title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
      ),
      subtitle: Text(
        categoryName,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
      trailing: Text(
        expense.type == ExpenseType.income
            ? '+\$${expense.amount.toStringAsFixed(2)}'
            : '-\$${expense.amount.toStringAsFixed(2)}',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: expense.type == ExpenseType.income
                  ? Colors.green
                  : Theme.of(context).colorScheme.error,
            ),
      ),
    );
  }
}
