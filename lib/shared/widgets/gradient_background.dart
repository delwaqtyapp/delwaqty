import 'package:flutter/material.dart';
import 'package:delwaqty/core/theme/app_colors.dart';

class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key, required this.child, this.colors});

  final Widget child;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColors =
        colors ??
        (isDark
            ? [
                AppColors.primaryDark.withValues(alpha: 0.3),
                AppColors.surfaceDark,
              ]
            : [
                AppColors.primaryLight.withValues(alpha: 0.15),
                AppColors.surfaceLight,
              ]);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: effectiveColors,
        ),
      ),
      child: child,
    );
  }
}
