import 'package:delwaqty/features/customer/driver/domain/entities/driver_profile.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/driver_delivery.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/vehicle.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/driver_document.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/wallet_detail.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/driver_performance.dart';

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

  // M6: Onboarding
  Future<void> submitOnboardingStep(String driverId, {String? fullName, String? phone, String? nationalId, String? address, String? profilePhotoUrl, required int step});
  Future<void> completeOnboarding(String driverId);

  // M6: Vehicles
  Future<List<Vehicle>> getVehicles(String driverId);
  Future<String> addVehicle(String driverId, {required String category, String? make, String? model, int? year, String? color, required String plateNumber, int seats = 4, String? photoUrl});
  Future<void> updateVehicle(String vehicleId, String driverId, {String? category, String? make, String? model, int? year, String? color, String? plateNumber, int? seats, String? photoUrl, bool? isActive});
  Future<void> toggleVehicleActive(String vehicleId, String driverId);

  // M6: Documents
  Future<List<DriverDocument>> getDocuments(String driverId);
  Future<String> upsertDocument(String driverId, String docType, String fileUrl, {String? fileName, int? fileSize, DateTime? expiresAt});

  // M6: Wallet
  Future<WalletDetail> getWalletDetail(String driverId);

  // M6: Performance
  Future<DriverPerformance> getPerformance(String driverId);
}
