import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/features/provider/merchant/data/datasources/remote/supabase_merchant_dashboard_data_source.dart';
import 'package:delwaqty/features/provider/merchant/domain/entities/merchant_order.dart';
import 'package:delwaqty/features/provider/merchant/domain/entities/merchant_stats.dart';
import 'package:delwaqty/features/provider/merchant/domain/repositories/merchant_dashboard_repository.dart';

class MerchantDashboardRepositoryImpl implements MerchantDashboardRepository {
  MerchantDashboardRepositoryImpl(this._dataSource);
  final SupabaseMerchantDashboardDataSource _dataSource;

  @override
  Future<MerchantStats> getMerchantStats(String merchantId) async {
    try {
      return await _dataSource.getMerchantStats(merchantId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<MerchantOrder>> getMerchantOrders(
    String merchantId, {
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      return await _dataSource.getMerchantOrders(
        merchantId,
        status: status,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await _dataSource.updateOrderStatus(orderId, status);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getMerchantProducts(
    String merchantId,
  ) async {
    try {
      return await _dataSource.getMerchantProducts(merchantId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> createProduct(
    String merchantId,
    Map<String, dynamic> product,
  ) async {
    try {
      await _dataSource.createProduct(merchantId, product);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> updateProduct(
    String productId,
    Map<String, dynamic> product,
  ) async {
    try {
      await _dataSource.updateProduct(productId, product);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> deleteProduct(String productId) async {
    try {
      await _dataSource.deleteProduct(productId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
