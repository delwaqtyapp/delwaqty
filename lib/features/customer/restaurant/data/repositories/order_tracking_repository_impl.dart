import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/features/customer/restaurant/data/datasources/remote/supabase_order_tracking_data_source.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/order_tracking.dart';
import 'package:delwaqty/features/customer/restaurant/domain/repositories/order_tracking_repository.dart';

class OrderTrackingRepositoryImpl implements OrderTrackingRepository {
  OrderTrackingRepositoryImpl(this._dataSource);
  final SupabaseOrderTrackingDataSource _dataSource;

  @override
  Future<List<OrderTracking>> getTracking(String orderId) async {
    try {
      return await _dataSource.getTracking(orderId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<OrderTracking> addTracking(OrderTracking tracking) async {
    try {
      return await _dataSource.addTracking(tracking);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<OrderTracking?> getLatestTracking(String orderId) async {
    try {
      return await _dataSource.getLatestTracking(orderId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
