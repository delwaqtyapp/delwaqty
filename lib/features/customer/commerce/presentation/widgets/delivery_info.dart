import 'package:flutter/material.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class DeliveryInfo extends StatelessWidget {
  const DeliveryInfo({
    this.estimatedMinutes,
    this.deliveryFee,
    this.minimumOrder,
    super.key,
  });

  final int? estimatedMinutes;
  final double? deliveryFee;
  final double? minimumOrder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        if (estimatedMinutes != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.access_time, size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                '$estimatedMinutes ${l10n.minutesShort}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        if (deliveryFee != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delivery_dining, size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                deliveryFee == 0
                    ? l10n.freeDelivery
                    : '${deliveryFee!.toStringAsFixed(0)} ${l10n.currencySymbol}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        if (minimumOrder != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '${l10n.minOrder} ${minimumOrder!.toStringAsFixed(0)} ${l10n.currencySymbol}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
      ],
    );
  }
}
