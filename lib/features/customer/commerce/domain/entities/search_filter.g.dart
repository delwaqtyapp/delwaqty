// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_filter.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SearchFilter _$SearchFilterFromJson(Map<String, dynamic> json) =>
    _SearchFilter(
      minPrice: (json['minPrice'] as num?)?.toDouble(),
      maxPrice: (json['maxPrice'] as num?)?.toDouble(),
      minRating: (json['minRating'] as num?)?.toDouble(),
      maxDeliveryMinutes: (json['maxDeliveryMinutes'] as num?)?.toInt(),
      maxDistanceKm: (json['maxDistanceKm'] as num?)?.toDouble(),
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
      sortBy:
          $enumDecodeNullable(_$SortByEnumMap, json['sortBy']) ??
          SortBy.distance,
    );

Map<String, dynamic> _$SearchFilterToJson(_SearchFilter instance) =>
    <String, dynamic>{
      'minPrice': instance.minPrice,
      'maxPrice': instance.maxPrice,
      'minRating': instance.minRating,
      'maxDeliveryMinutes': instance.maxDeliveryMinutes,
      'maxDistanceKm': instance.maxDistanceKm,
      'tags': instance.tags,
      'sortBy': _$SortByEnumMap[instance.sortBy]!,
    };

const _$SortByEnumMap = {
  SortBy.distance: 'distance',
  SortBy.rating: 'rating',
  SortBy.deliveryTime: 'delivery_time',
  SortBy.priceLow: 'price_low',
  SortBy.priceHigh: 'price_high',
  SortBy.popularity: 'popularity',
};
