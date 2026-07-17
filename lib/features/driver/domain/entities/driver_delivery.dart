import 'package:freezed_annotation/freezed_annotation.dart';

part 'driver_delivery.freezed.dart';
part 'driver_delivery.g.dart';

@freezed
class DriverDelivery with _$DriverDelivery {
  const factory DriverDelivery({
    required String id,
    required String orderId,
    required String merchantName,
    required String merchantAddress,
    required String customerName,
    required String deliveryAddress,
    double? customerLatitude,
    double? customerLongitude,
    @Default('pending') String status,
    double? deliveryFee,
    String? notes,
    required DateTime createdAt,
    DateTime? acceptedAt,
    DateTime? pickedUpAt,
    DateTime? deliveredAt,
  }) = _DriverDelivery;

  factory DriverDelivery.fromJson(Map<String, dynamic> json) =>
      _$DriverDeliveryFromJson(json);
}
