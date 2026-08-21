import 'package:delwaqty/features/customer/merchant/domain/entities/merchant_order.dart';
import 'package:delwaqty/features/customer/merchant/domain/entities/merchant_stats.dart';

abstract interface class MerchantDashboardRepository {
  Future<MerchantStats> getMerchantStats(String merchantId);
  Future<List<MerchantOrder>> getMerchantOrders(
    String merchantId, {
    String? status,
    int limit = 20,
    int offset = 0,
  });
  Future<void> updateOrderStatus(String orderId, String status);
  Future<List<Map<String, dynamic>>> getMerchantProducts(String merchantId);
  Future<void> createProduct(
    String merchantId,
    Map<String, dynamic> product,
  );
  Future<void> updateProduct(
    String productId,
    Map<String, dynamic> product,
  );
  Future<void> deleteProduct(String productId);
}
