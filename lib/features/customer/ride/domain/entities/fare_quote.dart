import 'package:delwaqty/features/customer/ride/domain/entities/ride.dart';

class FareQuote {
  const FareQuote({
    required this.rideType,
    required this.baseFare,
    required this.distanceFare,
    required this.timeFare,
    required this.surgeMultiplier,
    required this.total,
    required this.minimumFare,
    required this.currency,
    required this.distanceKm,
    required this.durationMinutes,
    required this.etaMinutes,
  });

  final RideType rideType;
  final double baseFare;
  final double distanceFare;
  final double timeFare;
  final double surgeMultiplier;
  final double total;
  final double minimumFare;
  final String currency;
  final double distanceKm;
  final double durationMinutes;
  final int etaMinutes;
}

class PromoResult {
  const PromoResult({
    required this.valid,
    this.discount = 0,
    this.promoId,
    this.reason,
  });

  final bool valid;
  final double discount;
  final String? promoId;
  final String? reason;
}

class NearbyDriver {
  const NearbyDriver({
    required this.driverId,
    required this.fullName,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.rating,
  });

  final String driverId;
  final String fullName;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final double rating;
}
