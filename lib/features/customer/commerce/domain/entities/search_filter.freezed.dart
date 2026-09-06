// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'search_filter.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SearchFilter {

 double? get minPrice; double? get maxPrice; double? get minRating; int? get maxDeliveryMinutes; double? get maxDistanceKm; List<String> get tags; SortBy get sortBy;
/// Create a copy of SearchFilter
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SearchFilterCopyWith<SearchFilter> get copyWith => _$SearchFilterCopyWithImpl<SearchFilter>(this as SearchFilter, _$identity);

  /// Serializes this SearchFilter to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SearchFilter;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SearchFilter&&(identical(other.minPrice, _this.minPrice) || other.minPrice == _this.minPrice)&&(identical(other.maxPrice, _this.maxPrice) || other.maxPrice == _this.maxPrice)&&(identical(other.minRating, _this.minRating) || other.minRating == _this.minRating)&&(identical(other.maxDeliveryMinutes, _this.maxDeliveryMinutes) || other.maxDeliveryMinutes == _this.maxDeliveryMinutes)&&(identical(other.maxDistanceKm, _this.maxDistanceKm) || other.maxDistanceKm == _this.maxDistanceKm)&&const DeepCollectionEquality().equals(other.tags, _this.tags)&&(identical(other.sortBy, _this.sortBy) || other.sortBy == _this.sortBy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SearchFilter;
  return Object.hash(runtimeType,_this.minPrice,_this.maxPrice,_this.minRating,_this.maxDeliveryMinutes,_this.maxDistanceKm,const DeepCollectionEquality().hash(_this.tags),_this.sortBy);
}

@override
String toString() {
  final _this = this as SearchFilter;
  return 'SearchFilter(minPrice: ${_this.minPrice}, maxPrice: ${_this.maxPrice}, minRating: ${_this.minRating}, maxDeliveryMinutes: ${_this.maxDeliveryMinutes}, maxDistanceKm: ${_this.maxDistanceKm}, tags: ${_this.tags}, sortBy: ${_this.sortBy})';
}


}

/// @nodoc
abstract mixin class $SearchFilterCopyWith<$Res>  {
  factory $SearchFilterCopyWith(SearchFilter value, $Res Function(SearchFilter) _then) = _$SearchFilterCopyWithImpl;
@useResult
$Res call({
 double? minPrice, double? maxPrice, double? minRating, int? maxDeliveryMinutes, double? maxDistanceKm, List<String> tags, SortBy sortBy
});




}
/// @nodoc
class _$SearchFilterCopyWithImpl<$Res>
    implements $SearchFilterCopyWith<$Res> {
  _$SearchFilterCopyWithImpl(this._self, this._then);

  final SearchFilter _self;
  final $Res Function(SearchFilter) _then;

/// Create a copy of SearchFilter
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? minPrice = freezed,Object? maxPrice = freezed,Object? minRating = freezed,Object? maxDeliveryMinutes = freezed,Object? maxDistanceKm = freezed,Object? tags = null,Object? sortBy = null,}) {
  return _then(SearchFilter(
minPrice: freezed == minPrice ? _self.minPrice : minPrice // ignore: cast_nullable_to_non_nullable
as double?,maxPrice: freezed == maxPrice ? _self.maxPrice : maxPrice // ignore: cast_nullable_to_non_nullable
as double?,minRating: freezed == minRating ? _self.minRating : minRating // ignore: cast_nullable_to_non_nullable
as double?,maxDeliveryMinutes: freezed == maxDeliveryMinutes ? _self.maxDeliveryMinutes : maxDeliveryMinutes // ignore: cast_nullable_to_non_nullable
as int?,maxDistanceKm: freezed == maxDistanceKm ? _self.maxDistanceKm : maxDistanceKm // ignore: cast_nullable_to_non_nullable
as double?,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,sortBy: null == sortBy ? _self.sortBy : sortBy // ignore: cast_nullable_to_non_nullable
as SortBy,
  ));
}

}


/// Adds pattern-matching-related methods to [SearchFilter].
extension SearchFilterPatterns on SearchFilter {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SearchFilter value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SearchFilter() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SearchFilter value)  $default,){
final _that = this;
switch (_that) {
case _SearchFilter():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SearchFilter value)?  $default,){
final _that = this;
switch (_that) {
case _SearchFilter() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double? minPrice,  double? maxPrice,  double? minRating,  int? maxDeliveryMinutes,  double? maxDistanceKm,  List<String> tags,  SortBy sortBy)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SearchFilter() when $default != null:
return $default(_that.minPrice,_that.maxPrice,_that.minRating,_that.maxDeliveryMinutes,_that.maxDistanceKm,_that.tags,_that.sortBy);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double? minPrice,  double? maxPrice,  double? minRating,  int? maxDeliveryMinutes,  double? maxDistanceKm,  List<String> tags,  SortBy sortBy)  $default,) {final _that = this;
switch (_that) {
case _SearchFilter():
return $default(_that.minPrice,_that.maxPrice,_that.minRating,_that.maxDeliveryMinutes,_that.maxDistanceKm,_that.tags,_that.sortBy);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double? minPrice,  double? maxPrice,  double? minRating,  int? maxDeliveryMinutes,  double? maxDistanceKm,  List<String> tags,  SortBy sortBy)?  $default,) {final _that = this;
switch (_that) {
case _SearchFilter() when $default != null:
return $default(_that.minPrice,_that.maxPrice,_that.minRating,_that.maxDeliveryMinutes,_that.maxDistanceKm,_that.tags,_that.sortBy);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SearchFilter implements SearchFilter {
  const _SearchFilter({this.minPrice, this.maxPrice, this.minRating, this.maxDeliveryMinutes, this.maxDistanceKm,  List<String> tags = const [], this.sortBy = SortBy.distance}): _tags = tags;
  factory _SearchFilter.fromJson(Map<String, dynamic> json) => _$SearchFilterFromJson(json);

@override final  double? minPrice;
@override final  double? maxPrice;
@override final  double? minRating;
@override final  int? maxDeliveryMinutes;
@override final  double? maxDistanceKm;
 final  List<String> _tags;
@override@JsonKey() List<String> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

@override@JsonKey() final  SortBy sortBy;

/// Create a copy of SearchFilter
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SearchFilterCopyWith<_SearchFilter> get copyWith => __$SearchFilterCopyWithImpl<_SearchFilter>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SearchFilterToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SearchFilter&&(identical(other.minPrice, minPrice) || other.minPrice == minPrice)&&(identical(other.maxPrice, maxPrice) || other.maxPrice == maxPrice)&&(identical(other.minRating, minRating) || other.minRating == minRating)&&(identical(other.maxDeliveryMinutes, maxDeliveryMinutes) || other.maxDeliveryMinutes == maxDeliveryMinutes)&&(identical(other.maxDistanceKm, maxDistanceKm) || other.maxDistanceKm == maxDistanceKm)&&const DeepCollectionEquality().equals(other.tags, _tags)&&(identical(other.sortBy, sortBy) || other.sortBy == sortBy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,minPrice,maxPrice,minRating,maxDeliveryMinutes,maxDistanceKm,const DeepCollectionEquality().hash(_tags),sortBy);
}

@override
String toString() {
    return 'SearchFilter(minPrice: $minPrice, maxPrice: $maxPrice, minRating: $minRating, maxDeliveryMinutes: $maxDeliveryMinutes, maxDistanceKm: $maxDistanceKm, tags: $tags, sortBy: $sortBy)';
}


}

/// @nodoc
abstract mixin class _$SearchFilterCopyWith<$Res> implements $SearchFilterCopyWith<$Res> {
  factory _$SearchFilterCopyWith(_SearchFilter value, $Res Function(_SearchFilter) _then) = __$SearchFilterCopyWithImpl;
@override @useResult
$Res call({
 double? minPrice, double? maxPrice, double? minRating, int? maxDeliveryMinutes, double? maxDistanceKm, List<String> tags, SortBy sortBy
});




}
/// @nodoc
class __$SearchFilterCopyWithImpl<$Res>
    implements _$SearchFilterCopyWith<$Res> {
  __$SearchFilterCopyWithImpl(this._self, this._then);

  final _SearchFilter _self;
  final $Res Function(_SearchFilter) _then;

/// Create a copy of SearchFilter
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? minPrice = freezed,Object? maxPrice = freezed,Object? minRating = freezed,Object? maxDeliveryMinutes = freezed,Object? maxDistanceKm = freezed,Object? tags = null,Object? sortBy = null,}) {
  return _then(_SearchFilter(
minPrice: freezed == minPrice ? _self.minPrice : minPrice // ignore: cast_nullable_to_non_nullable
as double?,maxPrice: freezed == maxPrice ? _self.maxPrice : maxPrice // ignore: cast_nullable_to_non_nullable
as double?,minRating: freezed == minRating ? _self.minRating : minRating // ignore: cast_nullable_to_non_nullable
as double?,maxDeliveryMinutes: freezed == maxDeliveryMinutes ? _self.maxDeliveryMinutes : maxDeliveryMinutes // ignore: cast_nullable_to_non_nullable
as int?,maxDistanceKm: freezed == maxDistanceKm ? _self.maxDistanceKm : maxDistanceKm // ignore: cast_nullable_to_non_nullable
as double?,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,sortBy: null == sortBy ? _self.sortBy : sortBy // ignore: cast_nullable_to_non_nullable
as SortBy,
  ));
}


}

// dart format on
