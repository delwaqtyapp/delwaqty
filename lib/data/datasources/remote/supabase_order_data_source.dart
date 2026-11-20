import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/services/logger/app_logger.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/order.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/cart.dart';

final supabaseOrderDataSourceProvider = Provider<SupabaseOrderDataSource>((
  ref,
) {
  return SupabaseOrderDataSource(
    ref.watch(supabaseClientProvider),
    ref.watch(loggerProvider),
  );
});

class SupabaseOrderDataSource {
  SupabaseOrderDataSource(this._client, this._logger);

  final SupabaseClient _client;
  final AppLogger _logger;

  static const String _ordersTable = 'orders';
  static const String _itemsTable = 'order_items';

  String? get _userId => _client.auth.currentUser?.id;

  Order _fromRow(
    Map<String, dynamic> row, [
    List<Map<String, dynamic>>? items,
  ]) {
    final orderItems =
        items
            ?.map(
              (i) => OrderItem(
                productId: i['product_id'] as String,
                productName: i['product_name'] as String? ?? '',
                variantName: i['variant_name'] as String?,
                quantity: i['quantity'] as int,
                unitPrice: (i['unit_price'] as num).toDouble(),
                totalPrice: (i['total_price'] as num).toDouble(),
              ),
            )
            .toList() ??
        [];

    return Order(
      id: row['id'] as String,
      merchantId: row['merchant_id'] as String,
      merchantName: row['merchant_name'] as String? ?? '',
      items: orderItems,
      subtotal:
          (row['total_amount'] as num).toDouble() -
          (row['delivery_fee'] as num? ?? 0).toDouble() -
          (row['tax'] as num? ?? 0).toDouble() +
          (row['discount'] as num? ?? 0).toDouble(),
      deliveryFee: (row['delivery_fee'] as num? ?? 0).toDouble(),
      discount: (row['discount'] as num? ?? 0).toDouble(),
      total: (row['total_amount'] as num).toDouble(),
      status: _parseStatus(row['status'] as String),
      deliveryAddress: row['delivery_address'] as String?,
      paymentMethod: row['payment_method'] as String?,
      paymentStatus: _parsePaymentStatus(
        row['payment_status'] as String? ?? 'unpaid',
      ),
      paymentId: row['payment_id'] as String?,
      transactionId: row['transaction_id'] as String?,
      specialInstructions:
          row['special_instructions'] as String? ?? row['notes'] as String?,
      confirmedAt: row['confirmed_at'] != null
          ? DateTime.parse(row['confirmed_at'] as String)
          : null,
      preparingAt: row['preparing_at'] != null
          ? DateTime.parse(row['preparing_at'] as String)
          : null,
      readyAt: row['ready_at'] != null
          ? DateTime.parse(row['ready_at'] as String)
          : null,
      deliveredAt: row['delivered_at'] != null
          ? DateTime.parse(row['delivered_at'] as String)
          : null,
      cancelledAt: row['cancelled_at'] != null
          ? DateTime.parse(row['cancelled_at'] as String)
          : null,
      cancellationReason: row['cancelled_reason'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : null,
    );
  }

  OrderStatus _parseStatus(String status) {
    // The database CHECK on orders.status allows:
    //   pending, confirmed, preparing, ready, delivering, delivered, cancelled
    // The Dart enum also has pickedUp ('picked_up') and inTransit
    // ('in_transit'), which the DB never stores. Map the DB vocabulary
    // onto the enum so a shipped order is not displayed as "pending".
    const dbToEnum = <String, OrderStatus>{
      'pending': OrderStatus.pending,
      'confirmed': OrderStatus.confirmed,
      'preparing': OrderStatus.preparing,
      'ready': OrderStatus.ready,
      'delivering': OrderStatus.inTransit,
      'picked_up': OrderStatus.pickedUp,
      'in_transit': OrderStatus.inTransit,
      'delivered': OrderStatus.delivered,
      'cancelled': OrderStatus.cancelled,
    };
    final mapped = dbToEnum[status];
    if (mapped != null) return mapped;
    return OrderStatus.values.firstWhere(
      (s) => s.name == status,
      orElse: () => OrderStatus.pending,
    );
  }

  PaymentStatus _parsePaymentStatus(String status) {
    return PaymentStatus.values.firstWhere(
      (s) => s.name == status,
      orElse: () => PaymentStatus.unpaid,
    );
  }

  Future<List<Order>> getOrders({
    OrderStatus? status,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final userId = _userId;
      if (userId == null) return [];

      // One round trip: the item lines are embedded through the
      // order_items foreign key instead of one query per order (N+1).
      var query = _client
          .from(_ordersTable)
          .select('*, order_items(*)')
          .eq('user_id', userId);

      if (status != null) {
        query = query.eq('status', status.name);
      }

      final data = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final orders = <Order>[];
      for (final row in data as List) {
        final rowMap = row as Map<String, dynamic>;
        final items = (rowMap['order_items'] as List<dynamic>? ?? const [])
            .map((i) => i as Map<String, dynamic>)
            .toList();
        orders.add(_fromRow(rowMap, items));
      }
      return orders;
    } catch (e, stack) {
      _logger.e('Failed to get orders', e, stack);
      rethrow;
    }
  }

  Future<Order?> getOrderById(String id) async {
    try {
      final userId = _userId;
      if (userId == null) return null;

      // Scope by owner in the query as defence in depth: RLS already
      // filters, but an IDOR must not depend on a single control.
      final data = await _client
          .from(_ordersTable)
          .select('*, order_items(*)')
          .eq('id', id)
          .eq('user_id', userId)
          .maybeSingle();
      if (data == null) return null;

      final items = (data['order_items'] as List<dynamic>? ?? const [])
          .map((i) => i as Map<String, dynamic>)
          .toList();
      return _fromRow(data, items);
    } catch (e, stack) {
      _logger.e('Failed to get order: $id', e, stack);
      rethrow;
    }
  }

  Future<Order> createOrder({
    required String merchantId,
    required String merchantName,
    required List<CartItem> items,
    required double subtotal,
    required double deliveryFee,
    required double discount,
    required double total,
    String? deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? paymentMethod,
    String? specialInstructions,
    String? couponCode,
    String? idempotencyKey,
  }) async {
    try {
      if (_userId == null) throw Exception('User not authenticated');

      // Server-side checkout (migration 157): prices, fee and coupon discount
      // are computed from the database; the client only sends item ids/qtys.
      final res = await _client.rpc(
        'create_order',
        params: {
          'p_merchant_id': merchantId,
          'p_items': items
              .map(
                (ci) => {'product_id': ci.productId, 'quantity': ci.quantity},
              )
              .toList(),
          'p_delivery_address': deliveryAddress,
          'p_delivery_latitude': deliveryLatitude,
          'p_delivery_longitude': deliveryLongitude,
          'p_payment_method': paymentMethod ?? 'cash',
          'p_coupon_code': couponCode,
          'p_special_instructions': specialInstructions,
          'p_idempotency_key': idempotencyKey,
        },
      );
      final map = Map<String, dynamic>.from(res as Map);
      if (map['ok'] != true) {
        throw Exception('create_order failed: ${map['code'] ?? map}');
      }
      final orderId = map['order_id'] as String;
      return getOrderById(orderId).then((order) {
        if (order == null) throw Exception('order $orderId not readable');
        return order;
      });
    } catch (e, stack) {
      _logger.e('Failed to create order', e, stack);
      rethrow;
    }
  }

  Future<Order> cancelOrder({required String orderId, String? reason}) async {
    try {
      // Guarded RPC path (direct updates are frozen by the 151 lockdown).
      final res = await _client.rpc(
        'cancel_order',
        params: {'p_order_id': orderId, 'p_reason': reason},
      );
      final map = Map<String, dynamic>.from(res as Map);
      if (map['ok'] != true) {
        throw Exception('cancel_order refused: ${map['code'] ?? map}');
      }
      final order = await getOrderById(orderId);
      if (order == null) throw Exception('order $orderId not readable');
      return order;
    } catch (e, stack) {
      _logger.e('Failed to cancel order: $orderId', e, stack);
      rethrow;
    }
  }
}
