import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/search_filter.dart';
import 'package:delwaqty/features/customer/commerce/domain/repositories/merchant_repository.dart';
import 'package:delwaqty/features/customer/commerce/commerce_module.dart';
import 'package:delwaqty/data/datasources/local/hive_cache_service.dart';
import 'package:delwaqty/services/connectivity/connectivity_service.dart';

final cachedMerchantRepositoryProvider = Provider<CachedMerchantRepository>((ref) {
  return CachedMerchantRepository(
    inner: ref.watch(merchantRepositoryProvider),
    cache: ref.watch(hiveCacheServiceProvider),
    connectivity: ref.watch(connectivityServiceProvider),
  );
});

class CachedMerchantRepository implements MerchantRepository {
  CachedMerchantRepository({
    required this.inner,
    required this.cache,
    required this.connectivity,
  });

  final MerchantRepository inner;
  final HiveCacheService cache;
  final ConnectivityService connectivity;

  bool get _isOnline => connectivity.currentStatus == ConnectivityStatus.connected;

  @override
  Future<List<Merchant>> getMerchants({
    MerchantType? type,
    String? city,
    bool? isOpenNow,
    SearchFilter? filter,
    int limit = 20,
    int offset = 0,
  }) async {
    final cacheKey = '${type?.name ?? 'all'}_${filter?.sortBy.name ?? 'distance'}';

    if (_isOnline) {
      try {
        final fresh = await inner.getMerchants(
          type: type,
          city: city,
          isOpenNow: isOpenNow,
          filter: filter,
          limit: limit,
          offset: offset,
        );
        if (offset == 0) {
          await cache.cacheMerchants(fresh, key: cacheKey);
        }
        return fresh;
      } catch (_) {
        final cached = cache.getCachedMerchants(key: cacheKey);
        if (cached.isNotEmpty) return cached;
        rethrow;
      }
    } else {
      final cached = cache.getCachedMerchants(key: cacheKey);
      if (cached.isNotEmpty) return cached;
      return inner.getMerchants(
        type: type,
        city: city,
        isOpenNow: isOpenNow,
        filter: filter,
        limit: limit,
        offset: offset,
      );
    }
  }

  @override
  Future<Merchant?> getMerchantById(String id) async {
    if (_isOnline) {
      try {
        return await inner.getMerchantById(id);
      } catch (_) {
        final cached = cache.getCachedMerchants().where((m) => m.id == id).toList();
        return cached.isNotEmpty ? cached.first : null;
      }
    }
    final cached = cache.getCachedMerchants().where((m) => m.id == id).toList();
    return cached.isNotEmpty ? cached.first : null;
  }

  @override
  Future<List<Merchant>> getFeaturedMerchants() async {
    if (_isOnline) {
      try {
        final fresh = await inner.getFeaturedMerchants();
        await cache.cacheMerchants(fresh, key: 'featured');
        return fresh;
      } catch (_) {
        final cached = cache.getCachedMerchants(key: 'featured');
        if (cached.isNotEmpty) return cached;
        rethrow;
      }
    }
    final cached = cache.getCachedMerchants(key: 'featured');
    if (cached.isNotEmpty) return cached;
    return inner.getFeaturedMerchants();
  }

  @override
  Future<List<Merchant>> searchMerchants(String query) async {
    if (_isOnline) {
      try {
        return await inner.searchMerchants(query);
      } catch (_) {
        return cache.getCachedMerchants().where((m) =>
          m.name.toLowerCase().contains(query.toLowerCase()) ||
          (m.description?.toLowerCase().contains(query.toLowerCase()) ?? false)
        ).toList();
      }
    }
    return cache.getCachedMerchants().where((m) =>
      m.name.toLowerCase().contains(query.toLowerCase()) ||
      (m.description?.toLowerCase().contains(query.toLowerCase()) ?? false)
    ).toList();
  }

  @override
  Future<List<Merchant>> getMerchantsByType(MerchantType type) async {
    if (_isOnline) {
      try {
        final fresh = await inner.getMerchantsByType(type);
        await cache.cacheMerchants(fresh, key: type.name);
        return fresh;
      } catch (_) {
        final cached = cache.getCachedMerchants(key: type.name);
        if (cached.isNotEmpty) return cached;
        rethrow;
      }
    }
    final cached = cache.getCachedMerchants(key: type.name);
    if (cached.isNotEmpty) return cached;
    return inner.getMerchantsByType(type);
  }
}
