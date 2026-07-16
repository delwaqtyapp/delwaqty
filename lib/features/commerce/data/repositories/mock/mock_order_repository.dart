import 'package:delwaqty/features/commerce/domain/entities/cart.dart';
import 'package:delwaqty/features/commerce/domain/entities/order.dart';
import 'package:delwaqty/features/commerce/domain/repositories/order_repository.dart';

class MockOrderRepository implements OrderRepository {
  final List<Order> _orders = [];

  @override
  Future<List<Order>> getOrders({
    OrderStatus? status,
    int limit = 20,
    int offset = 0,
  }) async {
    var results = List<Order>.from(_orders);
    if (status != null) {
      results = results.where((o) => o.status == status).toList();
    }
    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results.skip(offset).take(limit).toList();
  }

  @override
  Future<Order?> getOrderById(String id) async {
    try {
      return _orders.firstWhere((o) => o.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
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
    final order = Order(
      id: 'order_${DateTime.now().millisecondsSinceEpoch}',
      merchantId: merchantId,
      merchantName: merchantName,
      items: items
          .map((ci) => OrderItem(
                productId: ci.productId,
                productName: ci.productName,
                variantName: ci.variantName,
                quantity: ci.quantity,
                unitPrice: ci.unitPrice,
                totalPrice: ci.unitPrice * ci.quantity,
              ))
          .toList(),
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      discount: discount,
      total: total,
      status: OrderStatus.pending,
      deliveryAddress: deliveryAddress,
      paymentMethod: paymentMethod,
      specialInstructions: specialInstructions,
      createdAt: DateTime.now(),
    );
    _orders.add(order);
    return order;
  }

  @override
  Future<Order> cancelOrder({
    required String orderId,
    String? reason,
  }) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index < 0) throw StateError('Order not found');
    _orders[index] = _orders[index].copyWith(
      status: OrderStatus.cancelled,
      cancellationReason: reason,
      cancelledAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return _orders[index];
  }
}
