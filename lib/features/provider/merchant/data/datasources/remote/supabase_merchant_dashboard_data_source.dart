import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/services/logger/app_logger.dart';
import 'package:delwaqty/features/provider/merchant/domain/entities/merchant_order.dart';
import 'package:delwaqty/features/provider/merchant/domain/entities/merchant_stats.dart';

final supabaseMerchantDashboardDataSourceProvider =
    Provider<SupabaseMerchantDashboardDataSource>((ref) {
      return SupabaseMerchantDashboardDataSource(
        ref.watch(supabaseClientProvider),
        ref.watch(loggerProvider),
      );
    });

class SupabaseMerchantDashboardDataSource {
  SupabaseMerchantDashboardDataSource(this._client, this._logger);
  final SupabaseClient _client;
  final AppLogger _logger;

  MerchantOrder _orderFromRow(Map<String, dynamic> row) {
    final itemsData = row['order_items'] as List<dynamic>? ?? [];
    final items = itemsData.map((item) {
      final data = item as Map<String, dynamic>;
      final modifiersData = data['modifiers'];
      final modifierNames = modifiersData is List
          ? modifiersData.map((e) => e.toString()).toList()
          : <String>[];
      final product = data['products'];
      final productName = (product is Map && product['name'] != null)
          ? product['name'] as String
          : (data['product_name'] as String? ?? '');
      return MerchantOrderItem(
        productId: data['product_id'] as String? ?? '',
        productName: productName,
        quantity: (data['quantity'] as num?)?.toInt() ?? 1,
        unitPrice: (data['unit_price'] as num?)?.toDouble() ?? 0,
        modifiers: modifierNames,
      );
    }).toList();

    final user = row['users'];

    return MerchantOrder(
      id: row['id'] as String,
      customerId: row['user_id'] as String? ?? '',
      customerName: (user is Map && user['full_name'] != null)
          ? user['full_name'] as String
          : null,
      items: items,
      totalAmount: (row['total_amount'] as num).toDouble(),
      status: row['status'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      deliveryAddress: row['delivery_address'] as String?,
      notes: row['notes'] as String?,
    );
  }

  Future<MerchantStats> getMerchantStats(String merchantId) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      // Every one of these used to download the merchant's WHOLE orders /
      // products / reviews history and aggregate it in Dart, which fails on
      // real data volumes. PostgREST's count() returns the exact row count
      // in a header without transferring a single row.
      final todayRes = await _client
          .from('orders')
          .count()
          .eq('merchant_id', merchantId)
          .gte('created_at', todayStart.toIso8601String());

      final pendingRes = await _client
          .from('orders')
          .count()
          .eq('merchant_id', merchantId)
          .eq('status', 'pending');

      final revenueRes = await _client
          .from('orders')
          .select('total_amount')
          .eq('merchant_id', merchantId)
          .gte('created_at', todayStart.toIso8601String());
      final todayRevenue = (revenueRes as List<dynamic>).fold<double>(
        0,
        (sum, o) => sum + ((o['total_amount'] as num?)?.toDouble() ?? 0),
      );

      final totalProducts = await _client
          .from('products')
          .count()
          .eq('merchant_id', merchantId);

      final totalReviews = await _client
          .from('reviews')
          .count()
          .eq('merchant_id', merchantId);

      final ratingRes = await _client
          .from('reviews')
          .select('rating')
          .eq('merchant_id', merchantId);
      final reviews = ratingRes as List<dynamic>;
      final averageRating = reviews.isEmpty
          ? 0.0
          : reviews.fold<double>(
                0,
                (sum, r) => sum + ((r['rating'] as num?)?.toDouble() ?? 0),
              ) /
              reviews.length;

      return MerchantStats(
        todayOrders: todayRes,
        todayRevenue: todayRevenue,
        pendingOrders: pendingRes,
        averageRating: averageRating,
        totalProducts: totalProducts,
        totalReviews: totalReviews,
      );
    } catch (e) {
      _logger.e('Failed to get merchant stats', e);
      rethrow;
    }
  }

  Future<List<MerchantOrder>> getMerchantOrders(
    String merchantId, {
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      var query = _client
          .from('orders')
          .select(
            'id, user_id, status, total_amount, created_at, delivery_address, notes, '
            'users(full_name), '
            'order_items(product_id, product_name, quantity, unit_price, modifiers, products(name))',
          )
          .eq('merchant_id', merchantId);

      if (status != null) {
        query = query.eq('status', status);
      }

      final data = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (data as List<dynamic>).map((row) {
        final map = row as Map<String, dynamic>;
        final usersData = map['users'] as Map<String, dynamic>?;
        final orderMap = Map<String, dynamic>.from(map);
        orderMap['customer_name'] = usersData?['full_name'] as String?;
        return _orderFromRow(orderMap);
      }).toList();
    } catch (e) {
      _logger.e('Failed to get merchant orders', e);
      rethrow;
    }
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await _client
          .from('orders')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);
    } catch (e) {
      _logger.e('Failed to update order status', e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getMerchantProducts(
    String merchantId,
  ) async {
    try {
      final data = await _client
          .from('products')
          .select()
          .eq('merchant_id', merchantId)
          .order('created_at', ascending: false);
      return (data as List<dynamic>)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
    } catch (e) {
      _logger.e('Failed to get merchant products', e);
      rethrow;
    }
  }

  Future<void> createProduct(
    String merchantId,
    Map<String, dynamic> product,
  ) async {
    try {
      await _client.from('products').insert({
        ...product,
        'merchant_id': merchantId,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _logger.e('Failed to create product', e);
      rethrow;
    }
  }

  Future<void> updateProduct(
    String productId,
    Map<String, dynamic> product,
  ) async {
    try {
      await _client
          .from('products')
          .update({
            ...product,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', productId);
    } catch (e) {
      _logger.e('Failed to update product', e);
      rethrow;
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      await _client.from('products').delete().eq('id', productId);
    } catch (e) {
      _logger.e('Failed to delete product', e);
      rethrow;
    }
  }
}
