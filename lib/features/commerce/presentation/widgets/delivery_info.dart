import 'package:flutter/material.dart';

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

    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        if (estimatedMinutes != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.access_time, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text('$estimatedMinutes min', style: theme.textTheme.bodySmall),
            ],
          ),
        if (deliveryFee != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.delivery_dining, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                deliveryFee == 0
                    ? 'Free delivery'
                    : '${deliveryFee!.toStringAsFixed(0)} SAR',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        if (minimumOrder != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.shopping_bag_outlined,
                size: 16,
                color: Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                'Min ${minimumOrder!.toStringAsFixed(0)} SAR',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
      ],
    );
  }
}
