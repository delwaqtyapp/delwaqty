import 'package:delwaqty/features/customer/driver/domain/entities/driver_profile.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/driver_delivery.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/vehicle.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/driver_document.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/wallet_detail.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/driver_performance.dart';
import 'package:delwaqty/features/customer/driver/domain/repositories/driver_repository.dart';
import 'package:delwaqty/features/customer/driver/data/datasources/remote/supabase_driver_data_source.dart';
import 'package:delwaqty/features/customer/driver/data/datasources/remote/supabase_driver_platform_data_source.dart';

class DriverRepositoryImpl implements DriverRepository {
  DriverRepositoryImpl(this._dataSource, this._platformDataSource);

  final SupabaseDriverDataSource _dataSource;
  final SupabaseDriverPlatformDataSource _platformDataSource;

  @override
  Future<DriverProfile?> getProfile(String userId) => _dataSource.getProfile(userId);

  @override
  Future<DriverProfile> registerProfile(String userId, {String? vehicleType, String? vehiclePlate, String? vehicleColor}) =>
      _dataSource.registerProfile(userId, vehicleType: vehicleType, vehiclePlate: vehiclePlate, vehicleColor: vehicleColor);

  @override
  Future<void> updateStatus(String profileId, DriverStatus status) => _dataSource.updateStatus(profileId, status);

  @override
  Future<void> updateLocation(String profileId, double lat, double lng) => _dataSource.updateLocation(profileId, lat, lng);

  @override
  Future<List<DriverDelivery>> getAvailableDeliveries() => _dataSource.getAvailableDeliveries();

  @override
  Future<List<DriverDelivery>> getMyDeliveries(String profileId, {String? status}) =>
      _dataSource.getMyDeliveries(profileId, status: status);

  @override
  Future<void> acceptDelivery(String deliveryId, String profileId) => _dataSource.acceptDelivery(deliveryId, profileId);

  @override
  Future<void> rejectDelivery(String deliveryId) => _dataSource.rejectDelivery(deliveryId);

  @override
  Future<void> updateDeliveryStatus(String deliveryId, String status) => _dataSource.updateDeliveryStatus(deliveryId, status);

  @override
  Future<DriverProfile> getStats(String profileId) async {
    final profile = await _dataSource.getProfile(profileId);
    if (profile == null) throw Exception('Driver profile not found');
    return profile;
  }

  // M6: Onboarding
  @override
  Future<void> submitOnboardingStep(String driverId, {String? fullName, String? phone, String? nationalId, String? address, String? profilePhotoUrl, required int step}) =>
      _platformDataSource.submitOnboardingStep(driverId, fullName: fullName, phone: phone, nationalId: nationalId, address: address, profilePhotoUrl: profilePhotoUrl, step: step);

  @override
  Future<void> completeOnboarding(String driverId) =>
      _platformDataSource.completeOnboarding(driverId);

  // M6: Vehicles
  @override
  Future<List<Vehicle>> getVehicles(String driverId) =>
      _platformDataSource.getVehicles(driverId);

  @override
  Future<String> addVehicle(String driverId, {required String category, String? make, String? model, int? year, String? color, required String plateNumber, int seats = 4, String? photoUrl}) =>
      _platformDataSource.addVehicle(driverId, category: category, make: make, model: model, year: year, color: color, plateNumber: plateNumber, seats: seats, photoUrl: photoUrl);

  @override
  Future<void> updateVehicle(String vehicleId, String driverId, {String? category, String? make, String? model, int? year, String? color, String? plateNumber, int? seats, String? photoUrl, bool? isActive}) =>
      _platformDataSource.updateVehicle(vehicleId, driverId, category: category, make: make, model: model, year: year, color: color, plateNumber: plateNumber, seats: seats, photoUrl: photoUrl, isActive: isActive);

  @override
  Future<void> toggleVehicleActive(String vehicleId, String driverId) =>
      _platformDataSource.toggleVehicleActive(vehicleId, driverId);

  // M6: Documents
  @override
  Future<List<DriverDocument>> getDocuments(String driverId) =>
      _platformDataSource.getDocuments(driverId);

  @override
  Future<String> upsertDocument(String driverId, String docType, String fileUrl, {String? fileName, int? fileSize, DateTime? expiresAt}) =>
      _platformDataSource.upsertDocument(driverId, docType, fileUrl, fileName: fileName, fileSize: fileSize, expiresAt: expiresAt);

  // M6: Wallet
  @override
  Future<WalletDetail> getWalletDetail(String driverId) =>
      _platformDataSource.getWalletDetail(driverId);

  // M6: Performance
  @override
  Future<DriverPerformance> getPerformance(String driverId) =>
      _platformDataSource.getPerformance(driverId);
}
