import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:delwaqty/features/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/commerce/domain/entities/product.dart';
import 'package:delwaqty/features/home_services/domain/entities/service_category.dart';
import 'package:delwaqty/services/logger/app_logger.dart';

const String _merchantsBox = 'cached_merchants';
const String _productsBox = 'cached_products';
const String _categoriesBox = 'cached_service_categories';
const String _metadataBox = 'cache_metadata';

const Duration _defaultTtl = Duration(minutes: 15);

final hiveCacheServiceProvider = Provider<HiveCacheService>((ref) {
  return HiveCacheService(ref.watch(loggerProvider));
});

class HiveCacheService {
  HiveCacheService(this._logger);

  final AppLogger _logger;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Future.wait([
        Hive.openBox<Map>(_merchantsBox),
        Hive.openBox<Map>(_productsBox),
        Hive.openBox<Map>(_categoriesBox),
        Hive.openBox<Map>(_metadataBox),
      ]);
      _initialized = true;
    } catch (e) {
      _logger.e('Hive init failed', e);
    }
  }

  Box<Map> get _merchants => Hive.box<Map>(_merchantsBox);
  Box<Map> get _products => Hive.box<Map>(_productsBox);
  Box<Map> get _categories => Hive.box<Map>(_categoriesBox);
  Box<Map> get _metadata => Hive.box<Map>(_metadataBox);

  DateTime? _getLastUpdated(String key) {
    final meta = _metadata.get(key);
    if (meta == null) return null;
    return DateTime.tryParse(meta['updatedAt'] as String? ?? '');
  }

  void _setLastUpdated(String key) {
    _metadata.put(key, {'updatedAt': DateTime.now().toIso8601String()});
  }

  bool _isStale(String key, {Duration ttl = _defaultTtl}) {
    final lastUpdated = _getLastUpdated(key);
    if (lastUpdated == null) return true;
    return DateTime.now().difference(lastUpdated) > ttl;
  }

  Future<void> cacheMerchants(List<Merchant> merchants, {String key = 'all'}) async {
    try {
      final data = <String, Map>{
        for (final m in merchants) m.id: m.toJson()..['cached_at'] = DateTime.now().toIso8601String(),
      };
      await _merchants.putAll(data);
      _setLastUpdated('merchants_$key');
    } catch (e) {
      _logger.e('Cache merchants failed', e);
    }
  }

  List<Merchant> getCachedMerchants({String key = 'all', Duration ttl = _defaultTtl}) {
    try {
      if (_isStale('merchants_$key', ttl: ttl)) return [];
      return _merchants.values
          .where((m) => m.containsKey('cached_at'))
          .map((m) {
        final json = Map<String, dynamic>.from(m)..remove('cached_at');
        return Merchant.fromJson(json);
      }).toList();
    } catch (e) {
      _logger.e('Get cached merchants failed', e);
      return [];
    }
  }

  Future<void> cacheProducts(List<Product> products, {String key = 'all'}) async {
    try {
      final data = <String, Map>{
        for (final p in products) p.id: p.toJson()..['cached_at'] = DateTime.now().toIso8601String(),
      };
      await _products.putAll(data);
      _setLastUpdated('products_$key');
    } catch (e) {
      _logger.e('Cache products failed', e);
    }
  }

  List<Product> getCachedProducts({String key = 'all', Duration ttl = _defaultTtl}) {
    try {
      if (_isStale('products_$key', ttl: ttl)) return [];
      return _products.values
          .where((p) => p.containsKey('cached_at'))
          .map((p) {
        final json = Map<String, dynamic>.from(p)..remove('cached_at');
        return Product.fromJson(json);
      }).toList();
    } catch (e) {
      _logger.e('Get cached products failed', e);
      return [];
    }
  }

  Future<void> cacheServiceCategories(List<ServiceCategory> categories) async {
    try {
      final data = <String, Map>{
        for (final c in categories) c.id: c.toJson()..['cached_at'] = DateTime.now().toIso8601String(),
      };
      await _categories.putAll(data);
      _setLastUpdated('categories');
    } catch (e) {
      _logger.e('Cache categories failed', e);
    }
  }

  List<ServiceCategory> getCachedServiceCategories({Duration ttl = _defaultTtl}) {
    try {
      if (_isStale('categories', ttl: ttl)) return [];
      return _categories.values
          .where((c) => c.containsKey('cached_at'))
          .map((c) {
        final json = Map<String, dynamic>.from(c)..remove('cached_at');
        return ServiceCategory.fromJson(json);
      }).toList();
    } catch (e) {
      _logger.e('Get cached categories failed', e);
      return [];
    }
  }

  Future<void> clearAll() async {
    await Future.wait([
      _merchants.clear(),
      _products.clear(),
      _categories.clear(),
      _metadata.clear(),
    ]);
  }
}
