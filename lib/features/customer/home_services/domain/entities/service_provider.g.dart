// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_provider.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ServiceProvider _$ServiceProviderFromJson(Map<String, dynamic> json) =>
    _ServiceProvider(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String,
      categoryType: _$ServiceCategoryTypeEnumMap.entries
          .firstWhere(
            (e) => e.value == json['category_type'],
            orElse: () => const MapEntry(ServiceCategoryType.other, 'other'),
          )
          .key,
      description: json['description'] as String?,
      profileImageUrl: json['profile_image_url'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      isVerified: json['is_verified'] as bool? ?? false,
      isAvailable: json['is_available'] as bool? ?? false,
      hourlyRate: (json['hourly_rate'] as num?)?.toDouble(),
      fixedPriceMin: (json['fixed_price_min'] as num?)?.toDouble(),
      fixedPriceMax: (json['fixed_price_max'] as num?)?.toDouble(),
      city: json['city'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$ServiceProviderToJson(_ServiceProvider instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'name': instance.name,
      'category_type': _$ServiceCategoryTypeEnumMap[instance.categoryType]!,
      'description': instance.description,
      'profile_image_url': instance.profileImageUrl,
      'rating': instance.rating,
      'rating_count': instance.ratingCount,
      'is_verified': instance.isVerified,
      'is_available': instance.isAvailable,
      'hourly_rate': instance.hourlyRate,
      'fixed_price_min': instance.fixedPriceMin,
      'fixed_price_max': instance.fixedPriceMax,
      'city': instance.city,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'tags': instance.tags,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

const _$ServiceCategoryTypeEnumMap = {
  ServiceCategoryType.plumbing: 'plumbing',
  ServiceCategoryType.electrical: 'electrical',
  ServiceCategoryType.carpentry: 'carpentry',
  ServiceCategoryType.acMaintenance: 'acMaintenance',
  ServiceCategoryType.painting: 'painting',
  ServiceCategoryType.cleaning: 'cleaning',
  ServiceCategoryType.pestControl: 'pestControl',
  ServiceCategoryType.applianceRepair: 'applianceRepair',
  ServiceCategoryType.pipeChange: 'pipeChange',
  ServiceCategoryType.plastering: 'plastering',
  ServiceCategoryType.carpetCleaning: 'carpetCleaning',
  ServiceCategoryType.dishRepair: 'dishRepair',
  ServiceCategoryType.teacher: 'teacher',
  ServiceCategoryType.doctor: 'doctor',
  ServiceCategoryType.nurse: 'nurse',
  ServiceCategoryType.barber: 'barber',
  ServiceCategoryType.other: 'other',
};
