import 'package:delwaqty/features/customer/delivery/data/datasources/remote/supabase_delivery_data_source.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/delivery_order.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/merchant_profile.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/driver_capability.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/delivery_pricing.dart';
import 'package:delwaqty/features/customer/delivery/domain/repositories/delivery_repository.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/driver_stats.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/ride_offer.dart';

class DeliveryRepositoryImpl implements DeliveryRepository {
  DeliveryRepositoryImpl(this._dataSource);

  final SupabaseDeliveryDataSource _dataSource;

  @override
  Future<String> dispatchDelivery(String rideId,
          {double radiusKm = 10, int limit = 5}) =>
      _dataSource.dispatchDelivery(rideId, radiusKm: radiusKm, limit: limit);

  @override
  Future<String> acceptDeliveryRequest(String rideId, String driverId) =>
      _dataSource.acceptDeliveryRequest(rideId, driverId);

  @override
  Future<void> rejectDeliveryRequest(String rideId, String driverId) =>
      _dataSource.rejectDeliveryRequest(rideId, driverId);

  @override
  Stream<List<RideOffer>> watchDeliveryOffers(String driverId) =>
      _dataSource.watchDeliveryOffers(driverId);

  @override
  Stream<DeliveryOrder?> watchActiveDelivery(String driverId) =>
      _dataSource.watchActiveDelivery(driverId);

  @override
  Future<DeliveryOrder?> getActiveDelivery(String driverId) =>
      _dataSource.getActiveDelivery(driverId);

  @override
  Future<DeliveryOrder?> getDeliveryOrderById(String id) =>
      _dataSource.getDeliveryOrderById(id);

  @override
  Future<void> driverArrivedAtPickup(String rideId, String driverId) =>
      _dataSource.driverArrivedAtPickup(rideId, driverId);

  @override
  Future<void> startDelivery(
          String rideId, String driverId, String otp) =>
      _dataSource.startDelivery(rideId, driverId, otp);

  @override
  Future<double> completeDelivery(String rideId, String driverId,
          {String? proofUrl, double? finalDistanceKm}) =>
      _dataSource.completeDelivery(rideId, driverId,
          proofUrl: proofUrl, finalDistanceKm: finalDistanceKm);

  @override
  Future<void> cancelDelivery(String rideId, {String? reason}) =>
      _dataSource.cancelDelivery(rideId, reason: reason);


  @override
  Future<DeliveryPricingModel> getDeliveryPricing(String serviceType) =>
      _dataSource.getDeliveryPricing(serviceType);

  @override
  Future<Map<String, dynamic>> estimateDeliveryFee(
    String serviceType,
    double distanceKm, {
    double weightKg = 1.0,
    String priority = 'standard',
  }) =>
      _dataSource.estimateDeliveryFee(serviceType, distanceKm,
          weightKg: weightKg, priority: priority);

  @override
  Future<DriverCapability> getDriverCapabilities(String driverId) =>
      _dataSource.getDriverCapabilities(driverId);

  @override
  Future<void> updateDriverCapabilities(
    String driverId, {
    required List<String> serviceTypes,
    bool acceptsDeliveries = true,
    double maxDistance = 15,
    double maxWeight = 20,
  }) =>
      _dataSource.updateDriverCapabilities(driverId,
          serviceTypes: serviceTypes,
          acceptsDeliveries: acceptsDeliveries,
          maxDistance: maxDistance,
          maxWeight: maxWeight);

  @override
  Future<MerchantProfile?> getMerchantProfile(String merchantId) =>
      _dataSource.getMerchantProfile(merchantId);

  @override
  Future<void> upsertMerchantProfile({
    required String merchantId,
    required String userId,
    List<String>? serviceTypes,
    int? averagePrepTime,
    double? maxRadius,
  }) =>
      _dataSource.upsertMerchantProfile(
        merchantId: merchantId,
        userId: userId,
        serviceTypes: serviceTypes,
        averagePrepTime: averagePrepTime,
        maxRadius: maxRadius,
      );

  @override
  Future<DriverStats> getDashboardStats(String driverId) =>
      _dataSource.getDashboardStats(driverId);

  @override
  Future<List<DriverEarning>> getEarnings(String driverId,
          {int limit = 30}) =>
      _dataSource.getEarnings(driverId, limit: limit);

  @override
  Future<void> rateDelivery(String rideId, String driverId, int stars,
          {String? comment}) =>
      _dataSource.rateDelivery(rideId, driverId, stars, comment: comment);
}
