import 'package:delwaqty/features/customer/driver/domain/entities/driver_stats.dart';

abstract interface class DispatchRepository {
  Future<bool> getOnline(String driverId);

  Future<void> setOnline(
    String driverId,
    bool online, {
    double? lat,
    double? lng,
  });

  Future<void> updateLocation(
    String driverId,
    double lat,
    double lng, {
    double? heading,
    double? speed,
  });

  Future<DriverStats> getDashboardStats(String driverId);

  Future<List<DriverEarning>> getEarnings(String driverId, {int limit = 30});

  Future<String> requestWithdrawal(
    String driverId,
    double amount, {
    String method,
  });
}
