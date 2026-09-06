// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'coupon.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Coupon {

 String get id; String get code; String? get description; CouponType get type; double get value; double? get minimumOrder; double? get maximumDiscount; String? get merchantId; String? get branchId; String? get productId; String? get categoryId; int? get usageLimit; int? get usedCount; DateTime? get expiresAt; bool get isActive; DateTime? get createdAt;
/// Create a copy of Coupon
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CouponCopyWith<Coupon> get copyWith => _$CouponCopyWithImpl<Coupon>(this as Coupon, _$identity);

  /// Serializes this Coupon to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Coupon;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Coupon&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.value, _this.value) || other.value == _this.value)&&(identical(other.minimumOrder, _this.minimumOrder) || other.minimumOrder == _this.minimumOrder)&&(identical(other.maximumDiscount, _this.maximumDiscount) || other.maximumDiscount == _this.maximumDiscount)&&(identical(other.merchantId, _this.merchantId) || other.merchantId == _this.merchantId)&&(identical(other.branchId, _this.branchId) || other.branchId == _this.branchId)&&(identical(other.productId, _this.productId) || other.productId == _this.productId)&&(identical(other.categoryId, _this.categoryId) || other.categoryId == _this.categoryId)&&(identical(other.usageLimit, _this.usageLimit) || other.usageLimit == _this.usageLimit)&&(identical(other.usedCount, _this.usedCount) || other.usedCount == _this.usedCount)&&(identical(other.expiresAt, _this.expiresAt) || other.expiresAt == _this.expiresAt)&&(identical(other.isActive, _this.isActive) || other.isActive == _this.isActive)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Coupon;
  return Object.hash(runtimeType,_this.id,_this.code,_this.description,_this.type,_this.value,_this.minimumOrder,_this.maximumDiscount,_this.merchantId,_this.branchId,_this.productId,_this.categoryId,_this.usageLimit,_this.usedCount,_this.expiresAt,_this.isActive,_this.createdAt);
}

@override
String toString() {
  final _this = this as Coupon;
  return 'Coupon(id: ${_this.id}, code: ${_this.code}, description: ${_this.description}, type: ${_this.type}, value: ${_this.value}, minimumOrder: ${_this.minimumOrder}, maximumDiscount: ${_this.maximumDiscount}, merchantId: ${_this.merchantId}, branchId: ${_this.branchId}, productId: ${_this.productId}, categoryId: ${_this.categoryId}, usageLimit: ${_this.usageLimit}, usedCount: ${_this.usedCount}, expiresAt: ${_this.expiresAt}, isActive: ${_this.isActive}, createdAt: ${_this.createdAt})';
}


}

/// @nodoc
abstract mixin class $CouponCopyWith<$Res>  {
  factory $CouponCopyWith(Coupon value, $Res Function(Coupon) _then) = _$CouponCopyWithImpl;
@useResult
$Res call({
 String id, String code, String? description, CouponType type, double value, double? minimumOrder, double? maximumDiscount, String? merchantId, String? branchId, String? productId, String? categoryId, int? usageLimit, int? usedCount, DateTime? expiresAt, bool isActive, DateTime? createdAt
});




}
/// @nodoc
class _$CouponCopyWithImpl<$Res>
    implements $CouponCopyWith<$Res> {
  _$CouponCopyWithImpl(this._self, this._then);

  final Coupon _self;
  final $Res Function(Coupon) _then;

/// Create a copy of Coupon
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? code = null,Object? description = freezed,Object? type = null,Object? value = null,Object? minimumOrder = freezed,Object? maximumDiscount = freezed,Object? merchantId = freezed,Object? branchId = freezed,Object? productId = freezed,Object? categoryId = freezed,Object? usageLimit = freezed,Object? usedCount = freezed,Object? expiresAt = freezed,Object? isActive = null,Object? createdAt = freezed,}) {
  return _then(Coupon(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CouponType,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as double,minimumOrder: freezed == minimumOrder ? _self.minimumOrder : minimumOrder // ignore: cast_nullable_to_non_nullable
as double?,maximumDiscount: freezed == maximumDiscount ? _self.maximumDiscount : maximumDiscount // ignore: cast_nullable_to_non_nullable
as double?,merchantId: freezed == merchantId ? _self.merchantId : merchantId // ignore: cast_nullable_to_non_nullable
as String?,branchId: freezed == branchId ? _self.branchId : branchId // ignore: cast_nullable_to_non_nullable
as String?,productId: freezed == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String?,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,usageLimit: freezed == usageLimit ? _self.usageLimit : usageLimit // ignore: cast_nullable_to_non_nullable
as int?,usedCount: freezed == usedCount ? _self.usedCount : usedCount // ignore: cast_nullable_to_non_nullable
as int?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Coupon].
extension CouponPatterns on Coupon {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Coupon value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Coupon() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Coupon value)  $default,){
final _that = this;
switch (_that) {
case _Coupon():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Coupon value)?  $default,){
final _that = this;
switch (_that) {
case _Coupon() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String code,  String? description,  CouponType type,  double value,  double? minimumOrder,  double? maximumDiscount,  String? merchantId,  String? branchId,  String? productId,  String? categoryId,  int? usageLimit,  int? usedCount,  DateTime? expiresAt,  bool isActive,  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Coupon() when $default != null:
return $default(_that.id,_that.code,_that.description,_that.type,_that.value,_that.minimumOrder,_that.maximumDiscount,_that.merchantId,_that.branchId,_that.productId,_that.categoryId,_that.usageLimit,_that.usedCount,_that.expiresAt,_that.isActive,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String code,  String? description,  CouponType type,  double value,  double? minimumOrder,  double? maximumDiscount,  String? merchantId,  String? branchId,  String? productId,  String? categoryId,  int? usageLimit,  int? usedCount,  DateTime? expiresAt,  bool isActive,  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _Coupon():
return $default(_that.id,_that.code,_that.description,_that.type,_that.value,_that.minimumOrder,_that.maximumDiscount,_that.merchantId,_that.branchId,_that.productId,_that.categoryId,_that.usageLimit,_that.usedCount,_that.expiresAt,_that.isActive,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String code,  String? description,  CouponType type,  double value,  double? minimumOrder,  double? maximumDiscount,  String? merchantId,  String? branchId,  String? productId,  String? categoryId,  int? usageLimit,  int? usedCount,  DateTime? expiresAt,  bool isActive,  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Coupon() when $default != null:
return $default(_that.id,_that.code,_that.description,_that.type,_that.value,_that.minimumOrder,_that.maximumDiscount,_that.merchantId,_that.branchId,_that.productId,_that.categoryId,_that.usageLimit,_that.usedCount,_that.expiresAt,_that.isActive,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Coupon implements Coupon {
  const _Coupon({required this.id, required this.code, this.description, required this.type, required this.value, this.minimumOrder, this.maximumDiscount, this.merchantId, this.branchId, this.productId, this.categoryId, this.usageLimit, this.usedCount, this.expiresAt, this.isActive = true, this.createdAt});
  factory _Coupon.fromJson(Map<String, dynamic> json) => _$CouponFromJson(json);

@override final  String id;
@override final  String code;
@override final  String? description;
@override final  CouponType type;
@override final  double value;
@override final  double? minimumOrder;
@override final  double? maximumDiscount;
@override final  String? merchantId;
@override final  String? branchId;
@override final  String? productId;
@override final  String? categoryId;
@override final  int? usageLimit;
@override final  int? usedCount;
@override final  DateTime? expiresAt;
@override@JsonKey() final  bool isActive;
@override final  DateTime? createdAt;

/// Create a copy of Coupon
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CouponCopyWith<_Coupon> get copyWith => __$CouponCopyWithImpl<_Coupon>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CouponToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Coupon&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.description, description) || other.description == description)&&(identical(other.type, type) || other.type == type)&&(identical(other.value, value) || other.value == value)&&(identical(other.minimumOrder, minimumOrder) || other.minimumOrder == minimumOrder)&&(identical(other.maximumDiscount, maximumDiscount) || other.maximumDiscount == maximumDiscount)&&(identical(other.merchantId, merchantId) || other.merchantId == merchantId)&&(identical(other.branchId, branchId) || other.branchId == branchId)&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.usageLimit, usageLimit) || other.usageLimit == usageLimit)&&(identical(other.usedCount, usedCount) || other.usedCount == usedCount)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,code,description,type,value,minimumOrder,maximumDiscount,merchantId,branchId,productId,categoryId,usageLimit,usedCount,expiresAt,isActive,createdAt);
}

@override
String toString() {
    return 'Coupon(id: $id, code: $code, description: $description, type: $type, value: $value, minimumOrder: $minimumOrder, maximumDiscount: $maximumDiscount, merchantId: $merchantId, branchId: $branchId, productId: $productId, categoryId: $categoryId, usageLimit: $usageLimit, usedCount: $usedCount, expiresAt: $expiresAt, isActive: $isActive, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$CouponCopyWith<$Res> implements $CouponCopyWith<$Res> {
  factory _$CouponCopyWith(_Coupon value, $Res Function(_Coupon) _then) = __$CouponCopyWithImpl;
@override @useResult
$Res call({
 String id, String code, String? description, CouponType type, double value, double? minimumOrder, double? maximumDiscount, String? merchantId, String? branchId, String? productId, String? categoryId, int? usageLimit, int? usedCount, DateTime? expiresAt, bool isActive, DateTime? createdAt
});




}
/// @nodoc
class __$CouponCopyWithImpl<$Res>
    implements _$CouponCopyWith<$Res> {
  __$CouponCopyWithImpl(this._self, this._then);

  final _Coupon _self;
  final $Res Function(_Coupon) _then;

/// Create a copy of Coupon
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? code = null,Object? description = freezed,Object? type = null,Object? value = null,Object? minimumOrder = freezed,Object? maximumDiscount = freezed,Object? merchantId = freezed,Object? branchId = freezed,Object? productId = freezed,Object? categoryId = freezed,Object? usageLimit = freezed,Object? usedCount = freezed,Object? expiresAt = freezed,Object? isActive = null,Object? createdAt = freezed,}) {
  return _then(_Coupon(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CouponType,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as double,minimumOrder: freezed == minimumOrder ? _self.minimumOrder : minimumOrder // ignore: cast_nullable_to_non_nullable
as double?,maximumDiscount: freezed == maximumDiscount ? _self.maximumDiscount : maximumDiscount // ignore: cast_nullable_to_non_nullable
as double?,merchantId: freezed == merchantId ? _self.merchantId : merchantId // ignore: cast_nullable_to_non_nullable
as String?,branchId: freezed == branchId ? _self.branchId : branchId // ignore: cast_nullable_to_non_nullable
as String?,productId: freezed == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String?,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,usageLimit: freezed == usageLimit ? _self.usageLimit : usageLimit // ignore: cast_nullable_to_non_nullable
as int?,usedCount: freezed == usedCount ? _self.usedCount : usedCount // ignore: cast_nullable_to_non_nullable
as int?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
