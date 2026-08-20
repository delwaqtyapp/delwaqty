// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'search_filter.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

SearchFilter _$SearchFilterFromJson(Map<String, dynamic> json) {
  return _SearchFilter.fromJson(json);
}

/// @nodoc
mixin _$SearchFilter {
  double? get minPrice => throw _privateConstructorUsedError;
  double? get maxPrice => throw _privateConstructorUsedError;
  double? get minRating => throw _privateConstructorUsedError;
  int? get maxDeliveryMinutes => throw _privateConstructorUsedError;
  double? get maxDistanceKm => throw _privateConstructorUsedError;
  List<String> get tags => throw _privateConstructorUsedError;
  SortBy get sortBy => throw _privateConstructorUsedError;

  /// Serializes this SearchFilter to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SearchFilter
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SearchFilterCopyWith<SearchFilter> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SearchFilterCopyWith<$Res> {
  factory $SearchFilterCopyWith(
    SearchFilter value,
    $Res Function(SearchFilter) then,
  ) = _$SearchFilterCopyWithImpl<$Res, SearchFilter>;
  @useResult
  $Res call({
    double? minPrice,
    double? maxPrice,
    double? minRating,
    int? maxDeliveryMinutes,
    double? maxDistanceKm,
    List<String> tags,
    SortBy sortBy,
  });
}

/// @nodoc
class _$SearchFilterCopyWithImpl<$Res, $Val extends SearchFilter>
    implements $SearchFilterCopyWith<$Res> {
  _$SearchFilterCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SearchFilter
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? minPrice = freezed,
    Object? maxPrice = freezed,
    Object? minRating = freezed,
    Object? maxDeliveryMinutes = freezed,
    Object? maxDistanceKm = freezed,
    Object? tags = null,
    Object? sortBy = null,
  }) {
    return _then(
      _value.copyWith(
            minPrice: freezed == minPrice
                ? _value.minPrice
                : minPrice // ignore: cast_nullable_to_non_nullable
                      as double?,
            maxPrice: freezed == maxPrice
                ? _value.maxPrice
                : maxPrice // ignore: cast_nullable_to_non_nullable
                      as double?,
            minRating: freezed == minRating
                ? _value.minRating
                : minRating // ignore: cast_nullable_to_non_nullable
                      as double?,
            maxDeliveryMinutes: freezed == maxDeliveryMinutes
                ? _value.maxDeliveryMinutes
                : maxDeliveryMinutes // ignore: cast_nullable_to_non_nullable
                      as int?,
            maxDistanceKm: freezed == maxDistanceKm
                ? _value.maxDistanceKm
                : maxDistanceKm // ignore: cast_nullable_to_non_nullable
                      as double?,
            tags: null == tags
                ? _value.tags
                : tags // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            sortBy: null == sortBy
                ? _value.sortBy
                : sortBy // ignore: cast_nullable_to_non_nullable
                      as SortBy,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SearchFilterImplCopyWith<$Res>
    implements $SearchFilterCopyWith<$Res> {
  factory _$$SearchFilterImplCopyWith(
    _$SearchFilterImpl value,
    $Res Function(_$SearchFilterImpl) then,
  ) = __$$SearchFilterImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    double? minPrice,
    double? maxPrice,
    double? minRating,
    int? maxDeliveryMinutes,
    double? maxDistanceKm,
    List<String> tags,
    SortBy sortBy,
  });
}

/// @nodoc
class __$$SearchFilterImplCopyWithImpl<$Res>
    extends _$SearchFilterCopyWithImpl<$Res, _$SearchFilterImpl>
    implements _$$SearchFilterImplCopyWith<$Res> {
  __$$SearchFilterImplCopyWithImpl(
    _$SearchFilterImpl _value,
    $Res Function(_$SearchFilterImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SearchFilter
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? minPrice = freezed,
    Object? maxPrice = freezed,
    Object? minRating = freezed,
    Object? maxDeliveryMinutes = freezed,
    Object? maxDistanceKm = freezed,
    Object? tags = null,
    Object? sortBy = null,
  }) {
    return _then(
      _$SearchFilterImpl(
        minPrice: freezed == minPrice
            ? _value.minPrice
            : minPrice // ignore: cast_nullable_to_non_nullable
                  as double?,
        maxPrice: freezed == maxPrice
            ? _value.maxPrice
            : maxPrice // ignore: cast_nullable_to_non_nullable
                  as double?,
        minRating: freezed == minRating
            ? _value.minRating
            : minRating // ignore: cast_nullable_to_non_nullable
                  as double?,
        maxDeliveryMinutes: freezed == maxDeliveryMinutes
            ? _value.maxDeliveryMinutes
            : maxDeliveryMinutes // ignore: cast_nullable_to_non_nullable
                  as int?,
        maxDistanceKm: freezed == maxDistanceKm
            ? _value.maxDistanceKm
            : maxDistanceKm // ignore: cast_nullable_to_non_nullable
                  as double?,
        tags: null == tags
            ? _value._tags
            : tags // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        sortBy: null == sortBy
            ? _value.sortBy
            : sortBy // ignore: cast_nullable_to_non_nullable
                  as SortBy,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SearchFilterImpl implements _SearchFilter {
  const _$SearchFilterImpl({
    this.minPrice,
    this.maxPrice,
    this.minRating,
    this.maxDeliveryMinutes,
    this.maxDistanceKm,
    final List<String> tags = const [],
    this.sortBy = SortBy.distance,
  }) : _tags = tags;

  factory _$SearchFilterImpl.fromJson(Map<String, dynamic> json) =>
      _$$SearchFilterImplFromJson(json);

  @override
  final double? minPrice;
  @override
  final double? maxPrice;
  @override
  final double? minRating;
  @override
  final int? maxDeliveryMinutes;
  @override
  final double? maxDistanceKm;
  final List<String> _tags;
  @override
  @JsonKey()
  List<String> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  @override
  @JsonKey()
  final SortBy sortBy;

  @override
  String toString() {
    return 'SearchFilter(minPrice: $minPrice, maxPrice: $maxPrice, minRating: $minRating, maxDeliveryMinutes: $maxDeliveryMinutes, maxDistanceKm: $maxDistanceKm, tags: $tags, sortBy: $sortBy)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SearchFilterImpl &&
            (identical(other.minPrice, minPrice) ||
                other.minPrice == minPrice) &&
            (identical(other.maxPrice, maxPrice) ||
                other.maxPrice == maxPrice) &&
            (identical(other.minRating, minRating) ||
                other.minRating == minRating) &&
            (identical(other.maxDeliveryMinutes, maxDeliveryMinutes) ||
                other.maxDeliveryMinutes == maxDeliveryMinutes) &&
            (identical(other.maxDistanceKm, maxDistanceKm) ||
                other.maxDistanceKm == maxDistanceKm) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.sortBy, sortBy) || other.sortBy == sortBy));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    minPrice,
    maxPrice,
    minRating,
    maxDeliveryMinutes,
    maxDistanceKm,
    const DeepCollectionEquality().hash(_tags),
    sortBy,
  );

  /// Create a copy of SearchFilter
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SearchFilterImplCopyWith<_$SearchFilterImpl> get copyWith =>
      __$$SearchFilterImplCopyWithImpl<_$SearchFilterImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SearchFilterImplToJson(this);
  }
}

abstract class _SearchFilter implements SearchFilter {
  const factory _SearchFilter({
    final double? minPrice,
    final double? maxPrice,
    final double? minRating,
    final int? maxDeliveryMinutes,
    final double? maxDistanceKm,
    final List<String> tags,
    final SortBy sortBy,
  }) = _$SearchFilterImpl;

  factory _SearchFilter.fromJson(Map<String, dynamic> json) =
      _$SearchFilterImpl.fromJson;

  @override
  double? get minPrice;
  @override
  double? get maxPrice;
  @override
  double? get minRating;
  @override
  int? get maxDeliveryMinutes;
  @override
  double? get maxDistanceKm;
  @override
  List<String> get tags;
  @override
  SortBy get sortBy;

  /// Create a copy of SearchFilter
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SearchFilterImplCopyWith<_$SearchFilterImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
