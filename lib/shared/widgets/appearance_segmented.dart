import 'package:flutter/material.dart';
import 'package:delwaqty/shared/widgets/pressable_scale.dart';

/// A single selectable entry inside an [AppearanceSegmented] control.
class AppearanceSegmentOption<T> {
  const AppearanceSegmentOption(this.value, this.icon, this.label);

  final T value;
  final IconData icon;
  final String label;
}

/// A modern, animated segmented control for the settings' Appearance section.
///
/// Renders the options inside a soft rounded track; the selected option becomes
/// a filled elevated primary pill (icon + bold label) that animates in, giving
/// a professional segmented look instead of the default Material [SegmentedButton].
class AppearanceSegmented<T> extends StatelessWidget {
  const AppearanceSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<AppearanceSegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: _SegmentPill<T>(
                option: option,
                isSelected: option.value == selected,
                onTap: () => onChanged(option.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentPill<T> extends StatelessWidget {
  const _SegmentPill({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final AppearanceSegmentOption<T> option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = isSelected ? scheme.onPrimary : scheme.onSurfaceVariant;
    return PressableScale(
      scale: 0.94,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primary,
                    Color.lerp(scheme.primary, scheme.primaryContainer, 0.18)!,
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                option.icon,
                key: ValueKey(isSelected),
                size: 20,
                color: foreground,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  option.label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}