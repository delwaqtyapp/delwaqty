import 'package:flutter/material.dart';
import 'package:delwaqty/features/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/commerce/domain/entities/favorite.dart';
import 'package:delwaqty/features/commerce/presentation/widgets/favorite_button.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class MerchantCard extends StatelessWidget {
  const MerchantCard({required this.merchant, required this.onTap, super.key});

  final Merchant merchant;
  final VoidCallback onTap;

  String _typeLabel(BuildContext context, MerchantType type) {
    final l10n = AppLocalizations.of(context);
    switch (type) {
      case MerchantType.restaurant:
        return l10n.typeRestaurant;
      case MerchantType.grocery:
        return l10n.typeGrocery;
      case MerchantType.pharmacy:
        return l10n.typePharmacy;
      case MerchantType.flowers:
        return l10n.typeFlowers;
      case MerchantType.bakery:
        return l10n.typeBakery;
      case MerchantType.electronics:
        return l10n.typeElectronics;
      case MerchantType.furniture:
        return l10n.typeFurniture;
      case MerchantType.fashion:
        return l10n.typeFashion;
      case MerchantType.home:
        return l10n.typeHomeServices;
      case MerchantType.other:
        return l10n.typeOther;
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
    final l10n = AppLocalizations.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'merchant-${merchant.id}',
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (merchant.imageUrl != null)
                      Image.network(merchant.imageUrl!, fit: BoxFit.cover)
                    else
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
                        child: Text(
                          l10n.verified,
                          style: const TextStyle(color: Colors.white, fontSize: 10),
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
                        child: Text(
                          l10n.open,
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: FavoriteButton(
                        targetId: merchant.id,
                        type: FavoriteType.merchant,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
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
                    _typeLabel(context, merchant.type),
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
                        Flexible(
                          child: Text(
                            merchant.estimatedDeliveryMinutes != null
                                ? '${merchant.estimatedDeliveryMinutes} ${l10n.minutesShort}'
                                : l10n.delivery,
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (merchant.deliveryFee != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '${merchant.deliveryFee!.toStringAsFixed(0)} ${l10n.currencySymbol}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
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
