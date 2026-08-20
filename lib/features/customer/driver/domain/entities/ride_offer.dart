import 'package:delwaqty/features/customer/ride/domain/entities/ride.dart';

class RideOffer {
  const RideOffer({
    required this.requestId,
    required this.rideId,
    required this.driverId,
    required this.rideType,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.pickupAddress,
    required this.dropoffLatitude,
    required this.dropoffLongitude,
    required this.dropoffAddress,
    required this.fare,
    required this.currency,
    required this.distanceKm,
    required this.pickupDistanceKm,
    required this.etaMinutes,
    required this.offeredAt,
    required this.expiresAt,
  });

  final String requestId;
  final String rideId;
  final String driverId;
  final RideType rideType;
  final double pickupLatitude;
  final double pickupLongitude;
  final String pickupAddress;
  final double dropoffLatitude;
  final double dropoffLongitude;
  final String dropoffAddress;
  final double fare;
  final String currency;
  final double distanceKm;
  final double pickupDistanceKm;
  final int etaMinutes;
  final DateTime offeredAt;
  final DateTime expiresAt;

  double get estimatedEarnings => fare;

  Duration get remaining {
    final diff = expiresAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  bool get isExpired => remaining == Duration.zero;
}
