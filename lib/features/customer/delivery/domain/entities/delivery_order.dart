import 'package:freezed_annotation/freezed_annotation.dart';

part 'delivery_order.freezed.dart';
part 'delivery_order.g.dart';

enum DeliveryServiceType {
  ride,
  foodDelivery,
  groceryDelivery,
  pharmacyDelivery,
  marketplaceDelivery,
  courier,
  packageDelivery,
  documentDelivery,
  flowerDelivery,
  retailDelivery,
}

enum DeliveryPriority { standard, priority, express }

@freezed
abstract class DeliveryOrder with _$DeliveryOrder {
  const factory DeliveryOrder({
    required String id,
    required String serviceType,
    String? merchantId,
    String? merchantName,
    String? merchantAddress,
    String? riderId,
    String? driverId,
    String? driverName,
    String? driverPhone,
    required double pickupLatitude,
    required double pickupLongitude,
    @Default('') String pickupAddress,
    String? pickupNotes,
    required double dropoffLatitude,
    required double dropoffLongitude,
    @Default('') String dropoffAddress,
    String? dropoffNotes,
    @Default('standard') String priority,
    @Default('searching') String status,
    double? fare,
    double? deliveryFee,
    @Default('EGP') String currency,
    double? distance,
    int? estimatedMinutes,
    String? itemsSummary,
    double? weightKg,
    @Default(false) bool signatureRequired,
    @Default(true) bool otpRequired,
    String? deliveryProofUrl,
    DateTime? scheduledAt,
    DateTime? createdAt,
    DateTime? matchedAt,
    DateTime? arrivedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? cancellationReason,
  }) = _DeliveryOrder;

  factory DeliveryOrder.fromJson(Map<String, dynamic> json) =>
      _$DeliveryOrderFromJson(json);
}
