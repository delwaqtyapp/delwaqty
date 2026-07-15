import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/domain/entities/expense.dart';
import 'package:delwaqty/features/expenses/expenses_module.dart';
import 'package:delwaqty/shared/widgets/app_search_bar.dart';
import 'package:delwaqty/shared/widgets/expense_list_tile.dart';
import 'package:delwaqty/shared/widgets/loading_skeleton.dart';
import 'package:delwaqty/shared/widgets/error_state.dart';
import 'package:delwaqty/shared/widgets/empty_state.dart';
import 'package:delwaqty/shared/widgets/confirm_dialog.dart';
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
                      return ExpenseListTile(
                        expense: expense,
                        category: category.isNotEmpty ? category.first : null,
                        onTap: () =>
                            context.push('/expenses/${expense.id}'),
                        onDismissed: () async {
                          final confirmed = await ConfirmDialog.show(
                            context,
                            title: l10n.deleteExpense,
                            message: l10n.deleteExpenseConfirm,
                            confirmLabel: l10n.delete,
                            cancelLabel: l10n.cancel,
                            isDestructive: true,
                          );
                          if (confirmed && context.mounted) {
                            final repo = ref.read(expenseRepositoryProvider);
                            await repo.deleteExpense(expense.id);
                            ref.invalidate(expensesProvider);
                            ref.invalidate(totalExpensesProvider);
                          } else {
                            ref.invalidate(expensesProvider);
                          }
                        },
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
