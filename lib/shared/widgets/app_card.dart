import 'package:flutter/material.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/core/theme/app_elevation.dart';

/// A reusable card component for the Delwaqty platform.
///
/// Supports three visual variants ([elevated], [filled], [outlined]),
/// three content-density sizes ([compact], [standard], [spacious]),
/// optional tappable behaviour with ink-splash, and three content
/// slots: [header], [child] (body) and [footer].
class AppCard extends StatelessWidget {
  /// Creates a card with the given [variant] and optional content slots.
  const AppCard({
    super.key,
    this.header,
    this.child,
    this.footer,
    this.variant = AppCardVariant.elevated,
    this.size = AppCardSize.standard,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.borderColor,
    this.backgroundColor,
  });

  /// Content displayed above the body in a padded header area.
  final Widget? header;

  /// The primary body content of the card.
  final Widget? child;

  /// Content displayed below the body in a padded footer area.
  final Widget? footer;

  /// Visual variant of the card.
  final AppCardVariant variant;

  /// Content-density size of the card.
  final AppCardSize size;

  /// Called when the card is tapped. Enables tap feedback when non-null.
  final VoidCallback? onTap;

  /// Called when the card is long-pressed.
  final VoidCallback? onLongPress;

  /// Override for the default corner radius.
  final BorderRadius? borderRadius;

  /// Override for the border color (only relevant for [AppCardVariant.outlined]).
  final Color? borderColor;

  /// Override for the card background color.
  final Color? backgroundColor;

  EdgeInsets get _padding {
    return switch (size) {
      AppCardSize.compact => const EdgeInsets.all(AppSpacing.md),
      AppCardSize.standard => const EdgeInsets.all(AppSpacing.lg),
      AppCardSize.spacious => const EdgeInsets.all(AppSpacing.xl),
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final effectiveRadius = borderRadius ?? AppSpacing.borderRadiusLg;

    final card = _buildCardContent(context, colors, effectiveRadius);

    if (onTap != null || onLongPress != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: effectiveRadius,
          splashColor: colors.primary.withValues(alpha: 0.08),
          highlightColor: colors.primary.withValues(alpha: 0.04),
          child: card,
        ),
      );
    }

    return card;
  }

  Widget _buildCardContent(
    BuildContext context,
    ColorScheme colors,
    BorderRadius radius,
  ) {
    return Container(
      decoration: _decoration(context, radius),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: _padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (header != null) ...[
              header!,
              const SizedBox(height: AppSpacing.md),
            ],
            ?child,
            if (footer != null) ...[
              const SizedBox(height: AppSpacing.md),
              footer!,
            ],
          ],
        ),
      ),
    );
  }

  BoxDecoration _decoration(BuildContext context, BorderRadius radius) {
    final colors = Theme.of(context).colorScheme;

    return switch (variant) {
      AppCardVariant.elevated => BoxDecoration(
        color: backgroundColor ?? colors.surfaceContainerLowest,
        borderRadius: radius,
        boxShadow: AppElevation.shadowSm,
      ),
      AppCardVariant.filled => BoxDecoration(
        color:
            backgroundColor ??
            colors.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: radius,
      ),
      AppCardVariant.outlined => BoxDecoration(
        color: backgroundColor ?? colors.surfaceContainerLowest,
        borderRadius: radius,
        border: Border.all(color: borderColor ?? colors.outlineVariant),
      ),
    };
  }
}

/// Available visual variants for [AppCard].
enum AppCardVariant {
  /// Card with subtle shadow.
  elevated,

  /// Card with filled background, no shadow.
  filled,

  /// Card with visible border, no shadow.
  outlined,
}

/// Available content-density sizes for [AppCard].
enum AppCardSize {
  /// Compact padding — 12px.
  compact,

  /// Standard padding — 16px.
  standard,

  /// Spacious padding — 24px.
  spacious,
}
