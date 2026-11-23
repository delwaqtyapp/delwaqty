import 'package:flutter/material.dart';

/// Consistent page title block for admin surfaces (title / subtitle / actions).
class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scale the title down instead of wrapping a long word
        // mid-character on narrow screens.
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1035),
                height: 1.1,
              ),
            ),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              height: 1.4,
            ),
          ),
        ],
      ],
    );
    final hasActions = actions != null && actions!.isNotEmpty;
    // Narrow screens: actions drop to their own wrapped row below the
    // title so they never squeeze it into a character column.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (hasActions && constraints.maxWidth < 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleBlock,
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: actions!),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleBlock),
            if (hasActions) ...[const SizedBox(width: 16), ...actions!],
          ],
        );
      },
    );
  }
}
