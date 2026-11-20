import 'package:delwaqty/features/customer/driver/data/datasources/remote/supabase_dispatch_data_source.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/driver_stats.dart';
import 'package:delwaqty/features/customer/driver/domain/repositories/dispatch_repository.dart';

class DispatchRepositoryImpl implements DispatchRepository {
  DispatchRepositoryImpl(this._dataSource);

  final SupabaseDispatchDataSource _dataSource;

  @override
  Future<void> setOnline(
    String driverId,
    bool online, {
    double? lat,
    double? lng,
  }) {
    return _dataSource.setOnline(driverId, online, lat: lat, lng: lng);
  }

  @override
  Future<void> updateLocation(
    String driverId,
    double lat,
    double lng, {
    double? heading,
    double? speed,
  }) {
    return _dataSource.updateLocation(
      driverId,
      lat,
      lng,
      heading: heading,
      speed: speed,
    );
  }

  @override
  Future<DriverStats> getDashboardStats(String driverId) =>
      _dataSource.getDashboardStats(driverId);

  @override
  Future<List<DriverEarning>> getEarnings(String driverId, {int limit = 30}) =>
      _dataSource.getEarnings(driverId, limit: limit);

  @override
  Future<String> requestWithdrawal(
    String driverId,
    double amount, {
    String method = 'bank',
  }) => _dataSource.requestWithdrawal(driverId, amount, method: method);
}
