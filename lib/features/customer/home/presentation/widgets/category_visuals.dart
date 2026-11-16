import 'package:flutter/material.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_category.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

String merchantTypeLabel(MerchantType type, AppLocalizations l10n) =>
    switch (type) {
      MerchantType.restaurant => l10n.typeRestaurant,
      MerchantType.grocery => l10n.typeGrocery,
      MerchantType.supermarket => l10n.typeSupermarket,
      MerchantType.fruits => l10n.typeFruits,
      MerchantType.meat => l10n.typeMeat,
      MerchantType.seafood => l10n.typeSeafood,
      MerchantType.pharmacy => l10n.typePharmacy,
      MerchantType.bakery => l10n.typeBakery,
      MerchantType.sweets => l10n.typeSweets,
      MerchantType.flowers => l10n.typeFlowers,
      MerchantType.clothing => l10n.typeClothing,
      MerchantType.shoes => l10n.typeShoes,
      MerchantType.electronics => l10n.typeElectronics,
      MerchantType.mobile => l10n.typeMobile,
      MerchantType.furniture => l10n.typeFurniture,
      MerchantType.fashion => l10n.typeFashion,
      MerchantType.appliances => l10n.typeAppliances,
      MerchantType.home => l10n.typeHome,
      MerchantType.cafe => l10n.typeCafe,
      MerchantType.petShop => l10n.typePetShop,
      MerchantType.fitness => l10n.typeFitness,
      MerchantType.gas => l10n.typeGas,
      MerchantType.carwash => l10n.typeCarwash,
      MerchantType.perfumes => l10n.typePerfumes,
      MerchantType.spices => l10n.typeSpices,
      MerchantType.dairy => l10n.typeDairy,
      MerchantType.accessories => l10n.typeAccessories,
      MerchantType.butcher => l10n.typeButcher,
      MerchantType.vegetables => l10n.typeVegetables,
      MerchantType.other => l10n.typeOther,
    };

Color merchantTypeColor(MerchantType type) => switch (type) {
  MerchantType.restaurant => AppColors.serviceRestaurant,
  MerchantType.grocery => AppColors.serviceGrocery,
  MerchantType.supermarket => AppColors.serviceSupermarket,
  MerchantType.fruits => AppColors.serviceFruits,
  MerchantType.meat => AppColors.serviceMeat,
  MerchantType.seafood => AppColors.serviceSeafood,
  MerchantType.pharmacy => AppColors.servicePharmacy,
  MerchantType.bakery => AppColors.serviceBakery,
  MerchantType.sweets => AppColors.serviceSweets,
  MerchantType.flowers => AppColors.serviceFlowers,
  MerchantType.clothing => AppColors.serviceClothing,
  MerchantType.shoes => AppColors.serviceShoes,
  MerchantType.electronics => AppColors.serviceElectronics,
  MerchantType.mobile => AppColors.serviceMobile,
  MerchantType.furniture => AppColors.serviceFurniture,
  MerchantType.fashion => AppColors.serviceFashion,
  MerchantType.appliances => AppColors.serviceAppliances,
  MerchantType.home => AppColors.serviceHome,
  MerchantType.cafe => AppColors.serviceCafe,
  MerchantType.petShop => AppColors.servicePetShop,
  MerchantType.fitness => AppColors.serviceFitness,
  MerchantType.gas => AppColors.serviceGas,
  MerchantType.carwash => AppColors.serviceCarwash,
  MerchantType.perfumes => AppColors.serviceFlowers,
  MerchantType.spices => AppColors.serviceSupermarket,
  MerchantType.dairy => AppColors.serviceGrocery,
  MerchantType.accessories => AppColors.serviceFashion,
  MerchantType.butcher => AppColors.serviceMeat,
  MerchantType.vegetables => AppColors.serviceFruits,
  MerchantType.other => AppColors.serviceMore,
};

String merchantEmoji(MerchantType type) => switch (type) {
  MerchantType.restaurant => '🍽️',
  MerchantType.grocery => '🛒',
  MerchantType.supermarket => '🏪',
  MerchantType.fruits => '🥬',
  MerchantType.meat => '🥩',
  MerchantType.seafood => '🐟',
  MerchantType.pharmacy => '💊',
  MerchantType.bakery => '🥐',
  MerchantType.sweets => '🍰',
  MerchantType.flowers => '💐',
  MerchantType.clothing => '👔',
  MerchantType.shoes => '👟',
  MerchantType.electronics => '📱',
  MerchantType.mobile => '📞',
  MerchantType.furniture => '🛋️',
  MerchantType.fashion => '👗',
  MerchantType.appliances => '🔌',
  MerchantType.home => '🔧',
  MerchantType.cafe => '☕',
  MerchantType.petShop => '🐾',
  MerchantType.fitness => '💪',
  MerchantType.gas => '⛽',
  MerchantType.carwash => '🚿',
  MerchantType.perfumes => '🌸',
  MerchantType.spices => '🧂',
  MerchantType.dairy => '🥛',
  MerchantType.accessories => '👜',
  MerchantType.butcher => '🍖',
  MerchantType.vegetables => '🥕',
  MerchantType.other => '🏪',
};

MerchantType? categoryNameToMerchantType(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('مطعم') || lower.contains('restaurant')) return MerchantType.restaurant;
  if (lower.contains('بقال') || lower.contains('grocery')) return MerchantType.grocery;
  if (lower.contains('سوبرماركت') || lower.contains('supermarket')) return MerchantType.supermarket;
  if (lower.contains('فاكهة') || lower.contains('fruit')) return MerchantType.fruits;
  if (lower.contains('لحوم') || lower.contains('meat')) return MerchantType.meat;
  if (lower.contains('سمك') || lower.contains('seafood')) return MerchantType.seafood;
  if (lower.contains('صيدل') || lower.contains('pharmacy')) return MerchantType.pharmacy;
  if (lower.contains('مخب') || lower.contains('bakery')) return MerchantType.bakery;
  if (lower.contains('حلوي') || lower.contains('sweet')) return MerchantType.sweets;
  if (lower.contains('ورود') || lower.contains('flower')) return MerchantType.flowers;
  if (lower.contains('ملابس') || lower.contains('clothing')) return MerchantType.clothing;
  if (lower.contains('احذي') || lower.contains('shoe')) return MerchantType.shoes;
  if (lower.contains('electronic') || lower.contains('إلكتروني')) return MerchantType.electronics;
  if (lower.contains('جوال') || lower.contains('mobile') || lower.contains('هاتف')) return MerchantType.mobile;
  if (lower.contains('اثاث') || lower.contains('furniture')) return MerchantType.furniture;
  if (lower.contains('أزياء') || lower.contains('fashion') || lower.contains('mode')) return MerchantType.fashion;
  if (lower.contains('أجهزة') || lower.contains('appliance')) return MerchantType.appliances;
  if (lower.contains('منزل') || lower.contains('home')) return MerchantType.home;
  if (lower.contains('كافيه') || lower.contains('قهوة') || lower.contains('cafe')) return MerchantType.cafe;
  if (lower.contains('حيوان') || lower.contains('pet')) return MerchantType.petShop;
  if (lower.contains('لياقة') || lower.contains('fitness')) return MerchantType.fitness;
  if (lower.contains('بنزين') || lower.contains('gas')) return MerchantType.gas;
  if (lower.contains('غسيل') || lower.contains('carwash')) return MerchantType.carwash;
  if (lower.contains('عطور') || lower.contains('عطر') || lower.contains('perfume')) return MerchantType.perfumes;
  if (lower.contains('عطار') || lower.contains('بهار') || lower.contains('spice')) return MerchantType.spices;
  if (lower.contains('البان') || lower.contains('ألبان') || lower.contains('لبن') || lower.contains('dairy')) return MerchantType.dairy;
  if (lower.contains('إكسسوار') || lower.contains('اكسسوار') || lower.contains('accessor')) return MerchantType.accessories;
  if (lower.contains('جزار') || lower.contains('butcher')) return MerchantType.butcher;
  if (lower.contains('خضراوات') || lower.contains('خضروات') || lower.contains('خضار') || lower.contains('فواك') || lower.contains('vegetable')) return MerchantType.vegetables;
  return null;
}

/// Daily/repeat demand priority used for the home grid and the all-services
/// page: restaurants, grocery, vegetables & fruits, pharmacy, home services,
/// bakery, sweets first.
List<MerchantType> get dailyDemandPriority => <MerchantType>[
  MerchantType.restaurant,
  MerchantType.grocery,
  MerchantType.vegetables,
  MerchantType.fruits,
  MerchantType.butcher,
  MerchantType.dairy,
  MerchantType.pharmacy,
  MerchantType.home,
  MerchantType.bakery,
  MerchantType.sweets,
];

int categoryRank(String name) {
  final type = categoryNameToMerchantType(name);
  if (type == null) return dailyDemandPriority.length;
  final idx = dailyDemandPriority.indexOf(type);
  return idx == -1 ? dailyDemandPriority.length : idx;
}

String serviceTypeEmoji(ServiceCategoryType type) => switch (type) {
      ServiceCategoryType.doctor => '🩺',
      ServiceCategoryType.nurse => '🩹',
      ServiceCategoryType.teacher => '📚',
      ServiceCategoryType.barber => '💈',
      ServiceCategoryType.plumbing => '🔧',
      ServiceCategoryType.electrical => '⚡',
      ServiceCategoryType.carpentry => '🪚',
      ServiceCategoryType.acMaintenance => '❄️',
      ServiceCategoryType.painting => '🎨',
      ServiceCategoryType.cleaning => '🧹',
      ServiceCategoryType.pestControl => '🪳',
      ServiceCategoryType.applianceRepair => '🔩',
      ServiceCategoryType.pipeChange => '🔥',
      ServiceCategoryType.plastering => '🧱',
      ServiceCategoryType.carpetCleaning => '🧼',
      ServiceCategoryType.dishRepair => '📡',
      ServiceCategoryType.other => '🛠️',
    };

Color serviceTypeColor(ServiceCategoryType type) => switch (type) {
      ServiceCategoryType.doctor => AppColors.brandPurple,
      ServiceCategoryType.nurse => AppColors.brandCyan,
      ServiceCategoryType.teacher => AppColors.brandViolet,
      ServiceCategoryType.barber => AppColors.brandTeal,
      ServiceCategoryType.plumbing => Colors.blueGrey,
      ServiceCategoryType.electrical => Colors.amber.shade800,
      ServiceCategoryType.carpentry => Colors.brown,
      ServiceCategoryType.acMaintenance => Colors.cyan.shade700,
      ServiceCategoryType.painting => Colors.deepPurple,
      ServiceCategoryType.cleaning => Colors.teal,
      ServiceCategoryType.pestControl => Colors.green.shade800,
      ServiceCategoryType.applianceRepair => Colors.indigo,
      ServiceCategoryType.pipeChange => Colors.redAccent,
      ServiceCategoryType.plastering => Colors.orange.shade900,
      ServiceCategoryType.carpetCleaning => Colors.lightBlue.shade800,
      ServiceCategoryType.dishRepair => Colors.blueGrey.shade700,
      ServiceCategoryType.other => AppColors.brandPurple,
    };

String serviceTypeLabel(ServiceCategoryType type, AppLocalizations l10n) =>
    switch (type) {
      ServiceCategoryType.doctor => l10n.serviceCategoryDoctor,
      ServiceCategoryType.nurse => l10n.serviceCategoryNurse,
      ServiceCategoryType.teacher => l10n.serviceCategoryTeacher,
      ServiceCategoryType.barber => l10n.serviceCategoryBarber,
      ServiceCategoryType.plumbing => l10n.serviceCategoryPlumbing,
      ServiceCategoryType.electrical => l10n.serviceCategoryElectrical,
      ServiceCategoryType.carpentry => l10n.serviceCategoryCarpentry,
      ServiceCategoryType.acMaintenance => l10n.serviceCategoryAcMaintenance,
      ServiceCategoryType.painting => l10n.serviceCategoryPainting,
      ServiceCategoryType.cleaning => l10n.serviceCategoryCleaning,
      ServiceCategoryType.pestControl => l10n.serviceCategoryPestControl,
      ServiceCategoryType.applianceRepair => l10n.serviceCategoryApplianceRepair,
      ServiceCategoryType.pipeChange => l10n.serviceCategoryPipeChange,
      ServiceCategoryType.plastering => l10n.serviceCategoryPlastering,
      ServiceCategoryType.carpetCleaning => l10n.serviceCategoryCarpetCleaning,
      ServiceCategoryType.dishRepair => l10n.serviceCategoryDishRepair,
      ServiceCategoryType.other => l10n.serviceOther,
    };

/// Returns the bundled 3D category asset path for core merchant categories,
/// or `null` when a 3D icon composition should be rendered instead.
String? merchantCategoryAsset(String type) {
  final lower = type.toLowerCase();
  final resolved = categoryNameToMerchantType(type);

  if (resolved == MerchantType.restaurant ||
      lower.contains('restaurant') ||
      lower.contains('fast_food') ||
      lower.contains('food') ||
      lower.contains('grill') ||
      lower.contains('pizza') ||
      lower.contains('burger')) {
    return 'assets/categories/cat_restaurant.jpg';
  }

  if (resolved == MerchantType.grocery ||
      resolved == MerchantType.supermarket ||
      resolved == MerchantType.fruits ||
      resolved == MerchantType.vegetables ||
      resolved == MerchantType.butcher ||
      resolved == MerchantType.seafood ||
      resolved == MerchantType.meat ||
      resolved == MerchantType.dairy ||
      lower.contains('grocery') ||
      lower.contains('supermarket') ||
      lower.contains('hypermarket') ||
      lower.contains('fruit') ||
      lower.contains('vegetable') ||
      lower.contains('butcher') ||
      lower.contains('fish')) {
    return 'assets/categories/cat_grocery.jpg';
  }

  if (resolved == MerchantType.electronics ||
      resolved == MerchantType.mobile ||
      resolved == MerchantType.appliances ||
      lower.contains('electronic') ||
      lower.contains('mobile') ||
      lower.contains('computer') ||
      lower.contains('tech') ||
      lower.contains('appliance')) {
    return 'assets/categories/cat_electronics.jpg';
  }

  return null;
}

/// Maps any merchant category name or [MerchantType] to a crisp Material icon
/// so category tiles never fall back to flat text emojis.
IconData merchantCategoryIcon(String type) {
  final lower = type.toLowerCase();
  if (lower.contains('beauty') || lower.contains('cosmetic')) {
    return Icons.face_retouching_natural_rounded;
  }
  if (lower.contains('book')) return Icons.menu_book_rounded;
  if (lower.contains('sport')) return Icons.sports_soccer_rounded;
  if (lower.contains('toy')) return Icons.toys_rounded;
  if (lower.contains('jewel')) return Icons.diamond_rounded;
  if (lower.contains('coffee') || lower.contains('cafe')) {
    return Icons.local_cafe_rounded;
  }
  if (lower.contains('computer') || lower.contains('tech')) {
    return Icons.devices_rounded;
  }
  if (lower.contains('fast_food') ||
      lower.contains('food') ||
      lower.contains('grill') ||
      lower.contains('pizza') ||
      lower.contains('burger')) {
    return Icons.restaurant_rounded;
  }
  if (lower.contains('hypermarket')) return Icons.storefront_rounded;
  if (lower.contains('fish')) return Icons.set_meal_rounded;

  final merchantType = categoryNameToMerchantType(type) ?? MerchantType.other;
  return switch (merchantType) {
    MerchantType.restaurant => Icons.restaurant_rounded,
    MerchantType.grocery => Icons.local_grocery_store_rounded,
    MerchantType.supermarket => Icons.storefront_rounded,
    MerchantType.fruits => Icons.eco_rounded,
    MerchantType.meat => Icons.kebab_dining_rounded,
    MerchantType.seafood => Icons.set_meal_rounded,
    MerchantType.pharmacy => Icons.local_pharmacy_rounded,
    MerchantType.bakery => Icons.bakery_dining_rounded,
    MerchantType.sweets => Icons.cake_rounded,
    MerchantType.flowers => Icons.local_florist_rounded,
    MerchantType.clothing => Icons.checkroom_rounded,
    MerchantType.shoes => Icons.shopping_bag_rounded,
    MerchantType.electronics => Icons.devices_rounded,
    MerchantType.mobile => Icons.smartphone_rounded,
    MerchantType.furniture => Icons.chair_rounded,
    MerchantType.fashion => Icons.checkroom_rounded,
    MerchantType.appliances => Icons.kitchen_rounded,
    MerchantType.home => Icons.chair_rounded,
    MerchantType.cafe => Icons.local_cafe_rounded,
    MerchantType.petShop => Icons.pets_rounded,
    MerchantType.fitness => Icons.fitness_center_rounded,
    MerchantType.gas => Icons.local_gas_station_rounded,
    MerchantType.carwash => Icons.local_car_wash_rounded,
    MerchantType.perfumes => Icons.spa_rounded,
    MerchantType.spices => Icons.rice_bowl_rounded,
    MerchantType.dairy => Icons.local_drink_rounded,
    MerchantType.accessories => Icons.watch_rounded,
    MerchantType.butcher => Icons.kebab_dining_rounded,
    MerchantType.vegetables => Icons.eco_rounded,
    MerchantType.other => Icons.storefront_rounded,
  };
}

/// Sleek 3D-styled rounded tile icon supporting network images, bundled 3D
/// category artwork, and a glossy layered Material icon fallback.
class Category3dTileIcon extends StatelessWidget {
  const Category3dTileIcon({
    super.key,
    required this.color,
    required this.icon,
    this.networkImageUrl,
    this.assetImagePath,
    this.size = 64,
    this.borderRadius = 20,
  });

  final Color color;
  final IconData icon;
  final String? networkImageUrl;
  final String? assetImagePath;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final innerRadius = BorderRadius.circular(
      (borderRadius - 1.2).clamp(0, borderRadius),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.92),
            Color.lerp(color, Colors.black, 0.22)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: innerRadius,
        child: (networkImageUrl != null && networkImageUrl!.isNotEmpty)
            ? Image.network(
                networkImageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _buildAssetOrIcon(),
              )
            : _buildAssetOrIcon(),
      ),
    );
  }

  Widget _buildAssetOrIcon() {
    if (assetImagePath != null) {
      return Image.asset(
        assetImagePath!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _build3dIconLayer(),
      );
    }
    return _build3dIconLayer();
  }

  Widget _build3dIconLayer() {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.45, -0.45),
              radius: 0.85,
              colors: [
                Colors.white.withValues(alpha: 0.34),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Center(
          child: Icon(
            icon,
            color: Colors.white,
            size: size * 0.44,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

