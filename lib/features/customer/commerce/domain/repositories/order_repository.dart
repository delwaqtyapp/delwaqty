import 'package:delwaqty/features/customer/commerce/domain/entities/cart.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/order.dart';

abstract interface class OrderRepository {
  Future<List<Order>> getOrders({
    OrderStatus? status,
    int limit = 20,
    int offset = 0,
  });
  Future<Order?> getOrderById(String id);
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
  });
  Future<Order> cancelOrder({required String orderId, String? reason});
}
