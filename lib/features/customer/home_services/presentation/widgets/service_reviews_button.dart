import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_category.dart';

/// The single, unified reviews/ratings entry point across the whole app.
///
/// Renders the same gold star button on every surface that exposes a service
/// (category grid tile, per-service AppBar, delivery-car marketplace, …) and
/// opens the full reviews list for that category at
/// `/home-services/reviews/{categoryType}`.
class ServiceReviewsButton extends StatelessWidget {
  const ServiceReviewsButton({
    required this.categoryType,
    this.onPressedOverride,
    this.visualDensity = VisualDensity.compact,
    this.iconSize = 22,
    this.color = AppColors.rating,
    this.tooltipLabel,
    super.key,
  });

  final ServiceCategoryType categoryType;
  final VoidCallback? onPressedOverride;
  final VisualDensity visualDensity;
  final double iconSize;
  final Color color;
  final String? tooltipLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      tooltip: tooltipLabel ?? l10n.rateService,
      visualDensity: visualDensity,
      color: color,
      iconSize: iconSize,
      icon: const Icon(Icons.rate_review_rounded),
      onPressed: onPressedOverride ??
          () => context.push(
                '/home-services/reviews/${categoryType.name}',
              ),
    );
  }
}