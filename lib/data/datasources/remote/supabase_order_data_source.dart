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
      paymentStatus: _parsePaymentStatus(row['payment_status'] as String? ?? 'unpaid'),
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
      cancellationReason: row['cancellation_reason'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : null,
    );
  }

  OrderStatus _parseStatus(String status) {
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

      var query = _client.from(_ordersTable).select().eq('user_id', userId);

      if (status != null) {
        query = query.eq('status', status.name);
      }

      final data = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final orders = <Order>[];
      for (final row in data as List) {
        final rowMap = row as Map<String, dynamic>;
        final itemsData = await _client
            .from(_itemsTable)
            .select()
            .eq('order_id', rowMap['id']);
        final items = (itemsData as List)
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
      final data = await _client
          .from(_ordersTable)
          .select()
          .eq('id', id)
          .maybeSingle();
      if (data == null) return null;

      final itemsData = await _client
          .from(_itemsTable)
          .select()
          .eq('order_id', id);
      final items = (itemsData as List)
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
    String? paymentMethod,
    String? specialInstructions,
  }) async {
    try {
      final userId = _userId;
      if (userId == null) throw Exception('User not authenticated');

      final orderData = await _client
          .from(_ordersTable)
          .insert({
            'user_id': userId,
            'merchant_id': merchantId,
            'merchant_name': merchantName,
            'status': OrderStatus.pending.name,
            'total_amount': total,
            'delivery_fee': deliveryFee,
            'tax': 0,
            'discount': discount,
            'delivery_address': deliveryAddress,
            'payment_method': paymentMethod,
            'special_instructions': specialInstructions,
          })
          .select()
          .single();

      final orderId = orderData['id'] as String;

      for (final item in items) {
        await _client.from(_itemsTable).insert({
          'order_id': orderId,
          'product_id': item.productId,
          'product_name': item.productName,
          'variant_name': item.variantName,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'total_price': item.unitPrice * item.quantity,
        });
      }

      _logger.i('Created order: $orderId');
      return _fromRow(
        orderData,
        items
            .map(
              (ci) => {
                'product_id': ci.productId,
                'product_name': ci.productName,
                'variant_name': ci.variantName,
                'quantity': ci.quantity,
                'unit_price': ci.unitPrice,
                'total_price': ci.unitPrice * ci.quantity,
              },
            )
            .toList(),
      );
    } catch (e, stack) {
      _logger.e('Failed to create order', e, stack);
      rethrow;
    }
  }

  Future<Order> cancelOrder({required String orderId, String? reason}) async {
    try {
      final data = await _client
          .from(_ordersTable)
          .update({
            'status': OrderStatus.cancelled.name,
            'cancellation_reason': reason,
            'cancelled_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId)
          .select()
          .single();

      final itemsData = await _client
          .from(_itemsTable)
          .select()
          .eq('order_id', orderId);
      final items = (itemsData as List)
          .map((i) => i as Map<String, dynamic>)
          .toList();

      _logger.i('Cancelled order: $orderId');
      return _fromRow(data, items);
    } catch (e, stack) {
      _logger.e('Failed to cancel order: $orderId', e, stack);
      rethrow;
    }
  }
}
