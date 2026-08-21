import 'package:freezed_annotation/freezed_annotation.dart';

part 'vehicle.freezed.dart';
part 'vehicle.g.dart';

@freezed
class Vehicle with _$Vehicle {
  const factory Vehicle({
    required String id,
    required String driverId,
    required String category,
    String? make,
    String? model,
    int? year,
    String? color,
    required String plateNumber,
    @Default(4) int seats,
    @Default(true) bool isActive,
    @Default(false) bool isVerified,
    String? photoUrl,
    DateTime? registrationExpiresAt,
    DateTime? insuranceExpiresAt,
    required DateTime createdAt,
  }) = _Vehicle;

  factory Vehicle.fromJson(Map<String, dynamic> json) => _$VehicleFromJson(json);
}
