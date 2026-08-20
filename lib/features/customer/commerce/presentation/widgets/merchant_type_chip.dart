import 'package:flutter/material.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/merchant.dart';
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

  IconData _icon() {
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
    return ActionChip(
      avatar: Icon(_icon(), size: 18),
      label: Text(_label(context)),
      backgroundColor: AppColors.primaryLight.withValues(alpha: 0.3),
      onPressed: onTap,
    );
  }
}
