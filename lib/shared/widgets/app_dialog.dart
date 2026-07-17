import 'package:flutter/material.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/core/theme/app_animation.dart';
import 'package:delwaqty/core/theme/app_icons.dart';
import 'package:delwaqty/shared/widgets/app_button.dart';
import 'package:delwaqty/shared/widgets/app_text_field.dart';

/// A set of reusable dialog components for the Delwaqty platform.
///
/// Provides static factory methods for common dialog patterns so that
/// callers never need to deal with raw [showDialog] boilerplate.
class AppDialog {
  AppDialog._();

  /// Shows a confirmation dialog with a title, message, and confirm / cancel
  /// actions. Returns `true` when the user confirms, `false` otherwise.
  static Future<bool> confirmation(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) async {
    final colors = Theme.of(context).colorScheme;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusXl,
        ),
        title: Text(title),
        content: Text(message),
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          AppButton.text(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          if (isDestructive)
            AppButton.filled(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                confirmLabel,
                style: TextStyle(color: colors.onError),
              ),
            )
          else
            AppButton.filled(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Shows a dialog with a [TextField] for user input.
  ///
  /// Returns the entered text when the user confirms, or `null` on cancel.
  static Future<String?> input(
    BuildContext context, {
    required String title,
    String? hint,
    String? initialValue,
    String confirmLabel = 'OK',
    String cancelLabel = 'Cancel',
    TextInputType keyboardType = TextInputType.text,
    int maxLength = 256,
    String? Function(String?)? validator,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusXl,
        ),
        title: Text(title),
        content: Form(
          key: formKey,
          child: AppTextField(
            controller: controller,
            hint: hint,
            keyboardType: keyboardType,
            maxLength: maxLength,
            autofocus: true,
            validator: validator,
          ),
        ),
        actions: [
          AppButton.text(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(cancelLabel),
          ),
          AppButton.filled(
            onPressed: () {
              if (formKey.currentState?.validate() ?? true) {
                Navigator.of(context).pop(controller.text);
              }
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  /// Shows a full-screen dialog that slides up from the bottom.
  ///
  /// The [builder] receives the inner context and must return the dialog body.
  /// The dialog is automatically dismissible via a close button in the app bar.
  static Future<T?> fullScreen<T>(
    BuildContext context, {
    required String title,
    required Widget Function(BuildContext) builder,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: title,
      transitionDuration: AppAnimation.normal,
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).chain(CurveTween(curve: AppAnimation.standard));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return _FullScreenDialog(title: title, builder: builder);
      },
    );
  }

  /// Shows a modal bottom sheet styled dialog with rounded top corners.
  ///
  /// [builder] receives the inner [BuildContext] and should return the sheet
  /// body. Wrap content in safe-area if needed.
  static Future<T?> bottomSheet<T>(
    BuildContext context, {
    required Widget Function(BuildContext) builder,
    bool isScrollControlled = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: isScrollControlled ? 0.7 : 0.5,
        minChildSize: 0.2,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              const _HandleBar(),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: builder(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Small pill-shaped handle bar shown at the top of modal bottom sheets.
class _HandleBar extends StatelessWidget {
  const _HandleBar();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        margin: const EdgeInsets.only(
          top: AppSpacing.sm,
          bottom: AppSpacing.md,
        ),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: colors.onSurfaceVariant.withValues(alpha: 0.4),
          borderRadius: AppSpacing.borderRadiusFull,
        ),
      ),
    );
  }
}

/// Full-screen dialog with a close button in the app bar.
class _FullScreenDialog extends StatelessWidget {
  const _FullScreenDialog({required this.title, required this.builder});

  final String title;
  final Widget Function(BuildContext) builder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(AppIcons.actionClose),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: builder(context),
    );
  }
}
