import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/domain/entities/expense.dart';
import 'package:delwaqty/domain/entities/category.dart';
import 'package:delwaqty/data/providers.dart';
import 'package:delwaqty/shared/widgets/app_search_bar.dart';
import 'package:delwaqty/shared/widgets/loading_skeleton.dart';
import 'package:delwaqty/shared/widgets/error_state.dart';
import 'package:delwaqty/shared/widgets/empty_state.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class ExpensesPage extends ConsumerStatefulWidget {
  const ExpensesPage({super.key});

  @override
  ConsumerState<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends ConsumerState<ExpensesPage> {
  bool _isSearchActive = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  ExpenseType? _selectedType;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final expensesAsync = ref.watch(expensesProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.expenses),
        actions: [
          IconButton(
            icon: Icon(
              _isSearchActive ? Icons.search_off_rounded : Icons.search_rounded,
            ),
            onPressed: () {
              setState(() {
                _isSearchActive = !_isSearchActive;
                if (!_isSearchActive) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isSearchActive)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: AppSearchBar(
                controller: _searchController,
                hint: l10n.searchExpenses,
                autofocus: true,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                  label: l10n.filterAll,
                  selected: _selectedType == null,
                  onTap: () => setState(() => _selectedType = null),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: l10n.filterIncome,
                  selected: _selectedType == ExpenseType.income,
                  onTap: () => setState(
                    () => _selectedType =
                        _selectedType == ExpenseType.income ? null : ExpenseType.income,
                  ),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: l10n.filterExpense,
                  selected: _selectedType == ExpenseType.expense,
                  onTap: () => setState(
                    () => _selectedType =
                        _selectedType == ExpenseType.expense ? null : ExpenseType.expense,
                  ),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: l10n.filterTransfer,
                  selected: _selectedType == ExpenseType.transfer,
                  onTap: () => setState(
                    () => _selectedType =
                        _selectedType == ExpenseType.transfer ? null : ExpenseType.transfer,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: expensesAsync.when(
              data: (expenses) {
                final filtered = expenses.where((e) {
                  final matchesType =
                      _selectedType == null || e.type == _selectedType;
                  final matchesSearch = _searchQuery.isEmpty ||
                      e.title.toLowerCase().contains(_searchQuery);
                  return matchesType && matchesSearch;
                }).toList();

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: l10n.noExpenses,
                    message: l10n.noExpensesMessage,
                    actionLabel: l10n.addExpense,
                    onAction: () => context.push('/expenses/add'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(expensesProvider);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final expense = filtered[index];
                      final categories = categoriesAsync.valueOrNull ?? [];
                      final category = categories
                          .where((c) => c.id == expense.categoryId)
                          .toList();
                      return _ExpenseListTile(
                        expense: expense,
                        category: category.isNotEmpty ? category.first : null,
                        onTap: () =>
                            context.push('/expenses/${expense.id}'),
                      );
                    },
                  ),
                );
              },
              loading: () => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 6,
                itemBuilder: (_, __) => const SkeletonListTile(),
              ),
              error: (e, _) => ErrorState(
                title: l10n.error,
                message: e.toString(),
                onRetry: () => ref.invalidate(expensesProvider),
                retryLabel: l10n.retry,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/expenses/add'),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
        ),
      ),
    );
  }
}

class _ExpenseListTile extends StatelessWidget {
  const _ExpenseListTile({
    required this.expense,
    this.category,
    this.onTap,
  });

  final Expense expense;
  final Category? category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final categoryColor = category?.categoryColor ??
        Theme.of(context).colorScheme.primary;
    final categoryName = category?.name ?? 'Other';

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getTypeIcon(expense.type),
                  color: categoryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$categoryName · ${_formatDate(expense.date, context)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatAmount(expense),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _getAmountColor(context),
                    ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getAmountColor(BuildContext context) {
    return switch (expense.type) {
      ExpenseType.income => Colors.green,
      ExpenseType.expense => Theme.of(context).colorScheme.error,
      ExpenseType.transfer => Theme.of(context).colorScheme.primary,
    };
  }

  String _formatAmount(Expense expense) {
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

  String _formatDate(DateTime date, BuildContext context) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
