import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/services/logger/app_logger.dart';
import 'package:delwaqty/features/merchant/domain/entities/merchant_order.dart';
import 'package:delwaqty/features/merchant/domain/entities/merchant_stats.dart';

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
    final itemsData = row['items'] as List<dynamic>? ?? [];
    final items = itemsData.map((item) {
      final data = item as Map<String, dynamic>;
      final modifiersData = data['modifiers'] as List<dynamic>? ?? [];
      return MerchantOrderItem(
        productId: data['product_id'] as String,
        productName: data['product_name'] as String,
        quantity: data['quantity'] as int,
        unitPrice: (data['unit_price'] as num).toDouble(),
        modifiers: List<String>.from(modifiersData),
      );
    }).toList();

    return MerchantOrder(
      id: row['id'] as String,
      customerId: row['customer_id'] as String,
      customerName: row['customer_name'] as String?,
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

      final ordersData = await _client
          .from('orders')
          .select('id, status, total_amount, created_at')
          .eq('merchant_id', merchantId);

      final allOrders = ordersData as List<dynamic>;
      final todayOrders = allOrders.where((o) {
        final createdAt = DateTime.parse(o['created_at'] as String);
        return createdAt.isAfter(todayStart);
      }).toList();

      final todayRevenue = todayOrders.fold<double>(
        0,
        (sum, o) => sum + (o['total_amount'] as num).toDouble(),
      );

      final pendingOrders =
          allOrders.where((o) => o['status'] == 'pending').length;

      final productsData = await _client
          .from('products')
          .select('id')
          .eq('merchant_id', merchantId);

      final totalProducts = (productsData as List<dynamic>).length;

      final reviewsData = await _client
          .from('reviews')
          .select('rating')
          .eq('merchant_id', merchantId);

      final reviews = reviewsData as List<dynamic>;
      final totalReviews = reviews.length;
      final averageRating = totalReviews > 0
          ? reviews.fold<double>(
              0,
              (sum, r) => sum + (r['rating'] as num).toDouble(),
            ) /
              totalReviews
          : 0.0;

      return MerchantStats(
        todayOrders: todayOrders.length,
        todayRevenue: todayRevenue,
        pendingOrders: pendingOrders,
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
          .select('*, users(name)')
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
        orderMap['customer_name'] = usersData?['name'] as String?;
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
