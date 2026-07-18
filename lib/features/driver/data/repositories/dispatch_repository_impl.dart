import 'package:delwaqty/features/driver/data/datasources/remote/supabase_dispatch_data_source.dart';
import 'package:delwaqty/features/driver/domain/entities/driver_stats.dart';
import 'package:delwaqty/features/driver/domain/entities/ride_offer.dart';
import 'package:delwaqty/features/driver/domain/repositories/dispatch_repository.dart';
import 'package:delwaqty/features/ride/domain/entities/ride.dart';

class DispatchRepositoryImpl implements DispatchRepository {
  DispatchRepositoryImpl(this._dataSource);

  final SupabaseDispatchDataSource _dataSource;

  @override
  Future<String> registerRideDriver({
    required String fullName,
    required String phone,
    required RideType category,
    required String make,
    required String model,
    required String color,
    required String plate,
    int seats = 4,
  }) {
    return _dataSource.registerRideDriver(
      fullName: fullName,
      phone: phone,
      category: category,
      make: make,
      model: model,
      color: color,
      plate: plate,
      seats: seats,
    );
  }

  @override
  Future<void> setOnline(String driverId, bool online, {double? lat, double? lng}) {
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
    return _dataSource.updateLocation(driverId, lat, lng,
        heading: heading, speed: speed);
  }

  @override
  Stream<List<RideOffer>> watchOffers(String driverId) =>
      _dataSource.watchOffers(driverId);

  @override
  Future<String> acceptOffer(String rideId, String driverId) =>
      _dataSource.acceptOffer(rideId, driverId);

  @override
  Future<void> rejectOffer(String rideId, String driverId) =>
      _dataSource.rejectOffer(rideId, driverId);

  @override
  Stream<Ride?> watchActiveDriverRide(String driverId) =>
      _dataSource.watchActiveDriverRide(driverId);

  @override
  Future<Ride?> getActiveDriverRide(String driverId) =>
      _dataSource.getActiveDriverRide(driverId);

  @override
  Future<void> arriveAtPickup(String rideId, String driverId) =>
      _dataSource.arriveAtPickup(rideId, driverId);

  @override
  Future<void> startTrip(String rideId, String driverId, String otp) =>
      _dataSource.startTrip(rideId, driverId, otp);

  @override
  Future<double> completeTrip(String rideId, String driverId,
          {double? finalDistanceKm}) =>
      _dataSource.completeTrip(rideId, driverId, finalDistanceKm: finalDistanceKm);

  @override
  Future<void> cancelAsDriver(String rideId, {String? reason}) =>
      _dataSource.cancelAsDriver(rideId, reason: reason);

  @override
  Future<void> ratePassenger(String rideId, String driverId, int stars,
          {String? comment}) =>
      _dataSource.ratePassenger(rideId, driverId, stars, comment: comment);

  @override
  Future<DriverStats> getDashboardStats(String driverId) =>
      _dataSource.getDashboardStats(driverId);

  @override
  Future<List<DriverEarning>> getEarnings(String driverId, {int limit = 30}) =>
      _dataSource.getEarnings(driverId, limit: limit);

  @override
  Future<String> requestWithdrawal(String driverId, double amount,
          {String method = 'bank'}) =>
      _dataSource.requestWithdrawal(driverId, amount, method: method);
}
