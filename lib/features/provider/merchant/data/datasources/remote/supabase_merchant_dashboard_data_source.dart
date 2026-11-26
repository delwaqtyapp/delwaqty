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
      final productName = data['product_name'] as String? ?? '';
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
      customerPhone: (user is Map && user['phone'] != null)
          ? user['phone'] as String
          : (row['customer_phone'] as String?),
      driverId: row['driver_id'] as String?,
      hasLinkedDelivery: row['has_linked_delivery'] == true,
      items: items,
      totalAmount: (row['total_amount'] as num).toDouble(),
      status: row['status'] as String,
      dispatchStatus: row['dispatch_status'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      deliveryAddress: row['delivery_address'] as String?,
      notes: row['notes'] as String?,
    );
  }

  Future<MerchantStats> getMerchantStats(String merchantId) async {
    if (merchantId.isEmpty) {
      return const MerchantStats();
    }
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
          // Today's Orders counts every non-cancelled order placed today,
          // matching the revenue aggregate below (batch 14 item C).
          .neq('status', 'cancelled')
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
          .neq('status', 'cancelled')
          .gte('created_at', todayStart.toIso8601String());
      final todayRevenue = (revenueRes as List<dynamic>).fold<double>(
        0,
        (sum, o) => sum + ((o['total_amount'] as num?)?.toDouble() ?? 0),
      );

      // 449/451 app switch: exact count through the definer RPC
      // (base-table SELECT is 450 territory; a rows.length client count is
      // capped by PostgREST max_rows and downloads private rows).
      final totalProducts = await _client.rpc(
        'get_my_products_count',
        params: {'p_merchant_id': merchantId},
      ) as int;

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
    if (merchantId.isEmpty) {
      return const [];
    }
    try {
      var query = _client
          .from('orders')
          // 449/451 app switch: no products() embed (products base-table
          // SELECT is 450 territory); item names come from the denormalized
          // order_items.product_name snapshot, which is the correct source
          // for order history anyway.
          .select(
            'id, user_id, driver_id, status, dispatch_status, total_amount, created_at, delivery_address, notes, '
            'order_items(product_id, product_name, quantity, unit_price, modifiers)',
          )
          .eq('merchant_id', merchantId);

      if (status != null) {
        query = query.eq('status', status);
      }

      final data = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      // Customer PII comes through the scoped RPC (migration 159): the users
      // table is self+admin only, so an embed always returned null.
      final contactRows = await _client.rpc(
        'merchant_order_contacts',
        params: {'p_merchant_id': merchantId},
      );
      final contacts = <String, Map<String, dynamic>>{
        for (final c in (contactRows as List<dynamic>))
          (c as Map<String, dynamic>)['order_id'] as String:
              Map<String, dynamic>.from(c),
      };

      return Future.wait(
        (data as List<dynamic>).map((row) async {
          final map = row as Map<String, dynamic>;
          final contact = contacts[map['id'] as String];
          final orderMap = Map<String, dynamic>.from(map);
          orderMap['customer_name'] = contact?['full_name'] as String?;
          orderMap['customer_phone'] = contact?['phone'] as String?;
          orderMap['has_linked_delivery'] =
              await _client.rpc(
                'order_has_linked_delivery',
                params: {'p_order_id': map['id']},
              ) ==
              true;
          return _orderFromRow(orderMap);
        }),
      );
    } catch (e) {
      _logger.e('Failed to get merchant orders', e);
      rethrow;
    }
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      // Delivery completion must go through the RPC: it records the
      // merchant commission and is the only path the orders guard
      // trigger accepts for the 'delivered' transition.
      if (status == 'delivered') {
        final res = await _client.rpc(
          'merchant_complete_order',
          params: {'p_order_id': orderId},
        );
        final ok = res is Map && res['ok'] == true;
        if (!ok) {
          final reason = res is Map ? res['reason'] : null;
          throw StateError('merchant_complete_order failed: $reason');
        }
        return;
      }
      // Rejection must go through the RPC: it runs the shared cancellation
      // finalizer (stock, coupon, refund, cancelled_by='merchant') and the
      // orders guard refuses direct 'cancelled' writes from merchants.
      if (status == 'cancelled') {
        final res = await _client.rpc(
          'merchant_reject_order',
          params: {'p_order_id': orderId},
        );
        final ok = res is Map && res['ok'] == true;
        if (!ok) {
          final code = res is Map ? res['code'] : null;
          throw StateError('merchant_reject_order failed: $code');
        }
        return;
      }
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
    if (merchantId.isEmpty) {
      return const [];
    }
    try {
      // 449 app switch: the owner reads their own full rows through the
      // definer RPC (base-table SELECT is 450 territory; same shape and
      // created_at-desc ordering).
      final data = await _client.rpc(
        'get_my_products',
        params: {'p_merchant_id': merchantId},
      );
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
          .update({...product, 'updated_at': DateTime.now().toIso8601String()})
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
