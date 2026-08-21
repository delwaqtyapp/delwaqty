import 'package:flutter/material.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/restaurant_settings.dart';

class ServiceTypeChips extends StatelessWidget {
  const ServiceTypeChips({super.key, required this.settings});

  final RestaurantSettings settings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final services = <(bool, IconData, String)>[
      (settings.hasDineIn, Icons.restaurant_rounded, l10n.dineIn),
      (settings.hasTakeaway, Icons.takeout_dining_rounded, l10n.takeaway),
      (settings.hasDelivery, Icons.delivery_dining_rounded, l10n.delivery),
    ].where((s) => s.$1).toList();

    if (services.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: services.map((service) {
        final (_, icon, label) = service;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.4),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
