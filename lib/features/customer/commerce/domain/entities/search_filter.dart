import 'package:freezed_annotation/freezed_annotation.dart';

part 'search_filter.freezed.dart';
part 'search_filter.g.dart';

@freezed
abstract class SearchFilter with _$SearchFilter {
  const factory SearchFilter({
    double? minPrice,
    double? maxPrice,
    double? minRating,
    int? maxDeliveryMinutes,
    double? maxDistanceKm,
    @Default([]) List<String> tags,
    @Default(SortBy.distance) SortBy sortBy,
  }) = _SearchFilter;

  factory SearchFilter.fromJson(Map<String, dynamic> json) =>
      _$SearchFilterFromJson(json);
}

enum SortBy {
  @JsonValue('distance')
  distance,
  @JsonValue('rating')
  rating,
  @JsonValue('delivery_time')
  deliveryTime,
  @JsonValue('price_low')
  priceLow,
  @JsonValue('price_high')
  priceHigh,
  @JsonValue('popularity')
  popularity,
}
