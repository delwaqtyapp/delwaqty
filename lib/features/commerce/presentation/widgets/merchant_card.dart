import 'package:flutter/material.dart';
import 'package:delwaqty/features/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/core/theme/app_colors.dart';

class MerchantCard extends StatelessWidget {
  const MerchantCard({required this.merchant, required this.onTap, super.key});

  final Merchant merchant;
  final VoidCallback onTap;

  String _typeLabel(MerchantType type) {
    switch (type) {
      case MerchantType.restaurant:
        return 'Restaurant';
      case MerchantType.grocery:
        return 'Grocery';
      case MerchantType.pharmacy:
        return 'Pharmacy';
      case MerchantType.flowers:
        return 'Flowers';
      case MerchantType.bakery:
        return 'Bakery';
      case MerchantType.electronics:
        return 'Electronics';
      case MerchantType.furniture:
        return 'Furniture';
      case MerchantType.fashion:
        return 'Fashion';
      case MerchantType.home:
        return 'Home Services';
      case MerchantType.other:
        return 'Other';
    }
  }

  IconData _typeIcon(MerchantType type) {
    switch (type) {
      case MerchantType.restaurant:
        return Icons.restaurant;
      case MerchantType.grocery:
        return Icons.local_grocery_store;
      case MerchantType.pharmacy:
        return Icons.local_pharmacy;
      case MerchantType.flowers:
        return Icons.local_florist;
      case MerchantType.bakery:
        return Icons.bakery_dining;
      case MerchantType.electronics:
        return Icons.devices;
      case MerchantType.furniture:
        return Icons.chair;
      case MerchantType.fashion:
        return Icons.checkroom;
      case MerchantType.home:
        return Icons.home_repair_service;
      case MerchantType.other:
        return Icons.store;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: AppColors.primaryLight.withValues(alpha: 0.3),
                    child: Icon(
                      _typeIcon(merchant.type),
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  if (merchant.isVerified)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Verified',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),
                  if (merchant.isOpenNow)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Open',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          merchant.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            merchant.rating.toStringAsFixed(1),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _typeLabel(merchant.type),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (merchant.deliveryAvailable)
                    Row(
                      children: [
                        const Icon(
                          Icons.delivery_dining,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          merchant.estimatedDeliveryMinutes != null
                              ? '${merchant.estimatedDeliveryMinutes} min'
                              : 'Delivery',
                          style: theme.textTheme.bodySmall,
                        ),
                        if (merchant.deliveryFee != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${merchant.deliveryFee!.toStringAsFixed(0)} SAR',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
