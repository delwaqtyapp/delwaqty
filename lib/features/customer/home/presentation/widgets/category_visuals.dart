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
  if (lower.contains('مطعم') || lower.contains('restaurant'))
    return MerchantType.restaurant;
  if (lower.contains('بقال') || lower.contains('grocery'))
    return MerchantType.grocery;
  if (lower.contains('سوبرماركت') || lower.contains('supermarket'))
    return MerchantType.supermarket;
  if (lower.contains('فاكهة') || lower.contains('fruit'))
    return MerchantType.fruits;
  if (lower.contains('لحوم') || lower.contains('meat'))
    return MerchantType.meat;
  if (lower.contains('سمك') || lower.contains('seafood'))
    return MerchantType.seafood;
  if (lower.contains('مخب') || lower.contains('bakery'))
    return MerchantType.bakery;
  if (lower.contains('حلوي') || lower.contains('sweet'))
    return MerchantType.sweets;
  if (lower.contains('ورود') || lower.contains('flower'))
    return MerchantType.flowers;
  if (lower.contains('ملابس') || lower.contains('clothing'))
    return MerchantType.clothing;
  if (lower.contains('احذي') || lower.contains('shoe'))
    return MerchantType.shoes;
  if (lower.contains('electronic') || lower.contains('إلكتروني'))
    return MerchantType.electronics;
  if (lower.contains('جوال') ||
      lower.contains('mobile') ||
      lower.contains('هاتف'))
    return MerchantType.mobile;
  if (lower.contains('اثاث') || lower.contains('furniture'))
    return MerchantType.furniture;
  if (lower.contains('أزياء') ||
      lower.contains('fashion') ||
      lower.contains('mode'))
    return MerchantType.fashion;
  if (lower.contains('أجهزة') || lower.contains('appliance'))
    return MerchantType.appliances;
  if (lower.contains('منزل') || lower.contains('home'))
    return MerchantType.home;
  if (lower.contains('كافيه') ||
      lower.contains('قهوة') ||
      lower.contains('cafe'))
    return MerchantType.cafe;
  if (lower.contains('حيوان') || lower.contains('pet'))
    return MerchantType.petShop;
  if (lower.contains('لياقة') || lower.contains('fitness'))
    return MerchantType.fitness;
  if (lower.contains('بنزين') || lower.contains('gas')) return MerchantType.gas;
  if (lower.contains('غسيل') || lower.contains('carwash'))
    return MerchantType.carwash;
  if (lower.contains('عطور') ||
      lower.contains('عطر') ||
      lower.contains('perfume'))
    return MerchantType.perfumes;
  if (lower.contains('عطار') ||
      lower.contains('بهار') ||
      lower.contains('spice'))
    return MerchantType.spices;
  if (lower.contains('البان') ||
      lower.contains('ألبان') ||
      lower.contains('لبن') ||
      lower.contains('dairy'))
    return MerchantType.dairy;
  if (lower.contains('إكسسوار') ||
      lower.contains('اكسسوار') ||
      lower.contains('accessor'))
    return MerchantType.accessories;
  if (lower.contains('جزار') || lower.contains('butcher'))
    return MerchantType.butcher;
  if (lower.contains('خضراوات') ||
      lower.contains('خضروات') ||
      lower.contains('خضار') ||
      lower.contains('فواك') ||
      lower.contains('vegetable'))
    return MerchantType.vegetables;
  return null;
}

/// Daily/repeat demand priority used for the home grid and the all-services
/// page: restaurants, grocery, vegetables & fruits, home services,
/// bakery, sweets first.
List<MerchantType> get dailyDemandPriority => <MerchantType>[
  MerchantType.restaurant,
  MerchantType.grocery,
  MerchantType.vegetables,
  MerchantType.fruits,
  MerchantType.butcher,
  MerchantType.dairy,
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
      ServiceCategoryType.applianceRepair =>
        l10n.serviceCategoryApplianceRepair,
      ServiceCategoryType.pipeChange => l10n.serviceCategoryPipeChange,
      ServiceCategoryType.plastering => l10n.serviceCategoryPlastering,
      ServiceCategoryType.carpetCleaning => l10n.serviceCategoryCarpetCleaning,
      ServiceCategoryType.dishRepair => l10n.serviceCategoryDishRepair,
      ServiceCategoryType.other => l10n.serviceOther,
    };

/// Returns `null` so every category tile displays its own dedicated,
/// category-accurate real photo from [defaultCategoryImageUrl] instead of
/// sharing a generic local bundle image across unrelated categories.
String? merchantCategoryAsset(String type) => null;

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

/// Maps Arabic or English category/service names to [ServiceCategoryType].
ServiceCategoryType? categoryNameToServiceType(String name) {
  final lower = name.toLowerCase().trim();
  if (lower.isEmpty) return null;

  for (final value in ServiceCategoryType.values) {
    if (value != ServiceCategoryType.other &&
        lower == value.name.toLowerCase()) {
      return value;
    }
  }

  if (lower.contains('سجاد') ||
      lower.contains('موكيت') ||
      lower.contains('carpet')) {
    return ServiceCategoryType.carpetCleaning;
  }
  if (lower.contains('سباكة') ||
      lower.contains('سباك') ||
      lower.contains('plumbing') ||
      lower.contains('plumber')) {
    return ServiceCategoryType.plumbing;
  }
  if (lower.contains('كهرباء') ||
      lower.contains('كهربائي') ||
      lower.contains('electrical') ||
      lower.contains('electrician')) {
    return ServiceCategoryType.electrical;
  }
  if (lower.contains('نجارة') ||
      lower.contains('نجار') ||
      lower.contains('carpentry') ||
      lower.contains('carpenter')) {
    return ServiceCategoryType.carpentry;
  }
  if (lower.contains('تكييف') ||
      lower.contains('تبريد') ||
      lower.contains('ac_maintenance') ||
      lower.contains('ac maintenance') ||
      lower.contains('air condition') ||
      RegExp(r'\bac\b').hasMatch(lower)) {
    return ServiceCategoryType.acMaintenance;
  }
  if (lower.contains('نقاشة') ||
      lower.contains('محارة') ||
      lower.contains('جبس') ||
      lower.contains('plaster')) {
    return ServiceCategoryType.plastering;
  }
  if (lower.contains('دهان') ||
      lower.contains('painting') ||
      lower.contains('painter')) {
    return ServiceCategoryType.painting;
  }
  if (lower.contains('تنظيف') ||
      lower.contains('نظافة') ||
      lower.contains('cleaning')) {
    return ServiceCategoryType.cleaning;
  }
  if (lower.contains('حشرات') ||
      lower.contains('مكافحة') ||
      lower.contains('pest')) {
    return ServiceCategoryType.pestControl;
  }
  if (lower.contains('إصلاح أجهزة') ||
      lower.contains('اصلاح اجهزة') ||
      lower.contains('صيانة أجهزة') ||
      lower.contains('appliance_repair') ||
      lower.contains('appliance repair') ||
      (lower.contains('appliance') &&
          !lower.contains('home appliance') &&
          !lower.contains('أجهزة منزلية'))) {
    return ServiceCategoryType.applianceRepair;
  }
  if (lower.contains('أنبوبة') ||
      lower.contains('انبوبه') ||
      lower.contains('انبوبة') ||
      lower.contains('أنبوبه') ||
      lower.contains('أنابيب') ||
      lower.contains('انابيب') ||
      lower.contains('pipe')) {
    return ServiceCategoryType.pipeChange;
  }
  if (lower.contains('دش') ||
      lower.contains('ستلايت') ||
      lower.contains('dish_repair') ||
      lower.contains('dish repair') ||
      lower.contains('satellite') ||
      RegExp(r'\bdish\b').hasMatch(lower)) {
    return ServiceCategoryType.dishRepair;
  }
  if (lower.contains('مدرس') ||
      lower.contains('تعليم') ||
      lower.contains('دروس') ||
      lower.contains('teacher') ||
      lower.contains('tutor')) {
    return ServiceCategoryType.teacher;
  }
  if (lower.contains('دكتور') ||
      lower.contains('طبيب') ||
      lower.contains('عيادة') ||
      lower.contains('doctor') ||
      lower.contains('physician')) {
    return ServiceCategoryType.doctor;
  }
  if (lower.contains('ممرض') ||
      lower.contains('تمريض') ||
      lower.contains('nurse') ||
      lower.contains('nursing')) {
    return ServiceCategoryType.nurse;
  }
  if (lower.contains('حلاق') ||
      lower.contains('كوافير') ||
      lower.contains('barber')) {
    return ServiceCategoryType.barber;
  }
  return null;
}

/// Curated thumbnail image URL for every [ServiceCategoryType] so service
/// buttons always display a clear, vibrant photo.
String defaultServiceImageUrl(ServiceCategoryType type) => switch (type) {
  ServiceCategoryType.doctor => 'https://images.unsplash.com/photo-1622253692010-333f2da6031d?auto=format&fit=crop&w=240&q=80',
  ServiceCategoryType.nurse => 'https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?auto=format&fit=crop&w=240&q=80',
  ServiceCategoryType.teacher => 'https://images.unsplash.com/photo-1524178232363-1fb2b075b655?auto=format&fit=crop&w=240&q=80',
  ServiceCategoryType.barber => 'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?auto=format&fit=crop&w=240&q=80',
  ServiceCategoryType.plumbing => 'https://images.unsplash.com/photo-1585704032915-c3400ca199e7?auto=format&fit=crop&w=240&q=80',
  ServiceCategoryType.electrical => 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?auto=format&fit=crop&w=240&q=80',
  ServiceCategoryType.carpentry => 'https://images.unsplash.com/photo-1504148455328-c376907d081c?auto=format&fit=crop&w=240&q=80',
  ServiceCategoryType.painting => 'https://images.unsplash.com/photo-1562259949-e8e7689d7828?auto=format&fit=crop&w=240&q=80',
  ServiceCategoryType.cleaning => 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?auto=format&fit=crop&w=240&q=80',
  ServiceCategoryType.acMaintenance => 'https://images.unsplash.com/photo-1621905252507-b35492cc74b4?auto=format&fit=crop&w=240&q=80',
  ServiceCategoryType.pipeChange => 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=240&q=80',
  ServiceCategoryType.plastering => 'https://images.unsplash.com/photo-1504307651254-35680f356dfd?auto=format&fit=crop&w=240&q=80',
  ServiceCategoryType.carpetCleaning => 'https://images.unsplash.com/photo-1558317374-067fb5f30001?auto=format&fit=crop&w=240&q=80',
  ServiceCategoryType.dishRepair => 'https://images.unsplash.com/photo-1593784991095-a205069470b6?auto=format&fit=crop&w=240&q=80',
  ServiceCategoryType.pestControl => 'https://images.unsplash.com/photo-1584820927498-cfe5211fd8bf?auto=format&fit=crop&w=240&q=80',
  ServiceCategoryType.applianceRepair => 'https://images.unsplash.com/photo-1581092921461-eab62e97a780?auto=format&fit=crop&w=240&q=80',
  ServiceCategoryType.other => 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?auto=format&fit=crop&w=240&q=80',
};

/// Curated thumbnail image URL for any merchant category name or [MerchantType].
String defaultCategoryImageUrl(String typeOrName) {
  final serviceType = categoryNameToServiceType(typeOrName);
  if (serviceType != null) {
    return defaultServiceImageUrl(serviceType);
  }

  MerchantType? merchantType;
  final lower = typeOrName.toLowerCase().trim();
  for (final value in MerchantType.values) {
    if (value.name.toLowerCase() == lower) {
      merchantType = value;
      break;
    }
  }
  merchantType ??= categoryNameToMerchantType(typeOrName) ?? MerchantType.other;

  return switch (merchantType) {
    MerchantType.restaurant => 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=240&q=80',
    MerchantType.grocery => 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=240&q=80',
    MerchantType.supermarket => 'https://images.unsplash.com/photo-1578916171728-46686eac8d58?auto=format&fit=crop&w=240&q=80',
    MerchantType.fruits => 'https://images.unsplash.com/photo-1610832958506-aa56368176cf?auto=format&fit=crop&w=240&q=80',
    MerchantType.vegetables => 'https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=240&q=80',
    MerchantType.meat => 'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?auto=format&fit=crop&w=240&q=80',
    MerchantType.butcher => 'https://images.unsplash.com/photo-1551028150-64b9f398f678?auto=format&fit=crop&w=240&q=80',
    MerchantType.seafood => 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=240&q=80',
    MerchantType.bakery => 'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=240&q=80',
    MerchantType.sweets => 'https://images.unsplash.com/photo-1551024601-bec78aea704b?auto=format&fit=crop&w=240&q=80',
    MerchantType.flowers => 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?auto=format&fit=crop&w=240&q=80',
    MerchantType.clothing => 'https://images.unsplash.com/photo-1441986300917-64674bd600d8?auto=format&fit=crop&w=240&q=80',
    MerchantType.shoes => 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=240&q=80',
    MerchantType.electronics => 'https://images.unsplash.com/photo-1498049794561-7780e7231661?auto=format&fit=crop&w=240&q=80',
    MerchantType.mobile => 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?auto=format&fit=crop&w=240&q=80',
    MerchantType.furniture => 'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?auto=format&fit=crop&w=240&q=80',
    MerchantType.fashion => 'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&w=240&q=80',
    MerchantType.appliances => 'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?auto=format&fit=crop&w=240&q=80',
    MerchantType.home => 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?auto=format&fit=crop&w=240&q=80',
    MerchantType.cafe => 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=240&q=80',
    MerchantType.petShop => 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&w=240&q=80',
    MerchantType.fitness => 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?auto=format&fit=crop&w=240&q=80',
    MerchantType.gas => 'https://images.unsplash.com/photo-1545147986-a9d6f2ab03b5?auto=format&fit=crop&w=240&q=80',
    MerchantType.carwash => 'https://images.unsplash.com/photo-1520340356584-f9917d1eea6f?auto=format&fit=crop&w=240&q=80',
    MerchantType.perfumes => 'https://images.unsplash.com/photo-1541643600914-78b084683601?auto=format&fit=crop&w=240&q=80',
    MerchantType.spices => 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?auto=format&fit=crop&w=240&q=80',
    MerchantType.dairy => 'https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=240&q=80',
    MerchantType.accessories => 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?auto=format&fit=crop&w=240&q=80',
    MerchantType.other => 'https://images.unsplash.com/photo-1472851294608-062f824d29cc?auto=format&fit=crop&w=240&q=80',
  };
}

/// Sleek 3D-styled rounded tile icon with a unified Royal Indigo/Violet/Gold
/// palette and visible category photography paired with a crisp mini icon badge.
class Category3dTileIcon extends StatelessWidget {
  const Category3dTileIcon({
    super.key,
    required this.color,
    required this.icon,
    this.networkImageUrl,
    this.assetImagePath,
    this.fallbackImageUrl,
    this.size = 64,
    this.borderRadius = 18,
  });

  final Color color;
  final IconData icon;
  final String? networkImageUrl;
  final String? assetImagePath;
  final String? fallbackImageUrl;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);
    final innerRadius = BorderRadius.circular(
      (borderRadius - 1.0).clamp(0, borderRadius),
    );
    final cardSurface = isDark
        ? const Color(0xFF261E40)
        : const Color(0xFFF3EEFF);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : AppColors.brandPurple.withValues(alpha: 0.12);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : AppColors.brandPurple).withValues(
              alpha: isDark ? 0.24 : 0.08,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: borderColor),
      ),
      child: ClipRRect(
        borderRadius: innerRadius,
        child: _buildPrimaryLayer(isDark),
      ),
    );
  }

  Widget _buildPrimaryLayer(bool isDark) {
    if (networkImageUrl != null && networkImageUrl!.trim().isNotEmpty) {
      return Image.network(
        networkImageUrl!.trim(),
        width: size,
        height: size,
        fit: BoxFit.cover,
        frameBuilder: (ctx, child, frame, sync) =>
            _photoFrameBuilder(ctx, child, frame, sync, isDark),
        errorBuilder: (_, _, _) => _buildAssetOrFallbackLayer(isDark),
      );
    }
    return _buildAssetOrFallbackLayer(isDark);
  }

  Widget _buildAssetOrFallbackLayer(bool isDark) {
    if (assetImagePath != null && assetImagePath!.trim().isNotEmpty) {
      return Image.asset(
        assetImagePath!.trim(),
        width: size,
        height: size,
        fit: BoxFit.cover,
        frameBuilder: (ctx, child, frame, sync) =>
            _photoFrameBuilder(ctx, child, frame, sync, isDark),
        errorBuilder: (_, _, _) => _buildFallbackNetworkOrIconLayer(isDark),
      );
    }
    return _buildFallbackNetworkOrIconLayer(isDark);
  }

  Widget _buildFallbackNetworkOrIconLayer(bool isDark) {
    if (fallbackImageUrl != null && fallbackImageUrl!.trim().isNotEmpty) {
      return Image.network(
        fallbackImageUrl!.trim(),
        width: size,
        height: size,
        fit: BoxFit.cover,
        frameBuilder: (ctx, child, frame, sync) =>
            _photoFrameBuilder(ctx, child, frame, sync, isDark),
        errorBuilder: (_, _, _) => _build3dIconLayer(isDark),
      );
    }
    return _build3dIconLayer(isDark);
  }

  Widget _photoFrameBuilder(
    BuildContext context,
    Widget child,
    int? frame,
    bool wasSynchronouslyLoaded,
    bool isDark,
  ) {
    final loaded = wasSynchronouslyLoaded || frame != null;
    if (!loaded) {
      return Stack(
        fit: StackFit.expand,
        children: [_build3dIconLayer(isDark), child],
      );
    }
    return child;
  }

  Widget _build3dIconLayer(bool isDark) {
    final iconColor = isDark ? Colors.white : AppColors.brandPurple;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.35, -0.35),
              radius: 0.9,
              colors: [
                Colors.white.withValues(alpha: isDark ? 0.14 : 0.75),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Center(
          child: Icon(icon, color: iconColor, size: size * 0.46),
        ),
      ],
    );
  }
}

const List<ServiceCategoryType> serviceCategoryPriority = [
  ServiceCategoryType.doctor,
  ServiceCategoryType.nurse,
  ServiceCategoryType.teacher,
  ServiceCategoryType.barber,
  ServiceCategoryType.plumbing,
  ServiceCategoryType.electrical,
  ServiceCategoryType.carpentry,
  ServiceCategoryType.painting,
  ServiceCategoryType.cleaning,
  ServiceCategoryType.acMaintenance,
  ServiceCategoryType.pipeChange,
  ServiceCategoryType.plastering,
  ServiceCategoryType.carpetCleaning,
  ServiceCategoryType.dishRepair,
  ServiceCategoryType.pestControl,
  ServiceCategoryType.applianceRepair,
];

int serviceCategoryRank(ServiceCategoryType type) {
  final index = serviceCategoryPriority.indexOf(type);
  return index == -1 ? serviceCategoryPriority.length : index;
}

IconData serviceCategoryIcon(ServiceCategoryType type) => switch (type) {
  ServiceCategoryType.doctor => Icons.medical_services_rounded,
  ServiceCategoryType.nurse => Icons.health_and_safety_rounded,
  ServiceCategoryType.teacher => Icons.school_rounded,
  ServiceCategoryType.barber => Icons.content_cut_rounded,
  ServiceCategoryType.plumbing => Icons.plumbing_rounded,
  ServiceCategoryType.electrical => Icons.electrical_services_rounded,
  ServiceCategoryType.carpentry => Icons.carpenter_rounded,
  ServiceCategoryType.painting => Icons.format_paint_rounded,
  ServiceCategoryType.cleaning => Icons.cleaning_services_rounded,
  ServiceCategoryType.acMaintenance => Icons.ac_unit_rounded,
  ServiceCategoryType.pipeChange => Icons.settings_input_component_rounded,
  ServiceCategoryType.plastering => Icons.format_color_fill_rounded,
  ServiceCategoryType.carpetCleaning => Icons.local_laundry_service_rounded,
  ServiceCategoryType.dishRepair => Icons.satellite_alt_rounded,
  ServiceCategoryType.pestControl => Icons.bug_report_rounded,
  ServiceCategoryType.applianceRepair => Icons.build_rounded,
  ServiceCategoryType.other => Icons.home_repair_service_rounded,
};
