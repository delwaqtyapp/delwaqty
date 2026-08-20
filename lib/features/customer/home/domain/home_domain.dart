import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/customer/commerce/commerce_module.dart';
import 'package:delwaqty/features/customer/home/domain/entities/platform_category.dart';
import 'package:delwaqty/data/repositories/category_repository_impl.dart';

final nearbyMerchantsProvider = FutureProvider<List<Merchant>>((ref) async {
  final repo = ref.watch(merchantRepositoryProvider);
  return repo.getMerchants(limit: 20);
});

final activeCategoriesProvider = FutureProvider<List<PlatformCategory>>((ref) async {
  final repo = ref.watch(platformCategoryRepositoryProvider);
  return repo.getActiveCategories();
});

enum DiscoveryMode { nearby, recommended, popular }

final discoveryModeProvider = StateProvider<DiscoveryMode>((_) => DiscoveryMode.nearby);

final discoveryMerchantsProvider = FutureProvider<List<Merchant>>((ref) async {
  final mode = ref.watch(discoveryModeProvider);
  final repo = ref.watch(merchantRepositoryProvider);

  switch (mode) {
    case DiscoveryMode.nearby:
      return repo.getMerchants(limit: 20);
    case DiscoveryMode.recommended:
      final all = await repo.getMerchants(limit: 50);
      final rated = all.where((m) => m.rating >= 4.0).toList();
      rated.sort((a, b) => b.rating.compareTo(a.rating));
      return rated.take(20).toList();
    case DiscoveryMode.popular:
      final all = await repo.getMerchants(limit: 50);
      final featured = all.where((m) => m.isFeatured).toList();
      if (featured.length >= 6) return featured.take(20).toList();
      all.sort((a, b) => b.ratingCount.compareTo(a.ratingCount));
      return all.take(20).toList();
  }
});
