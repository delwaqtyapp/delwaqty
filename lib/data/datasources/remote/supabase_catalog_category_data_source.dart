import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/services/logger/app_logger.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/catalog_category.dart';

final supabaseCatalogCategoryDataSourceProvider =
    Provider<SupabaseCatalogCategoryDataSource>((ref) {
      return SupabaseCatalogCategoryDataSource(
        ref.watch(supabaseClientProvider),
        ref.watch(loggerProvider),
      );
    });

class SupabaseCatalogCategoryDataSource {
  SupabaseCatalogCategoryDataSource(this._client, this._logger);

  final SupabaseClient _client;
  final AppLogger _logger;

  static const String _tableName = 'catalog_categories';

  CatalogCategory _fromRow(Map<String, dynamic> row) {
    return CatalogCategory(
      id: row['id'] as String,
      merchantId: row['merchant_id'] as String,
      name: row['name'] as String,
      description: row['description'] as String?,
      icon: row['icon'] as String?,
      imageUrl: row['image_url'] as String?,
      sortOrder: row['sort_order'] as int? ?? 0,
      isVisible: row['is_visible'] as bool? ?? true,
    );
  }

  Future<List<CatalogCategory>> getCategories(String merchantId) async {
    try {
      final data = await _client
          .from(_tableName)
          .select()
          .eq('merchant_id', merchantId)
          .eq('is_visible', true)
          .order('sort_order');
      return (data as List)
          .map((row) => _fromRow(row as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      _logger.e('Failed to get catalog categories for $merchantId', e, stack);
      rethrow;
    }
  }

  Future<CatalogCategory?> getCategoryById(String id) async {
    try {
      final data = await _client
          .from(_tableName)
          .select()
          .eq('id', id)
          .maybeSingle();
      if (data == null) return null;
      return _fromRow(data);
    } catch (e, stack) {
      _logger.e('Failed to get catalog category: $id', e, stack);
      rethrow;
    }
  }
}
