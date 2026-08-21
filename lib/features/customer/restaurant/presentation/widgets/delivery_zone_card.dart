import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/customer/restaurant/restaurant_module.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/delivery_zone.dart';
import 'package:delwaqty/core/theme/app_colors.dart';


final _zonesProvider = FutureProvider.family<List<DeliveryZone>, String>((ref, merchantId) async {
  final repo = ref.watch(deliveryZoneRepositoryProvider);
  return repo.getZones(merchantId);
});

class DeliveryZoneCard extends ConsumerWidget {
  const DeliveryZoneCard({super.key, required this.merchantId});

  final String merchantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final zonesAsync = ref.watch(_zonesProvider(merchantId));

    return zonesAsync.when(
      data: (zones) {
        if (zones.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.local_shipping_outlined,
                  size: 32,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.noDeliveryZones,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: zones.map((zone) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            zone.name,
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${zone.radiusKm.toStringAsFixed(1)} ${l10n.km}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          zone.deliveryFee == 0
                              ? l10n.freeDelivery
                              : '${zone.deliveryFee.toStringAsFixed(0)} ${l10n.sar}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: zone.deliveryFee == 0 ? AppColors.successLight : null,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          l10n.estimatedDeliveryTime(zone.estimatedMinutes),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
      loading: () => const SizedBox(height: 60),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
