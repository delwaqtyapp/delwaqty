import 'package:flutter/material.dart';

/// A single selectable entry inside an [AppearanceSegmented] control.
///
/// [glyph] (optional) is drawn instead of [icon], e.g. "ع" / "Aa" for the
/// language switch.
class AppearanceSegmentOption<T> {
  const AppearanceSegmentOption(
    this.value,
    this.icon,
    this.label, {
    this.glyph,
  });

  final T value;
  final IconData icon;
  final String label;
  final String? glyph;
}

/// Animated sliding-thumb selector used for the theme and language switches
/// (profile and admin settings), so both controls look and move the same.
///
/// A single thumb glides under the selected option (RTL-aware through
/// [AlignmentDirectional]); the label colour, icon scale and weight animate
/// with it. Only implicit animations and plain boxes: cheap on low-end phones.
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

  static const _duration = Duration(milliseconds: 320);
  static const _curve = Curves.easeOutBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = options.length;
    final index = options.indexWhere((o) => o.value == selected);
    final slot = index < 0 ? 0 : index;
    final x = count <= 1 ? 0.0 : -1 + 2 * slot / (count - 1);
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Stack(
        children: [
          if (index >= 0)
            AnimatedAlign(
              duration: _duration,
              curve: _curve,
              alignment: AlignmentDirectional(x, 0),
              child: FractionallySizedBox(
                widthFactor: 1 / count,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.topStart,
                      end: AlignmentDirectional.bottomEnd,
                      colors: [
                        scheme.primary,
                        Color.lerp(
                          scheme.primary,
                          scheme.primaryContainer,
                          0.2,
                        )!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Row(
            children: [
              for (final option in options)
                Expanded(
                  child: _SegmentLabel<T>(
                    option: option,
                    isSelected: option.value == selected,
                    onTap: () => onChanged(option.value),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentLabel<T> extends StatelessWidget {
  const _SegmentLabel({
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
    return Semantics(
      button: true,
      selected: isSelected,
      label: option.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.15 : 1,
                  duration: AppearanceSegmented._duration,
                  curve: AppearanceSegmented._curve,
                  child: option.glyph != null
                      ? Text(
                          option.glyph!,
                          style: Theme.of(context).textTheme.labelLarge!
                              .copyWith(
                                fontSize: 17,
                                height: 1.1,
                                fontWeight: FontWeight.w800,
                                color: foreground,
                              ),
                        )
                      : Icon(option.icon, size: 19, color: foreground),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AnimatedDefaultTextStyle(
                      duration: AppearanceSegmented._duration,
                      style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: foreground,
                      ),
                      child: Text(option.label, maxLines: 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
