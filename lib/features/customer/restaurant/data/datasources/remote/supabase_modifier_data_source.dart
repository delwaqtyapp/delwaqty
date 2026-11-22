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

  /// Required modifier groups for a product: group id -> its option ids.
  /// Used to block checkout until every required group has a pick.
  Future<Map<String, Set<String>>> getRequiredGroupOptions(
    String productId,
  ) async {
    final groups = await _client
        .from('product_modifier_groups')
        .select('id')
        .eq('product_id', productId)
        .eq('is_required', true);
    final groupRows = (groups as List).cast<Map<String, dynamic>>();
    if (groupRows.isEmpty) return const {};
    final groupIds = [for (final g in groupRows) g['id'] as String];
    final options = await _client
        .from('product_modifier_options')
        .select('id, group_id')
        .inFilter('group_id', groupIds);
    final result = <String, Set<String>>{for (final id in groupIds) id: {}};
    for (final o in (options as List).cast<Map<String, dynamic>>()) {
      result[o['group_id']]?.add(o['id'] as String);
    }
    return result;
  }

  Future<List<ProductModifier>> getModifiers(String productId) async {
    // Read the group model (product_modifier_groups + _options), which is
    // what merchants manage and what the server-side pricing validates.
    // The old flat product_modifiers table is legacy. Flattened here so the
    // product detail page keeps its existing checkbox UI.
    final groups = await _client
        .from('product_modifier_groups')
        .select('id, sort_order')
        .eq('product_id', productId)
        .order('sort_order');
    final groupRows = (groups as List).cast<Map<String, dynamic>>();
    if (groupRows.isEmpty) return const [];
    final groupIds = [for (final g in groupRows) g['id'] as String];
    final options = await _client
        .from('product_modifier_options')
        .select('id, group_id, name, name_ar, price_adjustment, sort_order')
        .inFilter('group_id', groupIds)
        .order('sort_order');
    final optionRows = (options as List).cast<Map<String, dynamic>>();
    final groupOrder = {
      for (var i = 0; i < groupRows.length; i++) groupRows[i]['id']: i,
    };
    optionRows.sort(
      (a, b) => (groupOrder[a['group_id']] ?? 0).compareTo(
        groupOrder[b['group_id']] ?? 0,
      ),
    );
    return [
      for (final (i, o) in optionRows.indexed)
        ProductModifier(
          id: o['id'] as String,
          productId: productId,
          name: ((o['name_ar'] ?? '') as String).isNotEmpty
              ? o['name_ar'] as String
              : (o['name'] ?? '') as String,
          description: null,
          priceAdjustment: (o['price_adjustment'] as num? ?? 0).toDouble(),
          isAvailable: true,
          sortOrder: i,
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
    ];
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
