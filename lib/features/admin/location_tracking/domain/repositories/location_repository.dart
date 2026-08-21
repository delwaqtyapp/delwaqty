import 'package:delwaqty/features/admin/location_tracking/domain/entities/location_update.dart';

abstract class LocationRepository {
  Future<List<LocationUpdate>> getUserLocations(String userId, {int limit = 50});
  Future<List<LocationUpdate>> getActiveDrivers();
  Future<LocationUpdate?> getLatestLocation(String userId);
  Future<void> upsertLocation(LocationUpdate location);
  Stream<LocationUpdate> locationStream(String userId);
}
