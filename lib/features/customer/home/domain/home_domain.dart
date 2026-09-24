import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/customer/commerce/commerce_module.dart';
import 'package:delwaqty/features/customer/home/domain/entities/platform_category.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_provider.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_category.dart';
import 'package:delwaqty/data/repositories/category_repository_impl.dart';
import 'package:delwaqty/data/repositories/cached_service_booking_repository.dart';

final nearbyMerchantsProvider = FutureProvider<List<Merchant>>((ref) async {
  final repo = ref.watch(merchantRepositoryProvider);
  return repo.getMerchants();
});

final activeCategoriesProvider = FutureProvider<List<PlatformCategory>>((ref) async {
  final repo = ref.watch(platformCategoryRepositoryProvider);
  return repo.getActiveCategories();
});

enum DiscoveryMode { nearby, recommended, popular }

final discoveryModeProvider = StateProvider<DiscoveryMode>((_) => DiscoveryMode.nearby);

/// A discovery entry: either a marketplace merchant (restaurant, pharmacy,
/// grocery...) or a real booking service provider (doctor, barber, nurse,
/// teacher...). Both render as the same full-width list card under the
/// "اكتشف بالقرب منك" section so every actual service in the app shows up.
sealed class DiscoveryEntry {
  const DiscoveryEntry();
}

class MerchantDiscoveryEntry extends DiscoveryEntry {
  const MerchantDiscoveryEntry(this.merchant);
  final Merchant merchant;
}

class ProviderDiscoveryEntry extends DiscoveryEntry {
  const ProviderDiscoveryEntry(this.provider);
  final ServiceProvider provider;
}

const _bookingPriority = [
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

int _bookingRank(ServiceCategoryType type) {
  final i = _bookingPriority.indexOf(type);
  return i == -1 ? _bookingPriority.length : i;
}

final discoveryEntriesProvider = FutureProvider<List<DiscoveryEntry>>((ref) async {
  final mode = ref.watch(discoveryModeProvider);
  final repo = ref.watch(merchantRepositoryProvider);
  final serviceRepo = ref.watch(cachedServiceBookingRepositoryProvider);

  final merchantsFuture = repo.getMerchants(limit: 50);
  final providersFuture = serviceRepo.getProviders();
  final merchants = await merchantsFuture;
  final providers = await providersFuture;

  final entries = <DiscoveryEntry>[
    for (final m in merchants) MerchantDiscoveryEntry(m),
  ];
  final sortedProviders = [...providers]
    ..sort((a, b) => _bookingRank(a.categoryType).compareTo(_bookingRank(b.categoryType)));
  entries.addAll([
    for (final p in sortedProviders) ProviderDiscoveryEntry(p),
  ]);

  switch (mode) {
    case DiscoveryMode.nearby:
      return entries;
    case DiscoveryMode.recommended:
      final rated = entries.where((e) {
        if (e is MerchantDiscoveryEntry) return e.merchant.rating >= 4.0;
        if (e is ProviderDiscoveryEntry) return e.provider.rating >= 4.0;
        return false;
      }).toList();
      rated.sort((a, b) {
        final ra = a is MerchantDiscoveryEntry ? a.merchant.rating : (a as ProviderDiscoveryEntry).provider.rating;
        final rb = b is MerchantDiscoveryEntry ? b.merchant.rating : (b as ProviderDiscoveryEntry).provider.rating;
        return rb.compareTo(ra);
      });
      return rated.take(20).toList();
    case DiscoveryMode.popular:
      final featured = entries.where((e) {
        if (e is MerchantDiscoveryEntry) return e.merchant.isFeatured;
        if (e is ProviderDiscoveryEntry) return e.provider.ratingCount >= 3;
        return false;
      }).toList();
      if (featured.length >= 6) return featured.take(20).toList();
      entries.sort((a, b) {
        final ra = a is MerchantDiscoveryEntry ? a.merchant.ratingCount : (a as ProviderDiscoveryEntry).provider.ratingCount;
        final rb = b is MerchantDiscoveryEntry ? b.merchant.ratingCount : (b as ProviderDiscoveryEntry).provider.ratingCount;
        return rb.compareTo(ra);
      });
      return entries.take(20).toList();
  }
});
