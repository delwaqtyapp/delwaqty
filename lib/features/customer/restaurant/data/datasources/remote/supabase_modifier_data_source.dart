import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/product_modifier.dart';

final supabaseModifierDataSourceProvider = Provider<SupabaseModifierDataSource>(
  (ref) {
    return SupabaseModifierDataSource(ref.watch(supabaseClientProvider));
  },
);

class SupabaseModifierDataSource {
  SupabaseModifierDataSource(this._client);
  final SupabaseClient _client;

  ProductModifier _fromRow(Map<String, dynamic> row) => ProductModifier(
    id: row['id'] as String,
    productId: row['product_id'] as String,
    name: row['name'] as String,
    description: row['description'] as String?,
    priceAdjustment: (row['price_adjustment'] as num? ?? 0).toDouble(),
    isAvailable: row['is_available'] as bool? ?? true,
    sortOrder: row['sort_order'] as int? ?? 0,
    createdAt: DateTime.parse(row['created_at'] as String),
  );

  Future<List<ProductModifier>> getModifiers(String productId) async {
    final data = await _client
        .from('product_modifiers')
        .select()
        .eq('product_id', productId)
        .order('sort_order');
    return (data as List)
        .map((r) => _fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<ProductModifier> createModifier(ProductModifier modifier) async {
    final data = await _client
        .from('product_modifiers')
        .insert({
          'product_id': modifier.productId,
          'name': modifier.name,
          'description': modifier.description,
          'price_adjustment': modifier.priceAdjustment,
          'is_available': modifier.isAvailable,
          'sort_order': modifier.sortOrder,
        })
        .select()
        .single();
    return _fromRow(data);
  }

  Future<ProductModifier> updateModifier(ProductModifier modifier) async {
    final data = await _client
        .from('product_modifiers')
        .update({
          'name': modifier.name,
          'description': modifier.description,
          'price_adjustment': modifier.priceAdjustment,
          'is_available': modifier.isAvailable,
          'sort_order': modifier.sortOrder,
        })
        .eq('id', modifier.id)
        .select()
        .single();
    return _fromRow(data);
  }

  Future<void> deleteModifier(String id) async {
    await _client.from('product_modifiers').delete().eq('id', id);
  }
}
