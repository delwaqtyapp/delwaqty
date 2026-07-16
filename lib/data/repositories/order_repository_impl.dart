import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/data/datasources/remote/supabase_order_data_source.dart';
import 'package:delwaqty/features/commerce/domain/entities/cart.dart';
import 'package:delwaqty/features/commerce/domain/entities/order.dart';
import 'package:delwaqty/features/commerce/domain/repositories/order_repository.dart';

class OrderRepositoryImpl implements OrderRepository {
  OrderRepositoryImpl(this._dataSource);

  final SupabaseOrderDataSource _dataSource;

  @override
  Future<List<Order>> getOrders({
    OrderStatus? status,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      return await _dataSource.getOrders(
        status: status,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Order?> getOrderById(String id) async {
    try {
      return await _dataSource.getOrderById(id);
    } catch (e) {
      throw ServerException(message: e.toString());
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
    try {
      return await _dataSource.createOrder(
        merchantId: merchantId,
        merchantName: merchantName,
        items: items,
        subtotal: subtotal,
        deliveryFee: deliveryFee,
        discount: discount,
        total: total,
        deliveryAddress: deliveryAddress,
        paymentMethod: paymentMethod,
        specialInstructions: specialInstructions,
      );
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Order> cancelOrder({
    required String orderId,
    String? reason,
  }) async {
    try {
      return await _dataSource.cancelOrder(orderId: orderId, reason: reason);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
