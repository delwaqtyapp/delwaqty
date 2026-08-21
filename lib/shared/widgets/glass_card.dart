import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 16,
    this.blurAmount = 16,
    this.borderColor,
    this.backgroundColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blurAmount;
  final Color? borderColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveBg = backgroundColor ??
        colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
    final effectiveBorder = borderColor ??
        colorScheme.outline.withValues(alpha: 0.15);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
        child: Container(
          decoration: BoxDecoration(
            color: effectiveBg,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: effectiveBorder),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
