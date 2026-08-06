import 'package:flutter/material.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_elevation.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';

/// Premium primary action button.
///
/// Renders a brand gradient capsule with a soft glow, press-scale animation,
/// ripple ink and an optional loading state. Used for the app's primary CTAs.
class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.onLongPress,
    this.isLoading = false,
    this.isExpanded = false,
    this.leadingIcon,
    this.trailingIcon,
    this.height = 56,
    this.radius = AppSpacing.radiusButton,
    this.gradient,
    this.glow = true,
  });

  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final Widget child;
  final bool isLoading;
  final bool isExpanded;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final double height;
  final double radius;
  final Gradient? gradient;
  final bool glow;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  Gradient get _defaultGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.brandGradientStart, AppColors.brandGradientEnd],
  );

  @override
  Widget build(BuildContext context) {
    final onTap = widget.isLoading ? null : widget.onPressed;
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: widget.isLoading ? null : widget.onLongPress,
        onTapDown: onTap == null
            ? null
            : (_) => setState(() => _pressed = true),
        onTapUp: onTap == null
            ? null
            : (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        borderRadius: BorderRadius.circular(widget.radius),
        child: Ink(
          decoration: BoxDecoration(
            gradient: widget.gradient ?? _defaultGradient,
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: widget.glow ? AppElevation.shadowGlow : null,
          ),
          child: SizedBox(
            height: widget.height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.d24),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.isLoading)
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    )
                  else ...[
                    if (widget.leadingIcon != null) ...[
                      widget.leadingIcon!,
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    widget.child,
                    if (widget.trailingIcon != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      widget.trailingIcon!,
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final scaled = AnimatedScale(
      scale: _pressed ? 0.965 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: button,
    );

    if (widget.isExpanded) {
      return AnimatedOpacity(
        opacity: onTap == null ? 0.6 : 1,
        duration: const Duration(milliseconds: 160),
        child: SizedBox(width: double.infinity, child: scaled),
      );
    }
    return scaled;
  }
}
