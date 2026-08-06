import 'package:flutter/material.dart';
import 'package:delwaqty/core/theme/app_elevation.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';

/// Premium card surface.
///
/// 24px radius, soft brand-tinted shadow, optional press animation and ink
/// ripple. The default for store cards and content sections.
class PremiumCard extends StatelessWidget {
  const PremiumCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.radius = AppSpacing.radiusCard,
    this.color,
    this.gradient,
    this.borderColor,
    this.shadow = AppElevation.shadowCard,
    this.elevated = true,
    this.pressAnimation = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;
  final List<BoxShadow> shadow;
  final bool elevated;
  final bool pressAnimation;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(radius);
    final effectiveColor =
        color ?? (gradient != null ? null : colorScheme.surfaceContainerLowest);

    Widget surface = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: effectiveColor,
        gradient: gradient,
        borderRadius: borderRadius,
        border: borderColor != null
            ? Border.all(color: borderColor!)
            : null,
        boxShadow: elevated ? shadow : null,
      ),
      child: padding != null ? Padding(padding: padding!, child: child) : child,
    );

    if (onTap != null) {
      if (pressAnimation) {
        return _PressableCard(onTap: onTap!, radius: borderRadius, child: surface);
      }
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          splashColor: colorScheme.primary.withValues(alpha: 0.08),
          highlightColor: colorScheme.primary.withValues(alpha: 0.04),
          child: surface,
        ),
      );
    }
    return surface;
  }
}

class _PressableCard extends StatefulWidget {
  const _PressableCard({
    required this.onTap,
    required this.radius,
    required this.child,
  });

  final VoidCallback onTap;
  final BorderRadius radius;
  final Widget child;

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
