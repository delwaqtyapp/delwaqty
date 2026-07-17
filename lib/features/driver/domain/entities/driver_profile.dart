import 'package:freezed_annotation/freezed_annotation.dart';

part 'driver_profile.freezed.dart';
part 'driver_profile.g.dart';

enum DriverStatus {
  offline,
  online,
  onDelivery,
}

@freezed
class DriverProfile with _$DriverProfile {
  const factory DriverProfile({
    required String id,
    required String userId,
    String? vehicleType,
    String? vehiclePlate,
    String? vehicleColor,
    @Default(DriverStatus.offline) DriverStatus status,
    double? currentLatitude,
    double? currentLongitude,
    @Default(0.0) double totalEarnings,
    @Default(0) int totalDeliveries,
    @Default(4.5) double rating,
    required DateTime createdAt,
  }) = _DriverProfile;

  factory DriverProfile.fromJson(Map<String, dynamic> json) =>
      _$DriverProfileFromJson(json);
}
