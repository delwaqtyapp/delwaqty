import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/services/logger/app_logger.dart';
import 'package:delwaqty/features/commerce/domain/entities/product.dart';

final supabaseProductDataSourceProvider =
    Provider<SupabaseProductDataSource>((ref) {
  return SupabaseProductDataSource(
    ref.watch(supabaseClientProvider),
    ref.watch(loggerProvider),
  );
});

class SupabaseProductDataSource {
  SupabaseProductDataSource(this._client, this._logger);

  final SupabaseClient _client;
  final AppLogger _logger;

  static const String _tableName = 'products';

  Product _fromRow(Map<String, dynamic> row) {
    return Product(
      id: row['id'] as String,
      merchantId: row['merchant_id'] as String,
      categoryId: row['category'] as String? ?? '',
      name: row['name'] as String,
      description: row['description'] as String?,
      price: (row['price'] as num).toDouble(),
      originalPrice: row['compare_at_price'] != null
          ? (row['compare_at_price'] as num).toDouble()
          : null,
      imageUrl: row['image_url'] as String?,
      isAvailable: row['is_available'] as bool? ?? true,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : null,
    );
  }

  Future<List<Product>> getProducts({
    required String merchantId,
    String? categoryId,
    bool? isAvailable,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      var query = _client.from(_tableName).select().eq('merchant_id', merchantId);

      if (categoryId != null) {
        query = query.eq('category', categoryId);
      }
      if (isAvailable != null) {
        query = query.eq('is_available', isAvailable);
      }

      final data = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (data as List)
          .map((row) => _fromRow(row as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      _logger.e('Failed to get products for $merchantId', e, stack);
      rethrow;
    }
  }

  Future<Product?> getProductById(String id) async {
    try {
      final data = await _client
          .from(_tableName)
          .select()
          .eq('id', id)
          .maybeSingle();
      if (data == null) return null;
      return _fromRow(data);
    } catch (e, stack) {
      _logger.e('Failed to get product: $id', e, stack);
      rethrow;
    }
  }

  Future<List<Product>> getFeaturedProducts(String merchantId) async {
    try {
      final data = await _client
          .from(_tableName)
          .select()
          .eq('merchant_id', merchantId)
          .eq('is_available', true)
          .order('created_at', ascending: false)
          .limit(10);
      return (data as List)
          .map((row) => _fromRow(row as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      _logger.e('Failed to get featured products for $merchantId', e, stack);
      rethrow;
    }
  }

  Future<List<Product>> searchProducts(String query, {String? merchantId}) async {
    try {
      var q = _client
          .from(_tableName)
          .select()
          .or('name.ilike.%$query%,description.ilike.%$query%');

      if (merchantId != null) {
        q = q.eq('merchant_id', merchantId);
      }

      final data = await q.order('name').limit(20);
      return (data as List)
          .map((row) => _fromRow(row as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      _logger.e('Failed to search products: $query', e, stack);
      rethrow;
    }
  }
}
