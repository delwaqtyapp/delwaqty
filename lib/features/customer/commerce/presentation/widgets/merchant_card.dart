import 'package:flutter/material.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/favorite.dart';
import 'package:delwaqty/features/customer/commerce/presentation/widgets/favorite_button.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
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
      case MerchantType.supermarket:
        return l10n.typeSupermarket;
      case MerchantType.fruits:
        return l10n.typeFruits;
      case MerchantType.meat:
        return l10n.typeMeat;
      case MerchantType.seafood:
        return l10n.typeSeafood;
      case MerchantType.pharmacy:
        return l10n.typePharmacy;
      case MerchantType.flowers:
        return l10n.typeFlowers;
      case MerchantType.bakery:
        return l10n.typeBakery;
      case MerchantType.sweets:
        return l10n.typeSweets;
      case MerchantType.clothing:
        return l10n.typeClothing;
      case MerchantType.shoes:
        return l10n.typeShoes;
      case MerchantType.electronics:
        return l10n.typeElectronics;
      case MerchantType.mobile:
        return l10n.typeMobile;
      case MerchantType.furniture:
        return l10n.typeFurniture;
      case MerchantType.appliances:
        return l10n.typeAppliances;
      case MerchantType.fashion:
        return l10n.typeFashion;
      case MerchantType.cafe:
        return l10n.typeCafe;
      case MerchantType.petShop:
        return l10n.typePetShop;
      case MerchantType.fitness:
        return l10n.typeFitness;
      case MerchantType.gas:
        return l10n.typeGas;
      case MerchantType.carwash:
        return l10n.typeCarwash;
      case MerchantType.home:
        return l10n.typeHome;
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
      case MerchantType.supermarket:
        return Icons.shopping_cart;
      case MerchantType.fruits:
        return Icons.eco;
      case MerchantType.meat:
        return Icons.set_meal;
      case MerchantType.seafood:
        return Icons.phishing;
      case MerchantType.pharmacy:
        return Icons.local_pharmacy;
      case MerchantType.bakery:
        return Icons.bakery_dining;
      case MerchantType.sweets:
        return Icons.cake;
      case MerchantType.flowers:
        return Icons.local_florist;
      case MerchantType.clothing:
        return Icons.dry_cleaning;
      case MerchantType.shoes:
        return Icons.pedal_bike;
      case MerchantType.electronics:
        return Icons.devices;
      case MerchantType.mobile:
        return Icons.phone_iphone;
      case MerchantType.furniture:
        return Icons.chair;
      case MerchantType.appliances:
        return Icons.kitchen;
      case MerchantType.fashion:
        return Icons.checkroom;
      case MerchantType.cafe:
        return Icons.coffee;
      case MerchantType.petShop:
        return Icons.pets;
      case MerchantType.fitness:
        return Icons.fitness_center;
      case MerchantType.gas:
        return Icons.local_gas_station;
      case MerchantType.carwash:
        return Icons.local_car_wash;
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
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shadowColor: colorScheme.onSurface.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
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
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colorScheme.primaryContainer.withValues(
                                alpha: 0.55,
                              ),
                              colorScheme.primaryContainer.withValues(
                                alpha: 0.15,
                              ),
                            ],
                          ),
                        ),
                        child: Icon(
                          _typeIcon(merchant.type),
                          size: 48,
                          color: colorScheme.primary,
                        ),
                      ),
                    if (merchant.isVerified)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.infoLight,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            l10n.verified,
                            style: AppTextStyles.labelSmall.copyWith(
                              fontSize: 10,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    if (merchant.isOpenNow)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            l10n.open,
                            style: AppTextStyles.labelSmall.copyWith(
                              fontSize: 10,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.3,
                          ),
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
              padding: const EdgeInsets.all(14),
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
                          const Icon(
                            Icons.star,
                            size: 14,
                            color: AppColors.rating,
                          ),
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
                        Icon(
                          Icons.delivery_dining,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
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
