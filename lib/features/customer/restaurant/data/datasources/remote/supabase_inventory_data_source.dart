import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/product_inventory.dart';

final supabaseInventoryDataSourceProvider =
    Provider<SupabaseInventoryDataSource>((ref) {
      return SupabaseInventoryDataSource(ref.watch(supabaseClientProvider));
    });

class SupabaseInventoryDataSource {
  SupabaseInventoryDataSource(this._client);
  final SupabaseClient _client;

  ProductInventory _fromRow(Map<String, dynamic> row) => ProductInventory(
    id: row['id'] as String,
    productId: row['product_id'] as String,
    merchantId: row['merchant_id'] as String,
    stockQuantity: row['stock_quantity'] as int? ?? 0,
    reservedQuantity: row['reserved_quantity'] as int? ?? 0,
    lowStockThreshold: row['low_stock_threshold'] as int? ?? 10,
    isInStock: row['is_in_stock'] as bool? ?? true,
    updatedAt: row['updated_at'] != null
        ? DateTime.parse(row['updated_at'] as String)
        : null,
  );

  Future<ProductInventory?> getInventory(String productId) async {
    final data = await _client
        .from('product_inventory')
        .select()
        .eq('product_id', productId)
        .maybeSingle();
    return data != null ? _fromRow(data) : null;
  }

  Future<List<ProductInventory>> getMerchantInventory(String merchantId) async {
    final data = await _client
        .from('product_inventory')
        .select()
        .eq('merchant_id', merchantId)
        .order('updated_at', ascending: false);
    return (data as List)
        .map((r) => _fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<ProductInventory> upsertInventory({
    required String productId,
    required String merchantId,
    required int stockQuantity,
    int? reservedQuantity,
    int? lowStockThreshold,
    bool? isInStock,
  }) async {
    final now = DateTime.now().toIso8601String();
    final data = await _client
        .from('product_inventory')
        .upsert({
          'product_id': productId,
          'merchant_id': merchantId,
          'stock_quantity': stockQuantity,
          if (reservedQuantity != null) 'reserved_quantity': reservedQuantity,
          if (lowStockThreshold != null)
            'low_stock_threshold': lowStockThreshold,
          if (isInStock != null) 'is_in_stock': isInStock,
          'updated_at': now,
        }, onConflict: 'product_id')
        .select()
        .single();
    return _fromRow(data);
  }

  Future<ProductInventory> adjustStock({
    required String productId,
    required int adjustment,
  }) async {
    final existing = await getInventory(productId);
    if (existing == null)
      throw Exception('Inventory not found for product: $productId');
    final newQty = existing.stockQuantity + adjustment;
    final isInStock = newQty > 0;
    return upsertInventory(
      productId: productId,
      merchantId: existing.merchantId,
      stockQuantity: newQty < 0 ? 0 : newQty,
      isInStock: isInStock,
      lowStockThreshold: existing.lowStockThreshold,
    );
  }

  Future<ProductInventory> reserveStock({
    required String productId,
    required int quantity,
  }) async {
    final existing = await getInventory(productId);
    if (existing == null)
      throw Exception('Inventory not found for product: $productId');
    final available = existing.stockQuantity - existing.reservedQuantity;
    if (available < quantity) throw Exception('Insufficient stock');
    return upsertInventory(
      productId: productId,
      merchantId: existing.merchantId,
      stockQuantity: existing.stockQuantity,
      reservedQuantity: existing.reservedQuantity + quantity,
      isInStock: existing.isInStock,
      lowStockThreshold: existing.lowStockThreshold,
    );
  }

  Future<ProductInventory> releaseStock({
    required String productId,
    required int quantity,
  }) async {
    final existing = await getInventory(productId);
    if (existing == null)
      throw Exception('Inventory not found for product: $productId');
    final newReserved = (existing.reservedQuantity - quantity).clamp(
      0,
      existing.reservedQuantity,
    );
    return upsertInventory(
      productId: productId,
      merchantId: existing.merchantId,
      stockQuantity: existing.stockQuantity,
      reservedQuantity: newReserved,
      isInStock: existing.isInStock,
      lowStockThreshold: existing.lowStockThreshold,
    );
  }

  Future<List<String>> getOutOfStockProductIds(String merchantId) async {
    final data = await _client
        .from('product_inventory')
        .select('product_id')
        .eq('merchant_id', merchantId)
        .eq('is_in_stock', false);
    return (data as List).map((r) => r['product_id'] as String).toList();
  }

  Future<List<String>> getLowStockProductIds(String merchantId) async {
    final data = await _client
        .from('product_inventory')
        .select('product_id, stock_quantity, low_stock_threshold')
        .eq('merchant_id', merchantId);
    return (data as List)
        .where(
          (r) =>
              (r['stock_quantity'] as int) <=
                  (r['low_stock_threshold'] as int) &&
              (r['stock_quantity'] as int) > 0,
        )
        .map((r) => r['product_id'] as String)
        .toList();
  }

  Stream<ProductInventory> watchInventory(String productId) {
    return _client
        .from('product_inventory')
        .stream(primaryKey: ['id'])
        .eq('product_id', productId)
        .limit(1)
        .map((rows) => _fromRow(rows.first));
  }
}
