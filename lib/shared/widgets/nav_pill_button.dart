import 'package:flutter/material.dart';

class NavPillButton extends StatelessWidget {
  const NavPillButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
    this.icon,
    this.labelVisible = true,
  });

  final IconData? icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  final bool labelVisible;

  @override
  Widget build(BuildContext context) {
    final showLabel = isSelected || labelVisible;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 24,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              if (showLabel) const SizedBox(width: 8),
            ],
            if (showLabel)
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}