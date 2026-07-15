import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/domain/entities/expense.dart';
import 'package:delwaqty/domain/entities/category.dart';
import 'package:delwaqty/data/providers.dart';
import 'package:delwaqty/shared/widgets/loading_skeleton.dart';
import 'package:delwaqty/shared/widgets/error_state.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class ExpenseDetailPage extends ConsumerWidget {
  const ExpenseDetailPage({super.key, required this.expenseId});

  final String expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final expensesAsync = ref.watch(expensesProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return expensesAsync.when(
      data: (expenses) {
        final expense =
            expenses.where((e) => e.id == expenseId).firstOrNull;
        if (expense == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.expenseDetail)),
            body: ErrorState(
              message: l10n.expenseNotFound,
              onRetry: () => context.pop(),
              retryLabel: l10n.back,
            ),
          );
        }

        final categories = categoriesAsync.valueOrNull ?? [];
        final category =
            categories.where((c) => c.id == expense.categoryId).firstOrNull;
        final categoryColor =
            category?.categoryColor ?? Theme.of(context).colorScheme.primary;
        final categoryName = category?.name ?? 'Other';

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.expenseDetail),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_rounded),
                onPressed: () =>
                    context.push('/expenses/${expense.id}/edit'),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => _confirmDelete(context, ref, expense, l10n),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getTypeIcon(expense.type),
                        size: 32,
                        color: categoryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _formatAmount(expense, context),
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _getAmountColor(expense, context),
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      expense.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: categoryColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        categoryName,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: categoryColor,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow(
                      icon: Icons.calendar_today_rounded,
                      label: l10n.date,
                      value: _formatFullDate(expense.date, context),
                    ),
                    const Divider(height: 24),
                    _DetailRow(
                      icon: Icons.category_rounded,
                      label: l10n.category,
                      value: categoryName,
                    ),
                    const Divider(height: 24),
                    _DetailRow(
                      icon: Icons.label_rounded,
                      label: l10n.type,
                      value: _getTypeLabel(expense.type, l10n),
                    ),
                    if (expense.isRecurring) ...[
                      const Divider(height: 24),
                      _DetailRow(
                        icon: Icons.repeat_rounded,
                        label: l10n.recurring,
                        value: l10n.yes,
                      ),
                    ],
                  ],
                ),
              ),
              if (expense.note != null && expense.note!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.note,
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        expense.note!,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ],
              if (expense.receiptUrl != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.receipt,
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          expense.receiptUrl!,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: double.infinity,
                            height: 100,
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            child: Icon(
                              Icons.receipt_long_rounded,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                '${l10n.createdAt}: ${_formatFullDate(expense.createdAt, context)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.expenseDetail)),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: SkeletonCard(height: 200),
        ),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.expenseDetail)),
        body: ErrorState(
          message: e.toString(),
          onRetry: () => context.pop(),
          retryLabel: l10n.back,
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Expense expense,
    AppLocalizations l10n,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteExpense),
        content: Text(l10n.deleteExpenseConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final repo = ref.read(expenseRepositoryProvider);
              await repo.deleteExpense(expense.id);
              ref.invalidate(expensesProvider);
              ref.invalidate(totalExpensesProvider);
              if (context.mounted) {
                context.pop();
              }
            },
            child: Text(
              l10n.delete,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getAmountColor(Expense expense, BuildContext context) {
    return switch (expense.type) {
      ExpenseType.income => Colors.green,
      ExpenseType.expense => Theme.of(context).colorScheme.error,
      ExpenseType.transfer => Theme.of(context).colorScheme.primary,
    };
  }

  String _formatAmount(Expense expense, BuildContext context) {
    final prefix = switch (expense.type) {
      ExpenseType.income => '+',
      ExpenseType.transfer => '↕',
      ExpenseType.expense => '-',
    };
    return '$prefix\$${expense.amount.toStringAsFixed(2)}';
  }

  IconData _getTypeIcon(ExpenseType type) {
    return switch (type) {
      ExpenseType.income => Icons.arrow_downward_rounded,
      ExpenseType.transfer => Icons.swap_horiz_rounded,
      ExpenseType.expense => Icons.arrow_upward_rounded,
    };
  }

  String _getTypeLabel(ExpenseType type, AppLocalizations l10n) {
    return switch (type) {
      ExpenseType.income => l10n.filterIncome,
      ExpenseType.transfer => l10n.filterTransfer,
      ExpenseType.expense => l10n.filterExpense,
    };
  }

  String _formatFullDate(DateTime date, BuildContext context) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}
