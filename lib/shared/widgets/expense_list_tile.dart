import 'package:flutter/material.dart';
import 'package:delwaqty/domain/entities/expense.dart';
import 'package:delwaqty/domain/entities/category.dart';
import 'package:delwaqty/core/utils/icon_mapper.dart';
import 'package:delwaqty/core/utils/currency_formatter.dart';
import 'package:delwaqty/core/utils/date_formatter.dart';

class ExpenseListTile extends StatelessWidget {
  const ExpenseListTile({
    super.key,
    required this.expense,
    this.category,
    this.onTap,
    this.onDismissed,
  });

  final Expense expense;
  final Category? category;
  final VoidCallback? onTap;
  final VoidCallback? onDismissed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final categoryColor = category?.categoryColor ?? colorScheme.primary;
    final categoryName = category?.name ?? 'Other';
    final iconData = categoryIconFromName(category?.icon ?? 'category');

    final Widget tile = Material(
      color: colorScheme.surfaceContainerLowest,
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
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: categoryColor, size: 24),
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
                      '$categoryName \u00b7 ${DateFormatter.formatRelative(expense.date)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
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
            ],
          ),
        ),
      ),
    );

    if (onDismissed != null) {
      return Dismissible(
        key: ValueKey(expense.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: colorScheme.error,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.delete_rounded,
            color: colorScheme.onError,
          ),
        ),
        confirmDismiss: (_) async => true,
        onDismissed: (_) => onDismissed?.call(),
        child: tile,
      );
    }

    return tile;
  }

  Color _getAmountColor(BuildContext context) {
    return switch (expense.type) {
      ExpenseType.income => Colors.green,
      ExpenseType.expense => Theme.of(context).colorScheme.error,
      ExpenseType.transfer => Theme.of(context).colorScheme.primary,
    };
  }

  String _formatAmount(Expense e) {
    final prefix = switch (e.type) {
      ExpenseType.income => '+',
      ExpenseType.transfer => '\u21c4',
      ExpenseType.expense => '-',
    };
    return '$prefix${CurrencyFormatter.format(e.amount)}';
  }
}
