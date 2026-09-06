// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'review.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Review {

 String get id; String get merchantId; String get userId; String? get userName; String? get productId; String? get orderId; double get rating; String? get comment; List<String> get imageUrls; DateTime? get createdAt; DateTime? get updatedAt;
/// Create a copy of Review
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReviewCopyWith<Review> get copyWith => _$ReviewCopyWithImpl<Review>(this as Review, _$identity);

  /// Serializes this Review to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Review;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Review&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.merchantId, _this.merchantId) || other.merchantId == _this.merchantId)&&(identical(other.userId, _this.userId) || other.userId == _this.userId)&&(identical(other.userName, _this.userName) || other.userName == _this.userName)&&(identical(other.productId, _this.productId) || other.productId == _this.productId)&&(identical(other.orderId, _this.orderId) || other.orderId == _this.orderId)&&(identical(other.rating, _this.rating) || other.rating == _this.rating)&&(identical(other.comment, _this.comment) || other.comment == _this.comment)&&const DeepCollectionEquality().equals(other.imageUrls, _this.imageUrls)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Review;
  return Object.hash(runtimeType,_this.id,_this.merchantId,_this.userId,_this.userName,_this.productId,_this.orderId,_this.rating,_this.comment,const DeepCollectionEquality().hash(_this.imageUrls),_this.createdAt,_this.updatedAt);
}

@override
String toString() {
  final _this = this as Review;
  return 'Review(id: ${_this.id}, merchantId: ${_this.merchantId}, userId: ${_this.userId}, userName: ${_this.userName}, productId: ${_this.productId}, orderId: ${_this.orderId}, rating: ${_this.rating}, comment: ${_this.comment}, imageUrls: ${_this.imageUrls}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $ReviewCopyWith<$Res>  {
  factory $ReviewCopyWith(Review value, $Res Function(Review) _then) = _$ReviewCopyWithImpl;
@useResult
$Res call({
 String id, String merchantId, String userId, String? userName, String? productId, String? orderId, double rating, String? comment, List<String> imageUrls, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class _$ReviewCopyWithImpl<$Res>
    implements $ReviewCopyWith<$Res> {
  _$ReviewCopyWithImpl(this._self, this._then);

  final Review _self;
  final $Res Function(Review) _then;

/// Create a copy of Review
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? merchantId = null,Object? userId = null,Object? userName = freezed,Object? productId = freezed,Object? orderId = freezed,Object? rating = null,Object? comment = freezed,Object? imageUrls = null,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(Review(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,merchantId: null == merchantId ? _self.merchantId : merchantId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,userName: freezed == userName ? _self.userName : userName // ignore: cast_nullable_to_non_nullable
as String?,productId: freezed == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String?,orderId: freezed == orderId ? _self.orderId : orderId // ignore: cast_nullable_to_non_nullable
as String?,rating: null == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double,comment: freezed == comment ? _self.comment : comment // ignore: cast_nullable_to_non_nullable
as String?,imageUrls: null == imageUrls ? _self.imageUrls : imageUrls // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Review].
extension ReviewPatterns on Review {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Review value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Review() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Review value)  $default,){
final _that = this;
switch (_that) {
case _Review():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Review value)?  $default,){
final _that = this;
switch (_that) {
case _Review() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String merchantId,  String userId,  String? userName,  String? productId,  String? orderId,  double rating,  String? comment,  List<String> imageUrls,  DateTime? createdAt,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Review() when $default != null:
return $default(_that.id,_that.merchantId,_that.userId,_that.userName,_that.productId,_that.orderId,_that.rating,_that.comment,_that.imageUrls,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String merchantId,  String userId,  String? userName,  String? productId,  String? orderId,  double rating,  String? comment,  List<String> imageUrls,  DateTime? createdAt,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Review():
return $default(_that.id,_that.merchantId,_that.userId,_that.userName,_that.productId,_that.orderId,_that.rating,_that.comment,_that.imageUrls,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String merchantId,  String userId,  String? userName,  String? productId,  String? orderId,  double rating,  String? comment,  List<String> imageUrls,  DateTime? createdAt,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Review() when $default != null:
return $default(_that.id,_that.merchantId,_that.userId,_that.userName,_that.productId,_that.orderId,_that.rating,_that.comment,_that.imageUrls,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Review implements Review {
  const _Review({required this.id, required this.merchantId, required this.userId, this.userName, this.productId, this.orderId, required this.rating, this.comment,  List<String> imageUrls = const [], this.createdAt, this.updatedAt}): _imageUrls = imageUrls;
  factory _Review.fromJson(Map<String, dynamic> json) => _$ReviewFromJson(json);

@override final  String id;
@override final  String merchantId;
@override final  String userId;
@override final  String? userName;
@override final  String? productId;
@override final  String? orderId;
@override final  double rating;
@override final  String? comment;
 final  List<String> _imageUrls;
@override@JsonKey() List<String> get imageUrls {
  if (_imageUrls is EqualUnmodifiableListView) return _imageUrls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_imageUrls);
}

@override final  DateTime? createdAt;
@override final  DateTime? updatedAt;

/// Create a copy of Review
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReviewCopyWith<_Review> get copyWith => __$ReviewCopyWithImpl<_Review>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReviewToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Review&&(identical(other.id, id) || other.id == id)&&(identical(other.merchantId, merchantId) || other.merchantId == merchantId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.userName, userName) || other.userName == userName)&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.orderId, orderId) || other.orderId == orderId)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.comment, comment) || other.comment == comment)&&const DeepCollectionEquality().equals(other.imageUrls, _imageUrls)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,merchantId,userId,userName,productId,orderId,rating,comment,const DeepCollectionEquality().hash(_imageUrls),createdAt,updatedAt);
}

@override
String toString() {
    return 'Review(id: $id, merchantId: $merchantId, userId: $userId, userName: $userName, productId: $productId, orderId: $orderId, rating: $rating, comment: $comment, imageUrls: $imageUrls, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ReviewCopyWith<$Res> implements $ReviewCopyWith<$Res> {
  factory _$ReviewCopyWith(_Review value, $Res Function(_Review) _then) = __$ReviewCopyWithImpl;
@override @useResult
$Res call({
 String id, String merchantId, String userId, String? userName, String? productId, String? orderId, double rating, String? comment, List<String> imageUrls, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class __$ReviewCopyWithImpl<$Res>
    implements _$ReviewCopyWith<$Res> {
  __$ReviewCopyWithImpl(this._self, this._then);

  final _Review _self;
  final $Res Function(_Review) _then;

/// Create a copy of Review
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? merchantId = null,Object? userId = null,Object? userName = freezed,Object? productId = freezed,Object? orderId = freezed,Object? rating = null,Object? comment = freezed,Object? imageUrls = null,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_Review(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,merchantId: null == merchantId ? _self.merchantId : merchantId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,userName: freezed == userName ? _self.userName : userName // ignore: cast_nullable_to_non_nullable
as String?,productId: freezed == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String?,orderId: freezed == orderId ? _self.orderId : orderId // ignore: cast_nullable_to_non_nullable
as String?,rating: null == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double,comment: freezed == comment ? _self.comment : comment // ignore: cast_nullable_to_non_nullable
as String?,imageUrls: null == imageUrls ? _self._imageUrls : imageUrls // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$ReviewSummary {

 double get averageRating; int get totalReviews; int get fiveStarCount; int get fourStarCount; int get threeStarCount; int get twoStarCount; int get oneStarCount;
/// Create a copy of ReviewSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReviewSummaryCopyWith<ReviewSummary> get copyWith => _$ReviewSummaryCopyWithImpl<ReviewSummary>(this as ReviewSummary, _$identity);

  /// Serializes this ReviewSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ReviewSummary;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReviewSummary&&(identical(other.averageRating, _this.averageRating) || other.averageRating == _this.averageRating)&&(identical(other.totalReviews, _this.totalReviews) || other.totalReviews == _this.totalReviews)&&(identical(other.fiveStarCount, _this.fiveStarCount) || other.fiveStarCount == _this.fiveStarCount)&&(identical(other.fourStarCount, _this.fourStarCount) || other.fourStarCount == _this.fourStarCount)&&(identical(other.threeStarCount, _this.threeStarCount) || other.threeStarCount == _this.threeStarCount)&&(identical(other.twoStarCount, _this.twoStarCount) || other.twoStarCount == _this.twoStarCount)&&(identical(other.oneStarCount, _this.oneStarCount) || other.oneStarCount == _this.oneStarCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ReviewSummary;
  return Object.hash(runtimeType,_this.averageRating,_this.totalReviews,_this.fiveStarCount,_this.fourStarCount,_this.threeStarCount,_this.twoStarCount,_this.oneStarCount);
}

@override
String toString() {
  final _this = this as ReviewSummary;
  return 'ReviewSummary(averageRating: ${_this.averageRating}, totalReviews: ${_this.totalReviews}, fiveStarCount: ${_this.fiveStarCount}, fourStarCount: ${_this.fourStarCount}, threeStarCount: ${_this.threeStarCount}, twoStarCount: ${_this.twoStarCount}, oneStarCount: ${_this.oneStarCount})';
}


}

/// @nodoc
abstract mixin class $ReviewSummaryCopyWith<$Res>  {
  factory $ReviewSummaryCopyWith(ReviewSummary value, $Res Function(ReviewSummary) _then) = _$ReviewSummaryCopyWithImpl;
@useResult
$Res call({
 double averageRating, int totalReviews, int fiveStarCount, int fourStarCount, int threeStarCount, int twoStarCount, int oneStarCount
});




}
/// @nodoc
class _$ReviewSummaryCopyWithImpl<$Res>
    implements $ReviewSummaryCopyWith<$Res> {
  _$ReviewSummaryCopyWithImpl(this._self, this._then);

  final ReviewSummary _self;
  final $Res Function(ReviewSummary) _then;

/// Create a copy of ReviewSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? averageRating = null,Object? totalReviews = null,Object? fiveStarCount = null,Object? fourStarCount = null,Object? threeStarCount = null,Object? twoStarCount = null,Object? oneStarCount = null,}) {
  return _then(ReviewSummary(
averageRating: null == averageRating ? _self.averageRating : averageRating // ignore: cast_nullable_to_non_nullable
as double,totalReviews: null == totalReviews ? _self.totalReviews : totalReviews // ignore: cast_nullable_to_non_nullable
as int,fiveStarCount: null == fiveStarCount ? _self.fiveStarCount : fiveStarCount // ignore: cast_nullable_to_non_nullable
as int,fourStarCount: null == fourStarCount ? _self.fourStarCount : fourStarCount // ignore: cast_nullable_to_non_nullable
as int,threeStarCount: null == threeStarCount ? _self.threeStarCount : threeStarCount // ignore: cast_nullable_to_non_nullable
as int,twoStarCount: null == twoStarCount ? _self.twoStarCount : twoStarCount // ignore: cast_nullable_to_non_nullable
as int,oneStarCount: null == oneStarCount ? _self.oneStarCount : oneStarCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ReviewSummary].
extension ReviewSummaryPatterns on ReviewSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReviewSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReviewSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReviewSummary value)  $default,){
final _that = this;
switch (_that) {
case _ReviewSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReviewSummary value)?  $default,){
final _that = this;
switch (_that) {
case _ReviewSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double averageRating,  int totalReviews,  int fiveStarCount,  int fourStarCount,  int threeStarCount,  int twoStarCount,  int oneStarCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReviewSummary() when $default != null:
return $default(_that.averageRating,_that.totalReviews,_that.fiveStarCount,_that.fourStarCount,_that.threeStarCount,_that.twoStarCount,_that.oneStarCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double averageRating,  int totalReviews,  int fiveStarCount,  int fourStarCount,  int threeStarCount,  int twoStarCount,  int oneStarCount)  $default,) {final _that = this;
switch (_that) {
case _ReviewSummary():
return $default(_that.averageRating,_that.totalReviews,_that.fiveStarCount,_that.fourStarCount,_that.threeStarCount,_that.twoStarCount,_that.oneStarCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double averageRating,  int totalReviews,  int fiveStarCount,  int fourStarCount,  int threeStarCount,  int twoStarCount,  int oneStarCount)?  $default,) {final _that = this;
switch (_that) {
case _ReviewSummary() when $default != null:
return $default(_that.averageRating,_that.totalReviews,_that.fiveStarCount,_that.fourStarCount,_that.threeStarCount,_that.twoStarCount,_that.oneStarCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReviewSummary implements ReviewSummary {
  const _ReviewSummary({required this.averageRating, required this.totalReviews, this.fiveStarCount = 0, this.fourStarCount = 0, this.threeStarCount = 0, this.twoStarCount = 0, this.oneStarCount = 0});
  factory _ReviewSummary.fromJson(Map<String, dynamic> json) => _$ReviewSummaryFromJson(json);

@override final  double averageRating;
@override final  int totalReviews;
@override@JsonKey() final  int fiveStarCount;
@override@JsonKey() final  int fourStarCount;
@override@JsonKey() final  int threeStarCount;
@override@JsonKey() final  int twoStarCount;
@override@JsonKey() final  int oneStarCount;

/// Create a copy of ReviewSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReviewSummaryCopyWith<_ReviewSummary> get copyWith => __$ReviewSummaryCopyWithImpl<_ReviewSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReviewSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReviewSummary&&(identical(other.averageRating, averageRating) || other.averageRating == averageRating)&&(identical(other.totalReviews, totalReviews) || other.totalReviews == totalReviews)&&(identical(other.fiveStarCount, fiveStarCount) || other.fiveStarCount == fiveStarCount)&&(identical(other.fourStarCount, fourStarCount) || other.fourStarCount == fourStarCount)&&(identical(other.threeStarCount, threeStarCount) || other.threeStarCount == threeStarCount)&&(identical(other.twoStarCount, twoStarCount) || other.twoStarCount == twoStarCount)&&(identical(other.oneStarCount, oneStarCount) || other.oneStarCount == oneStarCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,averageRating,totalReviews,fiveStarCount,fourStarCount,threeStarCount,twoStarCount,oneStarCount);
}

@override
String toString() {
    return 'ReviewSummary(averageRating: $averageRating, totalReviews: $totalReviews, fiveStarCount: $fiveStarCount, fourStarCount: $fourStarCount, threeStarCount: $threeStarCount, twoStarCount: $twoStarCount, oneStarCount: $oneStarCount)';
}


}

/// @nodoc
abstract mixin class _$ReviewSummaryCopyWith<$Res> implements $ReviewSummaryCopyWith<$Res> {
  factory _$ReviewSummaryCopyWith(_ReviewSummary value, $Res Function(_ReviewSummary) _then) = __$ReviewSummaryCopyWithImpl;
@override @useResult
$Res call({
 double averageRating, int totalReviews, int fiveStarCount, int fourStarCount, int threeStarCount, int twoStarCount, int oneStarCount
});




}
/// @nodoc
class __$ReviewSummaryCopyWithImpl<$Res>
    implements _$ReviewSummaryCopyWith<$Res> {
  __$ReviewSummaryCopyWithImpl(this._self, this._then);

  final _ReviewSummary _self;
  final $Res Function(_ReviewSummary) _then;

/// Create a copy of ReviewSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? averageRating = null,Object? totalReviews = null,Object? fiveStarCount = null,Object? fourStarCount = null,Object? threeStarCount = null,Object? twoStarCount = null,Object? oneStarCount = null,}) {
  return _then(_ReviewSummary(
averageRating: null == averageRating ? _self.averageRating : averageRating // ignore: cast_nullable_to_non_nullable
as double,totalReviews: null == totalReviews ? _self.totalReviews : totalReviews // ignore: cast_nullable_to_non_nullable
as int,fiveStarCount: null == fiveStarCount ? _self.fiveStarCount : fiveStarCount // ignore: cast_nullable_to_non_nullable
as int,fourStarCount: null == fourStarCount ? _self.fourStarCount : fourStarCount // ignore: cast_nullable_to_non_nullable
as int,threeStarCount: null == threeStarCount ? _self.threeStarCount : threeStarCount // ignore: cast_nullable_to_non_nullable
as int,twoStarCount: null == twoStarCount ? _self.twoStarCount : twoStarCount // ignore: cast_nullable_to_non_nullable
as int,oneStarCount: null == oneStarCount ? _self.oneStarCount : oneStarCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
