import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/features/customer/commerce/commerce_module.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/search_filter.dart';

IconData merchantTypeIcon(MerchantType type) {
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
    case MerchantType.perfumes:
      return Icons.spa;
    case MerchantType.spices:
      return Icons.rice_bowl;
    case MerchantType.dairy:
      return Icons.water_drop;
    case MerchantType.accessories:
      return Icons.diamond;
    case MerchantType.butcher:
      return Icons.outdoor_grill;
    case MerchantType.vegetables:
      return Icons.grass;
    case MerchantType.other:
      return Icons.store;
  }
}

Color merchantTypeColor(MerchantType type) {
  switch (type) {
    case MerchantType.restaurant:
      return AppColors.serviceRestaurant;
    case MerchantType.grocery:
      return AppColors.serviceGrocery;
    case MerchantType.supermarket:
      return AppColors.serviceSupermarket;
    case MerchantType.fruits:
      return AppColors.serviceFruits;
    case MerchantType.meat:
      return AppColors.serviceMeat;
    case MerchantType.seafood:
      return AppColors.serviceSeafood;
    case MerchantType.pharmacy:
      return AppColors.servicePharmacy;
    case MerchantType.bakery:
      return AppColors.serviceBakery;
    case MerchantType.sweets:
      return AppColors.serviceSweets;
    case MerchantType.flowers:
      return AppColors.serviceFlowers;
    case MerchantType.clothing:
      return AppColors.serviceClothing;
    case MerchantType.shoes:
      return AppColors.serviceShoes;
    case MerchantType.electronics:
      return AppColors.serviceElectronics;
    case MerchantType.mobile:
      return AppColors.serviceMobile;
    case MerchantType.furniture:
      return AppColors.serviceFurniture;
    case MerchantType.fashion:
      return AppColors.serviceFashion;
    case MerchantType.appliances:
      return AppColors.serviceAppliances;
    case MerchantType.home:
      return AppColors.serviceHome;
    case MerchantType.cafe:
      return AppColors.serviceCafe;
    case MerchantType.petShop:
      return AppColors.servicePetShop;
    case MerchantType.fitness:
      return AppColors.serviceFitness;
    case MerchantType.gas:
      return AppColors.serviceGas;
    case MerchantType.carwash:
      return AppColors.serviceCarwash;
    case MerchantType.perfumes:
      return AppColors.serviceFlowers;
    case MerchantType.spices:
      return AppColors.serviceSupermarket;
    case MerchantType.dairy:
      return AppColors.serviceGrocery;
    case MerchantType.accessories:
      return AppColors.serviceFashion;
    case MerchantType.butcher:
      return AppColors.serviceMeat;
    case MerchantType.vegetables:
      return AppColors.serviceFruits;
    case MerchantType.other:
      return AppColors.serviceMore;
  }
}

final searchQueryProvider = StateProvider<String>((_) => '');

final searchSelectedTypeProvider = StateProvider<MerchantType?>((_) => null);

final searchSelectedSortProvider = StateProvider<SortBy>(
  (_) => SortBy.distance,
);

final searchOpenNowFilterProvider = StateProvider<bool>((_) => false);

final searchPriceRangeProvider = StateProvider<RangeValues>(
  (_) => const RangeValues(0, 10000),
);

final recentSearchesProvider = StateProvider<List<String>>((_) => []);

final searchResultsProvider = FutureProvider<List<Merchant>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final type = ref.watch(searchSelectedTypeProvider);
  final sortBy = ref.watch(searchSelectedSortProvider);
  final openNow = ref.watch(searchOpenNowFilterProvider);
  final priceRange = ref.watch(searchPriceRangeProvider);
  final repo = ref.watch(merchantRepositoryProvider);

  final hasPriceFilter = priceRange.start > 0 || priceRange.end < 10000;

  if (query.trim().isEmpty && type == null && !hasPriceFilter) {
    return repo.getMerchants(filter: SearchFilter(sortBy: sortBy), limit: 50);
  }

  List<Merchant> results;
  if (query.trim().isNotEmpty) {
    results = await repo.searchMerchants(query.trim());
  } else {
    results = await repo.getMerchants(
      type: type,
      filter: SearchFilter(sortBy: sortBy),
      limit: 50,
    );
  }

  if (type != null) {
    results = results.where((m) => m.type == type).toList();
  }
  if (openNow) {
    results = results.where((m) => m.isOpenNow).toList();
  }
  if (hasPriceFilter) {
    results = results.where((m) {
      final price = m.minimumOrder ?? m.deliveryFee ?? 0;
      return price >= priceRange.start && price <= priceRange.end;
    }).toList();
  }

  return results;
});

final searchAutocompleteProvider = FutureProvider<List<String>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().length < 2) return [];
  final repo = ref.watch(merchantRepositoryProvider);
  final results = await repo.searchMerchants(query.trim());
  return results.take(5).map((m) => m.name).toList();
});
