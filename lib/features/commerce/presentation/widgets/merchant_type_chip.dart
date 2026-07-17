import 'package:flutter/material.dart';
import 'package:delwaqty/features/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/core/theme/app_colors.dart';

class MerchantTypeChip extends StatelessWidget {
  const MerchantTypeChip({required this.type, this.onTap, super.key});

  final MerchantType type;
  final VoidCallback? onTap;

  String _label() {
    switch (type) {
      case MerchantType.restaurant:
        return 'Food';
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
        return 'Home';
      case MerchantType.other:
        return 'Other';
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
      label: Text(_label()),
      backgroundColor: AppColors.primaryLight.withValues(alpha: 0.3),
      onPressed: onTap,
    );
  }
}
