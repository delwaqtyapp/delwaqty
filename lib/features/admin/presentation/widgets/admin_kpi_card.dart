import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/features/admin/presentation/widgets/admin_card.dart';

/// KPI statistic card. Layout is mathematically overflow-safe: leading icon
/// chip is fixed size, the value uses a FittedBox and the label ellipsizes.
class AdminKpiCard extends StatelessWidget {
  const AdminKpiCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.color = AppColors.brandPurple,
    this.delta,
    this.deltaUp = true,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final String? delta;
  final bool deltaUp;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.72)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1035),
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (delta != null) ...[
                      const SizedBox(width: 6),
                      Icon(
                        deltaUp
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 15,
                        color: deltaUp
                            ? AppColors.successLight
                            : AppColors.errorLight,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact labelled info row used inside admin cards.
class AdminInfoRow extends ConsumerWidget {
  const AdminInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: const Color(0xFF6B7280)),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1035),
            ),
          ),
        ),
      ],
    );
  }
}