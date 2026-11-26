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

  /// All modifier groups of a product with their selection rules and option
  /// membership (product_modifier_groups + product_modifier_options).
  Future<List<ModifierGroupInfo>> getModifierGroups(String productId) async {
    final groups = await _client
        .from('product_modifier_groups')
        .select('id, is_required, max_selections')
        .eq('product_id', productId)
        .order('sort_order');
    final groupRows = (groups as List).cast<Map<String, dynamic>>();
    if (groupRows.isEmpty) return const [];
    final groupIds = [for (final g in groupRows) g['id'] as String];
    final options = await _client
        .from('product_modifier_options')
        .select('id, group_id')
        .inFilter('group_id', groupIds);
    final byGroup = <String, Set<String>>{for (final id in groupIds) id: {}};
    for (final o in (options as List).cast<Map<String, dynamic>>()) {
      byGroup[o['group_id']]?.add(o['id'] as String);
    }
    return [
      for (final g in groupRows)
        ModifierGroupInfo(
          id: g['id'] as String,
          isRequired: g['is_required'] == true,
          maxSelections: (g['max_selections'] as num?)?.toInt() ?? 0,
          optionIds: byGroup[g['id']] ?? const {},
        ),
    ];
  }
}
