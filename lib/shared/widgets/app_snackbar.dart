import 'package:flutter/material.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/core/theme/app_icons.dart';

/// A reusable snackbar system for the Delwaqty platform.
///
/// Provides static convenience methods that display context-appropriate
/// snackbars with configurable duration, action buttons, and semantic
/// colouring for success, error, warning and info states.
class AppSnackbar {
  AppSnackbar._();

  // ---------------------------------------------------------------------------
  // Static Helpers
  // ---------------------------------------------------------------------------

  /// Shows a **success** snackbar with a green tint.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> success(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    return _show(
      context,
      message: message,
      backgroundColor: AppColors.successLight,
      icon: const Icon(AppIcons.actionSuccess, color: Colors.white),
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// Shows an **error** snackbar with a red tint.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> error(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    return _show(
      context,
      message: message,
      backgroundColor: AppColors.errorLight,
      icon: const Icon(AppIcons.actionError, color: Colors.white),
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// Shows a **warning** snackbar with an orange tint.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> warning(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    return _show(
      context,
      message: message,
      backgroundColor: AppColors.warningLight,
      icon: const Icon(AppIcons.actionWarning, color: Colors.white),
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// Shows an **info** snackbar with a blue tint.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> info(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    return _show(
      context,
      message: message,
      backgroundColor: AppColors.infoLight,
      icon: const Icon(AppIcons.actionInfo, color: Colors.white),
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// Shows a plain snackbar with the theme's surface colour.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> plain(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    final colors = Theme.of(context).colorScheme;
    return _show(
      context,
      message: message,
      backgroundColor: colors.inverseSurface,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> _show(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    Widget? icon,
    String? actionLabel,
    VoidCallback? onAction,
    required Duration duration,
  }) {
    final snackBar = SnackBar(
      content: Row(
        children: [
          if (icon != null) ...[
            icon,
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: backgroundColor,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusMd,
      ),
      margin: const EdgeInsets.all(AppSpacing.lg),
      action: actionLabel != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: Colors.white,
              onPressed: onAction ?? () {},
            )
          : null,
    );

    return ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
