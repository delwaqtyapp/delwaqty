import 'package:delwaqty/features/customer/delivery/domain/entities/ask_anything_ride_state.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/cash_collection.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/courier_invoice_item.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/courier_quote.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/courier_shopping_item.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/delivery_order.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/merchant_profile.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/driver_capability.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/delivery_pricing.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/driver_stats.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/ride_offer.dart';

abstract interface class DeliveryRepository {
  Future<String> requestCourierDelivery({
    required String riderId,
    required double pickupLatitude,
    required double pickupLongitude,
    required String pickupAddress,
    required double dropoffLatitude,
    required double dropoffLongitude,
    required String dropoffAddress,
    String? itemsSummary,
    String? notes,
    String priority = 'standard',
  });

  Future<String> dispatchDelivery(
    String rideId, {
    double radiusKm = 10,
    int limit = 5,
  });

  /// Ask-anything courier flow (436).
  Future<({String deliveryId, double quoteBaseline})> requestCourierShopping({
    required double pickupLatitude,
    required double pickupLongitude,
    required String pickupAddress,
    required double dropoffLatitude,
    required double dropoffLongitude,
    required String dropoffAddress,
    required List<CourierShoppingItem> items,
    required int estimatedShops,
    String? notes,
    String priority = 'standard',
  });
  Future<void> proposeCourierQuote(
    String rideId,
    double amount, {
    String? note,
  });
  Future<void> respondCourierQuote(String quoteId, String action);
  Future<void> decideCourierInvoiceItem(String itemId, String action);
  Stream<AskAnythingRideState?> watchAskAnythingRide(String rideId);
  Stream<List<CourierQuote>> watchCourierQuotes(String rideId);
  Stream<List<CourierInvoiceItem>> watchCourierInvoiceItems(String rideId);
  Future<String> acceptDeliveryRequest(String rideId, String driverId);
  Future<void> rejectDeliveryRequest(String rideId, String driverId);
  Stream<List<RideOffer>> watchDeliveryOffers(String driverId);

  Stream<DeliveryOrder?> watchActiveDelivery(String driverId);
  Future<DeliveryOrder?> getActiveDelivery(String driverId);
  Future<DeliveryOrder?> getDeliveryOrderById(String id);
  Future<void> driverArrivedAtPickup(String rideId, String driverId);
  Future<void> startDelivery(String rideId, String driverId, String otp);
  Future<double> completeDelivery(
    String rideId,
    String driverId, {
    String? proofUrl,
    String? recipientOtp,
    double? finalDistanceKm,
  });
  Future<void> cancelDelivery(String rideId, {String? reason, bool byDriver});

  Future<void> reportIncident(String rideId, String kind, {String? note});

  Future<DeliveryPricingModel> getDeliveryPricing(String serviceType);
  Future<Map<String, dynamic>> estimateDeliveryFee(
    String serviceType,
    double distanceKm, {
    double weightKg = 1.0,
    String priority = 'standard',
  });

  Future<DriverCapability> getDriverCapabilities(String driverId);
  Future<void> updateDriverCapabilities(
    String driverId, {
    required List<String> serviceTypes,
    bool acceptsDeliveries = true,
    double maxDistance = 15,
    double maxWeight = 20,
  });

  Future<MerchantProfile?> getMerchantProfile(String merchantId);
  Future<void> upsertMerchantProfile({
    required String merchantId,
    required String userId,
    List<String>? serviceTypes,
    int? averagePrepTime,
    double? maxRadius,
  });

  Future<DriverStats> getDashboardStats(String driverId);
  Future<List<DriverEarning>> getEarnings(String driverId, {int limit = 30});

  Future<void> rateDelivery(
    String rideId,
    String driverId,
    int stars, {
    String? comment,
  });

  /// Cash handoff (migration 392): what the captain should collect on this
  /// delivery and whether it is collected. Answers only the assigned driver.
  Future<CashCollectionState?> getCashCollectionState(String rideId);

  /// The captain's "تم التحصيل" tap: marks the cash collected and syncs the
  /// linked commerce order. Idempotent on the server.
  Future<CashCollectionResult> confirmCashCollection(String rideId);

  /// The delivery ride linked to a commerce order, for the customer's
  /// post-collection driver rating. Streams realtime ride changes so the
  /// rating card unlocks the moment the captain stamps the collection
  /// (review #71), without waiting for a manual refresh.
  Stream<OrderDeliveryRide?> watchOrderDeliveryRide(String orderId);
}
