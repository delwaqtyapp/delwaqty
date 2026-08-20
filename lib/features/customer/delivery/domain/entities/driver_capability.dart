import 'package:freezed_annotation/freezed_annotation.dart';

part 'driver_capability.freezed.dart';
part 'driver_capability.g.dart';

@freezed
class DriverCapability with _$DriverCapability {
  const factory DriverCapability({
    required String driverId,
    @Default(['ride']) List<String> serviceTypes,
    @Default(false) bool acceptsDeliveries,
    @Default(15.0) double maxDeliveryDistanceKm,
    @Default(20.0) double maxWeightKg,
  }) = _DriverCapability;

  factory DriverCapability.fromJson(Map<String, dynamic> json) =>
      _$DriverCapabilityFromJson(json);
}
