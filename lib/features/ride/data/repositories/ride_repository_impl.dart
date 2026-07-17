import 'package:delwaqty/features/ride/domain/entities/ride.dart';
import 'package:delwaqty/features/ride/domain/repositories/ride_repository.dart';
import 'package:delwaqty/features/ride/data/datasources/remote/supabase_ride_data_source.dart';

class RideRepositoryImpl implements RideRepository {
  RideRepositoryImpl(this._dataSource);

  final SupabaseRideDataSource _dataSource;

  @override
  Future<Ride> requestRide({
    required double pickupLatitude,
    required double pickupLongitude,
    required String pickupAddress,
    required double dropoffLatitude,
    required double dropoffLongitude,
    required String dropoffAddress,
    required RideType rideType,
  }) {
    return _dataSource.requestRide(
      riderId: 'current-user',
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
      pickupAddress: pickupAddress,
      dropoffLatitude: dropoffLatitude,
      dropoffLongitude: dropoffLongitude,
      dropoffAddress: dropoffAddress,
      rideType: rideType,
    );
  }

  @override
  Future<void> cancelRide(String rideId, {String? reason}) {
    return _dataSource.cancelRide(rideId, reason: reason);
  }

  @override
  Future<Ride?> getActiveRide() {
    return _dataSource.getActiveRide('current-user');
  }

  @override
  Future<List<Ride>> getRideHistory({int limit = 20, int offset = 0}) {
    return _dataSource.getRideHistory('current-user', limit: limit, offset: offset);
  }

  @override
  Future<void> rateRide(String rideId, int rating, {String? feedback, double? tip}) {
    return _dataSource.rateRide(rideId, rating, feedback: feedback, tip: tip);
  }

  @override
  Future<void> shareTrip(String rideId) {
    return _dataSource.shareTrip(rideId);
  }

  @override
  Future<void> reportIssue(String rideId, String issue) {
    return _dataSource.reportIssue(rideId, issue);
  }

  @override
  Future<Map<String, double>> getFareEstimate({
    required double pickupLatitude,
    required double pickupLongitude,
    required double dropoffLatitude,
    required double dropoffLongitude,
    required RideType rideType,
  }) {
    return _dataSource.getFareEstimate(
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
      dropoffLatitude: dropoffLatitude,
      dropoffLongitude: dropoffLongitude,
      rideType: rideType,
    );
  }
}
