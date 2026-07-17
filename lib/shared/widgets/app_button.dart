import 'package:flutter/material.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/core/theme/app_animation.dart';

/// A comprehensive, multi-variant button component for the Delwaqty platform.
///
/// Supports five visual variants ([filled], [tonal], [outlined], [text],
/// [elevated]), three sizes ([small], [medium], [large]), loading state,
/// leading / trailing icons, full-width mode and disabled state.
class AppButton extends StatelessWidget {
  /// Creates a button with the given [variant], [size] and optional extras.
  const AppButton({
    super.key,
    required this.onPressed,
    this.child,
    this.variant = AppButtonVariant.filled,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.isExpanded = false,
    this.leadingIcon,
    this.trailingIcon,
  });

  /// A filled button (solid background).
  const AppButton.filled({
    super.key,
    required this.onPressed,
    this.child,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.isExpanded = false,
    this.leadingIcon,
    this.trailingIcon,
  }) : variant = AppButtonVariant.filled;

  /// A tonal button (soft background).
  const AppButton.tonal({
    super.key,
    required this.onPressed,
    this.child,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.isExpanded = false,
    this.leadingIcon,
    this.trailingIcon,
  }) : variant = AppButtonVariant.tonal;

  /// An outlined button (border only).
  const AppButton.outlined({
    super.key,
    required this.onPressed,
    this.child,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.isExpanded = false,
    this.leadingIcon,
    this.trailingIcon,
  }) : variant = AppButtonVariant.outlined;

  /// A text button (no background or border).
  const AppButton.text({
    super.key,
    required this.onPressed,
    this.child,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.isExpanded = false,
    this.leadingIcon,
    this.trailingIcon,
  }) : variant = AppButtonVariant.text;

  /// An elevated button (with shadow).
  const AppButton.elevated({
    super.key,
    required this.onPressed,
    this.child,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.isExpanded = false,
    this.leadingIcon,
    this.trailingIcon,
  }) : variant = AppButtonVariant.elevated;

  /// Callback when the button is tapped. `null` disables the button.
  final VoidCallback? onPressed;

  /// The primary label widget. Typically a [Text] widget.
  final Widget? child;

  /// Visual variant of the button.
  final AppButtonVariant variant;

  /// Size of the button affecting padding and text scale.
  final AppButtonSize size;

  /// When `true`, a circular progress indicator replaces the [child].
  final bool isLoading;

  /// When `true`, the button stretches to fill available horizontal space.
  final bool isExpanded;

  /// Optional icon widget placed before the label.
  final Widget? leadingIcon;

  /// Optional icon widget placed after the label.
  final Widget? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;
    final colors = Theme.of(context).colorScheme;

    final button = switch (variant) {
      AppButtonVariant.filled => _buildFilledButton(
        context,
        effectiveOnPressed,
        colors,
      ),
      AppButtonVariant.tonal => _buildTonalButton(
        context,
        effectiveOnPressed,
        colors,
      ),
      AppButtonVariant.outlined => _buildOutlinedButton(
        context,
        effectiveOnPressed,
        colors,
      ),
      AppButtonVariant.text => _buildTextButton(
        context,
        effectiveOnPressed,
        colors,
      ),
      AppButtonVariant.elevated => _buildElevatedButton(
        context,
        effectiveOnPressed,
        colors,
      ),
    };

    if (isExpanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }

  ButtonStyle _baseStyle(BuildContext context) {
    final padding = switch (size) {
      AppButtonSize.small => const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      AppButtonSize.medium => const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.md,
      ),
      AppButtonSize.large => const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxxl,
        vertical: AppSpacing.xl,
      ),
    };

    return ButtonStyle(
      padding: WidgetStatePropertyAll(padding),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusLg),
      ),
      animationDuration: AppAnimation.fast,
    );
  }

  Widget _buildChild(BuildContext context) {
    if (isLoading) {
      final spinnerColor = switch (variant) {
        AppButtonVariant.filled => Theme.of(context).colorScheme.onPrimary,
        AppButtonVariant.tonal => Theme.of(context).colorScheme.primary,
        _ => Theme.of(context).colorScheme.primary,
      };
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: spinnerColor),
      );
    }

    final children = <Widget>[
      if (leadingIcon != null) ...[
        leadingIcon!,
        const SizedBox(width: AppSpacing.sm),
      ],
      if (child != null) child!,
      if (trailingIcon != null) ...[
        const SizedBox(width: AppSpacing.sm),
        trailingIcon!,
      ],
    ];

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _buildFilledButton(
    BuildContext context,
    VoidCallback? effectiveOnPressed,
    ColorScheme colors,
  ) {
    return FilledButton(
      onPressed: effectiveOnPressed,
      style: _baseStyle(context),
      child: _buildChild(context),
    );
  }

  Widget _buildTonalButton(
    BuildContext context,
    VoidCallback? effectiveOnPressed,
    ColorScheme colors,
  ) {
    return FilledButton.tonal(
      onPressed: effectiveOnPressed,
      style: _baseStyle(context),
      child: _buildChild(context),
    );
  }

  Widget _buildOutlinedButton(
    BuildContext context,
    VoidCallback? effectiveOnPressed,
    ColorScheme colors,
  ) {
    return OutlinedButton(
      onPressed: effectiveOnPressed,
      style: _baseStyle(context),
      child: _buildChild(context),
    );
  }

  Widget _buildTextButton(
    BuildContext context,
    VoidCallback? effectiveOnPressed,
    ColorScheme colors,
  ) {
    return TextButton(
      onPressed: effectiveOnPressed,
      style: _baseStyle(context),
      child: _buildChild(context),
    );
  }

  Widget _buildElevatedButton(
    BuildContext context,
    VoidCallback? effectiveOnPressed,
    ColorScheme colors,
  ) {
    return ElevatedButton(
      onPressed: effectiveOnPressed,
      style: _baseStyle(context),
      child: _buildChild(context),
    );
  }
}

/// Available visual variants for [AppButton].
enum AppButtonVariant {
  /// Solid background.
  filled,

  /// Soft-toned background.
  tonal,

  /// Border only, no fill.
  outlined,

  /// No background or border.
  text,

  /// Elevated with shadow.
  elevated,
}

/// Available sizes for [AppButton].
enum AppButtonSize {
  /// Compact button.
  small,

  /// Default button size.
  medium,

  /// Large, prominent button.
  large,
}
