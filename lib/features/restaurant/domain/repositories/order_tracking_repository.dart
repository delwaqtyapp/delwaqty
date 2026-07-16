import 'package:delwaqty/features/restaurant/domain/entities/order_tracking.dart';

abstract interface class OrderTrackingRepository {
  Future<List<OrderTracking>> getTracking(String orderId);
  Future<OrderTracking> addTracking(OrderTracking tracking);
  Future<OrderTracking?> getLatestTracking(String orderId);
}
