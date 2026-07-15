import 'package:flutter/material.dart';
import 'package:delwaqty/core/utils/currency_formatter.dart';

class BudgetProgressBar extends StatelessWidget {
  const BudgetProgressBar({
    super.key,
    required this.spent,
    required this.budget,
    this.height = 8,
    this.showLabel = true,
    this.animationDuration = const Duration(milliseconds: 800),
    this.categoryColor,
  });

  final double spent;
  final double budget;
  final double height;
  final bool showLabel;
  final Duration animationDuration;
  final Color? categoryColor;

  double get _progress => budget > 0 ? (spent / budget).clamp(0.0, 1.5) : 0.0;
  bool get _isOverBudget => budget > 0 && spent > budget;

  Color _progressColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_isOverBudget) return colorScheme.error;
    final ratio = budget > 0 ? spent / budget : 0.0;
    if (ratio > 0.9) return colorScheme.error;
    if (ratio > 0.7) return Colors.orange;
    return categoryColor ?? Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveColor = _progressColor(context);
    final clampedProgress = _progress.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${CurrencyFormatter.format(spent)} / ${CurrencyFormatter.format(budget)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                Text(
                  '${(_progress * 100).clamp(0, 999).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: effectiveColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: clampedProgress),
            duration: animationDuration,
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: height,
              backgroundColor: colorScheme.surfaceContainerHighest,
              color: effectiveColor,
            ),
          ),
        ),
        if (_isOverBudget)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: colorScheme.error,
                ),
                const SizedBox(width: 4),
                Text(
                  'Over budget by ${CurrencyFormatter.format(spent - budget)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
