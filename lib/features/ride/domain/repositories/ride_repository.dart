import 'package:delwaqty/features/ride/domain/entities/ride.dart';

abstract interface class RideRepository {
  Future<Ride> requestRide({
    required double pickupLatitude,
    required double pickupLongitude,
    required String pickupAddress,
    required double dropoffLatitude,
    required double dropoffLongitude,
    required String dropoffAddress,
    required RideType rideType,
  });

  Future<void> cancelRide(String rideId, {String? reason});

  Future<Ride?> getActiveRide();

  Future<List<Ride>> getRideHistory({int limit = 20, int offset = 0});

  Future<void> rateRide(String rideId, int rating, {String? feedback, double? tip});

  Future<void> shareTrip(String rideId);

  Future<void> reportIssue(String rideId, String issue);

  Future<Map<String, double>> getFareEstimate({
    required double pickupLatitude,
    required double pickupLongitude,
    required double dropoffLatitude,
    required double dropoffLongitude,
    required RideType rideType,
  });
}
