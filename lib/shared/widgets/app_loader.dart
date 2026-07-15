import 'package:flutter/material.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/core/theme/app_elevation.dart';

/// A collection of reusable loader components for the Delwaqty platform.
///
/// Provides circular and linear progress indicators, a full-screen loading
/// overlay, and skeleton placeholder widgets.
class AppLoader {
  AppLoader._();

  // ---------------------------------------------------------------------------
  // Circular Progress Indicator
  // ---------------------------------------------------------------------------

  /// A centred circular progress indicator using the primary color.
  static Widget circular({
    Key? key,
    double size = 40,
    double strokeWidth = 4,
    Color? color,
  }) {
    return SizedBox(
      key: key,
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: color,
      ),
    );
  }

  /// A small circular progress indicator suitable for inline use (buttons, chips).
  static Widget small({
    Key? key,
    Color? color,
  }) {
    return SizedBox(
      key: key,
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: color,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Linear Progress Indicator
  // ---------------------------------------------------------------------------

  /// A linear progress indicator spanning available width.
  static Widget linear({
    Key? key,
    double? value,
    double height = 4,
    Color? color,
    Color? backgroundColor,
    BorderRadiusGeometry? borderRadius,
  }) {
    return ClipRRect(
      key: key,
      borderRadius: borderRadius ?? AppSpacing.borderRadiusFull,
      child: LinearProgressIndicator(
        value: value,
        minHeight: height,
        color: color,
        backgroundColor: backgroundColor,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Full-Screen Loading Overlay
  // ---------------------------------------------------------------------------

  /// Shows a full-screen loading overlay with a dimmed background.
  ///
  /// Call [Navigator.of(context).pop] to dismiss.
  static Future<void> showOverlay(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierLabel: 'Loading',
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return const _FullScreenLoader();
      },
    );
  }
}

/// Full-screen loader widget used by [AppLoader.showOverlay].
class _FullScreenLoader extends StatelessWidget {
  const _FullScreenLoader();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Card(
        elevation: AppElevation.md,
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: AppLoaderCircular(),
        ),
      ),
    );
  }
}

/// A stateless circular progress indicator widget.
class AppLoaderCircular extends StatelessWidget {
  /// Creates a circular loader widget.
  const AppLoaderCircular({
    super.key,
    this.size = 40,
    this.strokeWidth = 4,
    this.color,
  });

  /// Diameter of the loader.
  final double size;

  /// Thickness of the circular stroke.
  final double strokeWidth;

  /// Color override.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: color,
      ),
    );
  }
}

/// A stateless linear progress indicator widget.
class AppLoaderLinear extends StatelessWidget {
  /// Creates a linear loader widget.
  const AppLoaderLinear({
    super.key,
    this.value,
    this.height = 4,
    this.color,
    this.backgroundColor,
  });

  /// Optional explicit value between 0.0 and 1.0.
  final double? value;

  /// Height of the bar.
  final double height;

  /// Color override.
  final Color? color;

  /// Background track color override.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppSpacing.borderRadiusFull,
      child: LinearProgressIndicator(
        value: value,
        minHeight: height,
        color: color,
        backgroundColor: backgroundColor,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton Loading Widgets
// ---------------------------------------------------------------------------

/// A single skeleton placeholder rectangle that pulses to indicate loading.
class LoadingSkeleton extends StatefulWidget {
  /// Creates a skeleton placeholder.
  const LoadingSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = AppSpacing.radiusMd,
  });

  /// Fixed width. When `null` the skeleton fills available horizontal space.
  final double? width;

  /// Height of the skeleton block.
  final double height;

  /// Corner radius.
  final double borderRadius;

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// Skeleton placeholder that mimics a [ListTile] layout.
class SkeletonListTile extends StatelessWidget {
  /// Creates a list-tile skeleton.
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.listTilePaddingHorizontal,
        vertical: AppSpacing.listTilePaddingVertical,
      ),
      child: Row(
        children: [
          const LoadingSkeleton(
            width: 48,
            height: 48,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LoadingSkeleton(width: double.infinity, height: 14),
                const SizedBox(height: AppSpacing.sm),
                LoadingSkeleton(
                  width: MediaQuery.sizeOf(context).width * 0.4,
                  height: 12,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          const LoadingSkeleton(width: 60, height: 14),
        ],
      ),
    );
  }
}

/// Skeleton placeholder that mimics a card layout.
class SkeletonCard extends StatelessWidget {
  /// Creates a card skeleton.
  const SkeletonCard({super.key, this.height = 120});

  /// Height of the skeleton card.
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardMarginHorizontal,
        vertical: AppSpacing.cardMarginVertical,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: AppSpacing.borderRadiusXl,
      ),
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LoadingSkeleton(width: 120),
            SizedBox(height: AppSpacing.md),
            LoadingSkeleton(width: double.infinity, height: 12),
            SizedBox(height: AppSpacing.sm),
            LoadingSkeleton(width: double.infinity, height: 12),
            SizedBox(height: AppSpacing.sm),
            LoadingSkeleton(width: 200, height: 12),
          ],
        ),
      ),
    );
  }
}
