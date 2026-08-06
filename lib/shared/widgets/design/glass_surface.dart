import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:delwaqty/core/theme/app_elevation.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';

/// A premium frosted-glass surface.
///
/// Applies a [BackdropFilter] blur with a translucent tint, soft border and
/// optional float shadow. Use sparingly — floating menu, notification button,
/// search filters and the bottom navigation bar.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = AppSpacing.radiusCard,
    this.blur = 24,
    this.tint,
    this.borderColor,
    this.borderWidth = 1,
    this.shadow,
    this.padding,
    this.ignoreBackdrop = false,
  });

  final Widget child;
  final double borderRadius;
  final double blur;
  final Color? tint;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? shadow;
  final EdgeInsetsGeometry? padding;
  final bool ignoreBackdrop;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveTint =
        tint ??
        (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.72));
    final effectiveBorder =
        borderColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.6));

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: effectiveTint,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: effectiveBorder, width: borderWidth),
            boxShadow:
                shadow ?? (isDark ? null : AppElevation.shadowCard),
          ),
          child: child,
        ),
      ),
    );
  }
}
