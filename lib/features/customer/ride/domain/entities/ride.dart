import 'package:freezed_annotation/freezed_annotation.dart';

part 'ride.freezed.dart';
part 'ride.g.dart';

enum RideStatus { searching, matched, arrived, inTrip, completed, cancelled }

extension RideStatusX on RideStatus {
  static const Map<RideStatus, Set<RideStatus>> _legal = {
    RideStatus.searching: {RideStatus.matched, RideStatus.cancelled},
    RideStatus.matched: {RideStatus.arrived, RideStatus.cancelled},
    RideStatus.arrived: {RideStatus.inTrip, RideStatus.cancelled},
    RideStatus.inTrip: {RideStatus.completed, RideStatus.cancelled},
    RideStatus.completed: {},
    RideStatus.cancelled: {},
  };

  bool canTransitionTo(RideStatus next) => _legal[this]!.contains(next);

  bool get isTerminal =>
      this == RideStatus.completed || this == RideStatus.cancelled;

  bool get isActive => !isTerminal;
}

enum RideType { economy, comfort, premium, xl, motorbike, taxi }

extension RideTypeX on RideType {
  int get passengerCapacity {
    switch (this) {
      case RideType.economy:
        return 4;
      case RideType.comfort:
        return 4;
      case RideType.premium:
        return 4;
      case RideType.xl:
        return 6;
      case RideType.motorbike:
        return 1;
      case RideType.taxi:
        return 4;
    }
  }

  int get luggageCapacity {
    switch (this) {
      case RideType.economy:
        return 2;
      case RideType.comfort:
        return 2;
      case RideType.premium:
        return 3;
      case RideType.xl:
        return 4;
      case RideType.motorbike:
        return 0;
      case RideType.taxi:
        return 2;
    }
  }
}

@freezed
class Ride with _$Ride {
  const factory Ride({
    required String id,
    required String riderId,
    String? driverId,
    String? driverName,
    String? driverPhone,
    String? driverPhoto,
    String? vehicleType,
    String? vehiclePlate,
    String? vehicleColor,
    required double pickupLatitude,
    required double pickupLongitude,
    required String pickupAddress,
    required double dropoffLatitude,
    required double dropoffLongitude,
    required String dropoffAddress,
    @Default(RideType.economy) RideType rideType,
    @Default(RideStatus.searching) RideStatus status,
    double? fare,
    double? baseFare,
    double? distanceFare,
    double? timeFare,
    @Default(1.0) double surgeMultiplier,
    @Default(0.0) double discountAmount,
    String? promoCode,
    @Default('cash') String paymentMethod,
    @Default('pending') String paymentStatus,
    String? pickupOtp,
    @Default('EGP') String currency,
    double? distance,
    int? estimatedMinutes,
    double? driverLatitude,
    double? driverLongitude,
    required DateTime createdAt,
    DateTime? matchedAt,
    DateTime? arrivedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? cancellationReason,
    @Default(false) bool isSharedTrip,
    String? emergencyContactId,
  }) = _Ride;

  factory Ride.fromJson(Map<String, dynamic> json) => _$RideFromJson(json);
}
