import 'package:delwaqty/features/admin/location_tracking/domain/entities/location_update.dart';
import 'package:delwaqty/features/admin/location_tracking/domain/repositories/location_repository.dart';
import 'package:delwaqty/features/admin/location_tracking/data/datasources/remote/supabase_location_data_source.dart';

class LocationRepositoryImpl implements LocationRepository {
  final SupabaseLocationDataSource _dataSource;

  LocationRepositoryImpl(this._dataSource);

  @override
  Future<List<LocationUpdate>> getUserLocations(String userId, {int limit = 50}) {
    return _dataSource.getUserLocations(userId, limit: limit);
  }

  @override
  Future<List<LocationUpdate>> getActiveDrivers() {
    return _dataSource.getActiveDrivers();
  }

  @override
  Future<LocationUpdate?> getLatestLocation(String userId) {
    return _dataSource.getLatestLocation(userId);
  }

  @override
  Future<void> upsertLocation(LocationUpdate location) {
    return _dataSource.upsertLocation(location);
  }

  @override
  Stream<LocationUpdate> locationStream(String userId) {
    return _dataSource.locationStream(userId);
  }
}
