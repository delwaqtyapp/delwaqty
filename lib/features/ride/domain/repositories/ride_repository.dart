import 'package:delwaqty/features/ride/domain/entities/ride.dart';
import 'package:delwaqty/features/ride/domain/entities/fare_quote.dart';

abstract interface class RideRepository {
  Future<List<FareQuote>> getFareQuotes({
    required double pickupLatitude,
    required double pickupLongitude,
    required double dropoffLatitude,
    required double dropoffLongitude,
  });

  Future<PromoResult> validatePromo({
    required String code,
    required double fare,
  });

  Future<Ride> requestRide({
    required double pickupLatitude,
    required double pickupLongitude,
    required String pickupAddress,
    required double dropoffLatitude,
    required double dropoffLongitude,
    required String dropoffAddress,
    required RideType rideType,
    required double fare,
    required FareQuote quote,
    String? promoCode,
    double discountAmount,
    String paymentMethod,
  });

  Future<List<NearbyDriver>> findNearbyDrivers({
    required double latitude,
    required double longitude,
    required RideType rideType,
  });

  Stream<Ride> watchRide(String rideId);

  Future<Ride?> getRide(String rideId);

  Future<void> cancelRide(String rideId, {String? reason});

  Future<Ride?> getActiveRide();

  Future<List<Ride>> getRideHistory({int limit = 20, int offset = 0});

  Future<void> rateRide(String rideId, int rating, {String? feedback, double? tip});

  Future<void> shareTrip(String rideId);

  Future<void> reportIssue(String rideId, String issue);
}
