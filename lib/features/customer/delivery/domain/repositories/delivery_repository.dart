import 'package:delwaqty/features/customer/delivery/domain/entities/delivery_order.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/merchant_profile.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/driver_capability.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/delivery_pricing.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/driver_stats.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/ride_offer.dart';

abstract interface class DeliveryRepository {
  Future<String> dispatchDelivery(String rideId, {double radiusKm = 10, int limit = 5});
  Future<String> acceptDeliveryRequest(String rideId, String driverId);
  Future<void> rejectDeliveryRequest(String rideId, String driverId);
  Stream<List<RideOffer>> watchDeliveryOffers(String driverId);

  Stream<DeliveryOrder?> watchActiveDelivery(String driverId);
  Future<DeliveryOrder?> getActiveDelivery(String driverId);
  Future<void> driverArrivedAtPickup(String rideId, String driverId);
  Future<void> startDelivery(String rideId, String driverId, String otp);
  Future<double> completeDelivery(String rideId, String driverId, {String? proofUrl, double? finalDistanceKm});
  Future<void> cancelDelivery(String rideId, {String? reason});


  Future<DeliveryPricingModel> getDeliveryPricing(String serviceType);
  Future<Map<String, dynamic>> estimateDeliveryFee(String serviceType, double distanceKm, {double weightKg = 1.0, String priority = 'standard'});

  Future<DriverCapability> getDriverCapabilities(String driverId);
  Future<void> updateDriverCapabilities(String driverId, {required List<String> serviceTypes, bool acceptsDeliveries = true, double maxDistance = 15, double maxWeight = 20});

  Future<MerchantProfile?> getMerchantProfile(String merchantId);
  Future<void> upsertMerchantProfile({required String merchantId, required String userId, List<String>? serviceTypes, int? averagePrepTime, double? maxRadius});

  Future<DriverStats> getDashboardStats(String driverId);
  Future<List<DriverEarning>> getEarnings(String driverId, {int limit = 30});

  Future<void> rateDelivery(String rideId, String driverId, int stars, {String? comment});
}
