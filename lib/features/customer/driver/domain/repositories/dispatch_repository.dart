import 'package:delwaqty/features/customer/driver/domain/entities/driver_stats.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/ride_offer.dart';
import 'package:delwaqty/features/customer/ride/domain/entities/ride.dart';

abstract interface class DispatchRepository {
  Future<String> registerRideDriver({
    required String fullName,
    required String phone,
    required RideType category,
    required String make,
    required String model,
    required String color,
    required String plate,
    int seats,
  });

  Future<void> setOnline(String driverId, bool online, {double? lat, double? lng});

  Future<void> updateLocation(
    String driverId,
    double lat,
    double lng, {
    double? heading,
    double? speed,
  });

  Stream<List<RideOffer>> watchOffers(String driverId);

  Future<String> acceptOffer(String rideId, String driverId);

  Future<void> rejectOffer(String rideId, String driverId);

  Stream<Ride?> watchActiveDriverRide(String driverId);

  Future<Ride?> getActiveDriverRide(String driverId);

  Future<void> arriveAtPickup(String rideId, String driverId);

  Future<void> startTrip(String rideId, String driverId, String otp);

  Future<double> completeTrip(String rideId, String driverId, {double? finalDistanceKm});

  Future<void> cancelAsDriver(String rideId, {String? reason});

  Future<void> ratePassenger(String rideId, String driverId, int stars, {String? comment});

  Future<DriverStats> getDashboardStats(String driverId);

  Future<List<DriverEarning>> getEarnings(String driverId, {int limit = 30});

  Future<String> requestWithdrawal(String driverId, double amount, {String method});
}
