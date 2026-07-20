import 'package:flutter/material.dart';
import 'package:delwaqty/features/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class MerchantTypeChip extends StatelessWidget {
  const MerchantTypeChip({required this.type, this.onTap, super.key});

  final MerchantType type;
  final VoidCallback? onTap;

  String _label(BuildContext context) {
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

  IconData _icon() {
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
    return ActionChip(
      avatar: Icon(_icon(), size: 18),
      label: Text(_label(context)),
      backgroundColor: AppColors.primaryLight.withValues(alpha: 0.3),
      onPressed: onTap,
    );
  }
}
