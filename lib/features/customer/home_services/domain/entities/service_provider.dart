import 'package:freezed_annotation/freezed_annotation.dart';

import 'service_category.dart';

part 'service_provider.freezed.dart';

@freezed
abstract class ServiceProvider with _$ServiceProvider {
  const factory ServiceProvider({
    required String id,
    @Default('') String userId,
    required String name,
    required ServiceCategoryType categoryType,
    String? description,
    String? profileImageUrl,
    @Default(0.0) double rating,
    @Default(0) int ratingCount,
    @Default(false) bool isVerified,
    @Default(false) bool isAvailable,
    double? hourlyRate,
    double? fixedPriceMin,
    double? fixedPriceMax,
    String? city,
    double? latitude,
    double? longitude,
    @Default([]) List<String> tags,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _ServiceProvider;

  factory ServiceProvider.fromJson(Map<String, dynamic> json) {
    return ServiceProvider(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      categoryType: serviceCategoryTypeFromJson(json['category_type']),
      description: json['description'] as String?,
      profileImageUrl: json['profile_image_url'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      isVerified: json['is_verified'] as bool? ?? false,
      isAvailable: json['is_available'] as bool? ?? false,
      // 397: rows read through service_providers_with_effective_pricing
      // carry the resolved values; fall back to the raw columns for any
      // other source. The displayed price is always the booking truth.
      hourlyRate:
          (json['effective_hourly_rate'] as num?)?.toDouble() ??
          (json['hourly_rate'] as num?)?.toDouble(),
      fixedPriceMin:
          (json['effective_fixed_price_min'] as num?)?.toDouble() ??
          (json['fixed_price_min'] as num?)?.toDouble(),
      fixedPriceMax:
          (json['effective_fixed_price_max'] as num?)?.toDouble() ??
          (json['fixed_price_max'] as num?)?.toDouble(),
      city: json['city'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      tags:
          (json['tags'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}
