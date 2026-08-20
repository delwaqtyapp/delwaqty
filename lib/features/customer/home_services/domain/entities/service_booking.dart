import 'package:freezed_annotation/freezed_annotation.dart';
import 'service_category.dart';

part 'service_booking.freezed.dart';
part 'service_booking.g.dart';

enum BookingStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('confirmed')
  confirmed,
  @JsonValue('inProgress')
  inProgress,
  @JsonValue('completed')
  completed,
  @JsonValue('cancelled')
  cancelled,
}

@freezed
class ServiceBooking with _$ServiceBooking {
  const factory ServiceBooking({
    required String id,
    required String userId,
    required String providerId,
    required String providerName,
    required ServiceCategoryType categoryType,
    required BookingStatus status,
    String? description,
    required DateTime scheduledDate,
    required String scheduledTime,
    String? address,
    double? addressLatitude,
    double? addressLongitude,
    double? estimatedPrice,
    double? finalPrice,
    String? notes,
    required DateTime createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) = _ServiceBooking;

  factory ServiceBooking.fromJson(Map<String, dynamic> json) =>
      _$ServiceBookingFromJson(json);
}
