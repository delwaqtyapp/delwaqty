import 'package:delwaqty/features/driver/domain/entities/driver_profile.dart';
import 'package:delwaqty/features/driver/domain/entities/driver_delivery.dart';
import 'package:delwaqty/features/driver/domain/repositories/driver_repository.dart';
import 'package:delwaqty/features/driver/data/datasources/remote/supabase_driver_data_source.dart';

class DriverRepositoryImpl implements DriverRepository {
  DriverRepositoryImpl(this._dataSource);

  final SupabaseDriverDataSource _dataSource;

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
}
