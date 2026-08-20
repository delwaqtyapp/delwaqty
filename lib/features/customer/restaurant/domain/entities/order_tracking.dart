import 'package:freezed_annotation/freezed_annotation.dart';

part 'order_tracking.freezed.dart';
part 'order_tracking.g.dart';

@freezed
class OrderTracking with _$OrderTracking {
  const factory OrderTracking({
    required String id,
    required String orderId,
    required String status,
    int? estimatedMinutes,
    String? notes,
    required DateTime createdAt,
  }) = _OrderTracking;

  factory OrderTracking.fromJson(Map<String, dynamic> json) =>
      _$OrderTrackingFromJson(json);
}
