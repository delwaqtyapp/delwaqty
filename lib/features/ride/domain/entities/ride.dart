import 'package:freezed_annotation/freezed_annotation.dart';

part 'ride.freezed.dart';
part 'ride.g.dart';

enum RideStatus { searching, matched, arrived, inTrip, completed, cancelled }

enum RideType { economy, comfort, premium }

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
