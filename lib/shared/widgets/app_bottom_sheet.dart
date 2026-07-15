import 'package:flutter/material.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/core/theme/app_icons.dart';

/// A reusable bottom-sheet component for the Delwaqty platform.
///
/// Provides static methods for standard, modal and full-screen bottom sheets
/// with a consistent handle-bar indicator and themed styling.
class AppBottomSheet {
  AppBottomSheet._();

  /// Shows a standard (non-modal) bottom sheet.
  ///
  /// The sheet stays open until explicitly closed and does not block
  /// interaction with the rest of the screen.
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    bool isScrollControlled = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (context) => _BottomSheetContent(
        isScrollControlled: isScrollControlled,
        child: child,
      ),
    );
  }

  /// Shows a modal bottom sheet that is scroll-controlled and draggable.
  ///
  /// Wraps [child] in a [DraggableScrollableSheet] so the sheet can be
  /// expanded / collapsed by the user.
  static Future<T?> modal<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    double initialChildSize = 0.5,
    double minChildSize = 0.2,
    double maxChildSize = 0.95,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              const _HandleBar(),
              if (title != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Divider(),
              ],
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [child],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Shows a full-screen bottom sheet that covers the entire screen.
  ///
  /// Useful for complex flows like checkout or order details.
  static Future<T?> fullScreen<T>(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (context) => _FullScreenBottomSheet(
        title: title,
        child: child,
      ),
    );
  }
}

/// Internal wrapper that adds the handle bar to the sheet content.
class _BottomSheetContent extends StatelessWidget {
  const _BottomSheetContent({
    required this.child,
    this.isScrollControlled = false,
  });

  final Widget child;
  final bool isScrollControlled;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
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
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Full-screen bottom sheet with its own app bar.
class _FullScreenBottomSheet extends StatelessWidget {
  const _FullScreenBottomSheet({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Column(
          children: [
            const _HandleBar(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(AppIcons.actionClose),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [child],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Small pill-shaped handle bar shown at the top of bottom sheets.
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
