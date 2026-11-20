import 'package:freezed_annotation/freezed_annotation.dart';

import 'service_category.dart';

part 'service_booking.freezed.dart';

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
abstract class ServiceBooking with _$ServiceBooking {
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

  factory ServiceBooking.fromJson(Map<String, dynamic> json) {
    return ServiceBooking(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      providerId: json['provider_id'] as String? ?? '',
      providerName: json['provider_name'] as String? ?? '',
      categoryType: serviceCategoryTypeFromJson(json['category_type']),
      status: _bookingStatusFromJson(json['status']),
      description: json['description'] as String?,
      scheduledDate: DateTime.parse(json['scheduled_date'] as String),
      scheduledTime: json['scheduled_time'] as String? ?? '',
      address: json['address'] as String?,
      addressLatitude: (json['address_latitude'] as num?)?.toDouble(),
      addressLongitude: (json['address_longitude'] as num?)?.toDouble(),
      estimatedPrice: (json['estimated_price'] as num?)?.toDouble(),
      finalPrice: (json['final_price'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }
}

BookingStatus _bookingStatusFromJson(Object? value) {
  for (final status in BookingStatus.values) {
    if (status.name == value) return status;
  }
  return BookingStatus.pending;
}
