import 'package:freezed_annotation/freezed_annotation.dart';

part 'delivery_zone.freezed.dart';
part 'delivery_zone.g.dart';

@freezed
class DeliveryZone with _$DeliveryZone {
  const factory DeliveryZone({
    required String id,
    required String merchantId,
    required String name,
    required double radiusKm,
    @Default(0.0) double deliveryFee,
    @Default(0.0) double minimumOrder,
    @Default(30) int estimatedMinutes,
    @Default(true) bool isActive,
    required DateTime createdAt,
  }) = _DeliveryZone;

  factory DeliveryZone.fromJson(Map<String, dynamic> json) =>
      _$DeliveryZoneFromJson(json);
}
