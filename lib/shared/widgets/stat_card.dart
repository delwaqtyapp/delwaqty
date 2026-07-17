import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.color,
    this.trend,
    this.trendIsPositive,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? color;
  final String? trend;
  final bool? trendIsPositive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveColor = color ?? colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: effectiveColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 20, color: effectiveColor),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (subtitle != null || trend != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                if (subtitle != null)
                  Expanded(
                    child: Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (trend != null) ...[
                  Icon(
                    trendIsPositive == true
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    size: 16,
                    color: trendIsPositive == true ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    trend!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: trendIsPositive == true
                          ? Colors.green
                          : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
