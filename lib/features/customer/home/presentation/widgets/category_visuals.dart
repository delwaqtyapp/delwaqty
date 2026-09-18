import 'package:flutter/material.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/merchant.dart';
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
/// page: grocery, vegetables & fruits, restaurants, pharmacy, home services,
/// bakery, sweets first.
List<MerchantType> get dailyDemandPriority => <MerchantType>[
  MerchantType.grocery,
  MerchantType.vegetables,
  MerchantType.fruits,
  MerchantType.butcher,
  MerchantType.dairy,
  MerchantType.restaurant,
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
