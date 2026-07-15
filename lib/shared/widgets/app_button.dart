import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isLoading = false,
    this.isExpanded = false,
    this.variant = AppButtonVariant.filled,
    this.padding,
    this.borderRadius,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool isLoading;
  final bool isExpanded;
  final AppButtonVariant variant;
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry? borderRadius;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;
    final button = switch (variant) {
      AppButtonVariant.filled => ElevatedButton(
          onPressed: effectiveOnPressed,
          style: ElevatedButton.styleFrom(
            padding: padding,
            shape: borderRadius != null
                ? RoundedRectangleBorder(borderRadius: borderRadius!)
                : null,
          ),
          child: _buildChild(context),
        ),
      AppButtonVariant.outlined => OutlinedButton(
          onPressed: effectiveOnPressed,
          style: OutlinedButton.styleFrom(
            padding: padding,
            shape: borderRadius != null
                ? RoundedRectangleBorder(borderRadius: borderRadius!)
                : null,
          ),
          child: _buildChild(context),
        ),
      AppButtonVariant.text => TextButton(
          onPressed: effectiveOnPressed,
          style: TextButton.styleFrom(
            padding: padding,
            shape: borderRadius != null
                ? RoundedRectangleBorder(borderRadius: borderRadius!)
                : null,
          ),
          child: _buildChild(context),
        ),
    };

    if (isExpanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }

  Widget _buildChild(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: variant == AppButtonVariant.filled
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.primary,
        ),
      );
    }
    return child;
  }
}

enum AppButtonVariant { filled, outlined, text }
