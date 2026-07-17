import 'package:delwaqty/features/driver/domain/entities/driver_profile.dart';
import 'package:delwaqty/features/driver/domain/entities/driver_delivery.dart';

abstract interface class DriverRepository {
  Future<DriverProfile?> getProfile(String userId);
  Future<DriverProfile> registerProfile(String userId, {String? vehicleType, String? vehiclePlate, String? vehicleColor});
  Future<void> updateStatus(String profileId, DriverStatus status);
  Future<void> updateLocation(String profileId, double lat, double lng);
  Future<List<DriverDelivery>> getAvailableDeliveries();
  Future<List<DriverDelivery>> getMyDeliveries(String profileId, {String? status});
  Future<void> acceptDelivery(String deliveryId, String profileId);
  Future<void> rejectDelivery(String deliveryId);
  Future<void> updateDeliveryStatus(String deliveryId, String status);
  Future<DriverProfile> getStats(String profileId);
}
