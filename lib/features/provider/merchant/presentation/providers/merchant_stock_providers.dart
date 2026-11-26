import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';

/// Inventory for one merchant.
///
/// The customer app already owned a complete `product_inventory` data
/// source (get / upsert / adjust / reserve / low-stock) but the merchant
/// panel never consumed it, so a merchant could not restock a product or
/// see what was running low — even though the table, its RLS and the
/// realtime publication all existed.
class MerchantStockItem {
  const MerchantStockItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.isAvailable,
    required this.stockQuantity,
    required this.reservedQuantity,
    required this.lowStockThreshold,
    required this.isInStock,
    this.imageUrl,
  });

  final String productId;
  final String productName;
  final double price;
  final bool isAvailable;
  final int stockQuantity;
  final int reservedQuantity;
  final int lowStockThreshold;
  final bool isInStock;
  final String? imageUrl;

  /// Available to sell right now.
  int get availableQuantity =>
      (stockQuantity - reservedQuantity).clamp(0, 1 << 31);

  /// True when the merchant should be warned: at or below the threshold.
  bool get isLowStock => isInStock && stockQuantity <= lowStockThreshold;

  bool get isOutOfStock => !isInStock || stockQuantity <= 0;

  MerchantStockItem copyWith({
    int? stockQuantity,
    bool? isInStock,
    int? lowStockThreshold,
    int? reservedQuantity,
    bool? isAvailable,
  }) {
    return MerchantStockItem(
      productId: productId,
      productName: productName,
      price: price,
      isAvailable: isAvailable ?? this.isAvailable,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      reservedQuantity: reservedQuantity ?? this.reservedQuantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      isInStock: isInStock ?? this.isInStock,
      imageUrl: imageUrl,
    );
  }
}

final merchantStockProvider =
    FutureProvider.family<List<MerchantStockItem>, String>((
      ref,
      merchantId,
    ) async {
      if (merchantId.isEmpty) return const <MerchantStockItem>[];
      final client = ref.watch(supabaseClientProvider);

      // One round trip: the inventory row is embedded through the
      // product_inventory -> products foreign key instead of a query per item.
      var res = await client
          .from('product_inventory')
          .select(
            'product_id, stock_quantity, reserved_quantity, low_stock_threshold, '
            'is_in_stock',
          )
          .eq('merchant_id', merchantId)
          .order('stock_quantity', ascending: true);

      // 449 app switch: the owner reads their own full product rows through
      // the definer RPC (base-table SELECT is 450 territory); the inventory
      // rows join client-side by product_id instead of a PostgREST embed.
      final productsList = await client.rpc(
        'get_my_products',
        params: {'p_merchant_id': merchantId},
      ) as List;
      final productsById = <String, Map<String, dynamic>>{
        for (final raw in productsList)
          (raw as Map<String, dynamic>)['id'] as String:
              Map<String, dynamic>.from(raw),
      };

      if ((res as List).isEmpty) {
        if (productsList.isNotEmpty) {
          final initialRows = productsList.map((raw) {
            final p = raw as Map<String, dynamic>;
            final stock = (p['stock_quantity'] as num?)?.toInt() ?? 50;
            final available = (p['is_available'] as bool?) ?? true;
            return <String, dynamic>{
              'merchant_id': merchantId,
              'product_id': p['id'] as String,
              'stock_quantity': stock,
              'reserved_quantity': 0,
              'low_stock_threshold': 5,
              'is_in_stock': available && stock > 0,
            };
          }).toList();
          try {
            await client
                .from('product_inventory')
                .upsert(initialRows, onConflict: 'product_id');
            res = await client
                .from('product_inventory')
                .select(
                  'product_id, stock_quantity, reserved_quantity, low_stock_threshold, '
                  'is_in_stock',
                )
                .eq('merchant_id', merchantId)
                .order('stock_quantity', ascending: true);
          } catch (_) {
            return productsList.map((raw) {
              final p = raw as Map<String, dynamic>;
              final stock = (p['stock_quantity'] as num?)?.toInt() ?? 50;
              final available = (p['is_available'] as bool?) ?? true;
              return MerchantStockItem(
                productId: p['id'] as String,
                productName: (p['name'] as String?) ?? '',
                price: (p['price'] as num?)?.toDouble() ?? 0,
                isAvailable: available,
                imageUrl: p['image_url'] as String?,
                stockQuantity: stock,
                reservedQuantity: 0,
                lowStockThreshold: 5,
                isInStock: available && stock > 0,
              );
            }).toList();
          }
        }
      }

      return (res as List).map((row) {
        final map = row as Map<String, dynamic>;
        final p = productsById[map['product_id']] ?? const <String, dynamic>{};
        final stock = (map['stock_quantity'] as num?)?.toInt() ?? 0;
        return MerchantStockItem(
          productId: map['product_id'] as String,
          productName: (p['name'] as String?) ?? '',
          price: (p['price'] as num?)?.toDouble() ?? 0,
          isAvailable: (p['is_available'] as bool?) ?? true,
          imageUrl: p['image_url'] as String?,
          stockQuantity: stock,
          reservedQuantity: (map['reserved_quantity'] as num?)?.toInt() ?? 0,
          lowStockThreshold:
              (map['low_stock_threshold'] as num?)?.toInt() ?? 10,
          isInStock: (map['is_in_stock'] as bool?) ?? (stock > 0),
        );
      }).toList();
    });

/// Writes the stock level for one product.
///
/// `product_inventory` is the authoritative ledger; `products.stock_quantity`
/// and `products.is_available` are denormalised for the customer menu, so
/// both are written together in one upsert.
class StockNotifier {
  StockNotifier(this._ref);

  final Ref _ref;

  Future<void> setStock({
    required String merchantId,
    required String productId,
    required int quantity,
    required int lowStockThreshold,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    final clamped = quantity.clamp(0, 1 << 31);

    final existingItems = _ref
        .read(merchantStockProvider(merchantId))
        .asData
        ?.value;
    int? existingReserved;
    if (existingItems != null) {
      for (final item in existingItems) {
        if (item.productId == productId) {
          existingReserved = item.reservedQuantity;
          break;
        }
      }
    }

    await client.from('product_inventory').upsert({
      'merchant_id': merchantId,
      'product_id': productId,
      'stock_quantity': clamped,
      'reserved_quantity': ?existingReserved,
      'low_stock_threshold': lowStockThreshold,
      'is_in_stock': clamped > 0,
    }, onConflict: 'product_id');

    // Keep the denormalised product fields in sync so the customer menu
    // hides out-of-stock items immediately.
    await client
        .from('products')
        .update({'stock_quantity': clamped, 'is_available': clamped > 0})
        .eq('id', productId);

    _ref.invalidate(merchantStockProvider(merchantId));
  }

  Future<void> adjustBy({
    required String merchantId,
    required String productId,
    required int delta,
    required int currentQuantity,
    required int lowStockThreshold,
  }) => setStock(
    merchantId: merchantId,
    productId: productId,
    quantity: currentQuantity + delta,
    lowStockThreshold: lowStockThreshold,
  );
}

final stockNotifierProvider = Provider<StockNotifier>(StockNotifier.new);
