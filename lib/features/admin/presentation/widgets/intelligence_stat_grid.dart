import 'package:flutter/material.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/customer/home/presentation/widgets/category_visuals.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_category.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';

/// One KPI entry in an admin intelligence summary grid.
class IntelligenceStat {
  const IntelligenceStat({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
}

/// Responsive KPI grid for the admin intelligence pages.
///
/// Uses a [Wrap] with content-driven card heights instead of a fixed
/// `GridView` aspect ratio, so cards never overflow at small widths or
/// large text scales. Narrow layouts get 2 columns, wide layouts get
/// [wideColumns].
class IntelligenceStatGrid extends StatelessWidget {
  const IntelligenceStatGrid({
    super.key,
    required this.stats,
    this.wideColumns = 3,
  });

  final List<IntelligenceStat> stats;
  final int wideColumns;

  static const double _spacing = 10;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 600 ? wideColumns : 2;
        final cardWidth =
            (constraints.maxWidth - _spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          children: [
            for (final stat in stats)
              SizedBox(width: cardWidth, child: _IntelligenceStatCard(stat)),
          ],
        );
      },
    );
  }
}

class _IntelligenceStatCard extends StatelessWidget {
  const _IntelligenceStatCard(this.stat);

  final IntelligenceStat stat;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PremiumCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: stat.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(stat.icon, color: stat.color, size: 20),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              stat.value,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            stat.title,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: cs.onSurfaceVariant),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Localized label for a category/type string coming from the backend
/// (e.g. `plumbing`, `restaurant`). Falls back to the raw value when the
/// type is unknown.
String localizedCategoryTypeLabel(String type, AppLocalizations l10n) {
  for (final service in ServiceCategoryType.values) {
    if (service.name == type) return serviceTypeLabel(service, l10n);
  }
  for (final merchant in MerchantType.values) {
    if (merchant.name == type) return merchantTypeLabel(merchant, l10n);
  }
  return type;
}
