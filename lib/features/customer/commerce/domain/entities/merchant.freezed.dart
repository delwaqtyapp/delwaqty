// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'merchant.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Merchant {

 String get id; String get name; MerchantType get type; double get latitude; double get longitude; String? get address; String? get city; double get rating; int get ratingCount; String? get imageUrl; String? get description; bool get isOpenNow; bool get isVerified; bool get isFeatured; bool get deliveryAvailable; bool get pickupAvailable; int? get estimatedDeliveryMinutes; double? get deliveryFee; double? get minimumOrder; List<String> get tags; DateTime get createdAt; DateTime? get updatedAt;
/// Create a copy of Merchant
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MerchantCopyWith<Merchant> get copyWith => _$MerchantCopyWithImpl<Merchant>(this as Merchant, _$identity);

  /// Serializes this Merchant to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Merchant;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Merchant&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.latitude, _this.latitude) || other.latitude == _this.latitude)&&(identical(other.longitude, _this.longitude) || other.longitude == _this.longitude)&&(identical(other.address, _this.address) || other.address == _this.address)&&(identical(other.city, _this.city) || other.city == _this.city)&&(identical(other.rating, _this.rating) || other.rating == _this.rating)&&(identical(other.ratingCount, _this.ratingCount) || other.ratingCount == _this.ratingCount)&&(identical(other.imageUrl, _this.imageUrl) || other.imageUrl == _this.imageUrl)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.isOpenNow, _this.isOpenNow) || other.isOpenNow == _this.isOpenNow)&&(identical(other.isVerified, _this.isVerified) || other.isVerified == _this.isVerified)&&(identical(other.isFeatured, _this.isFeatured) || other.isFeatured == _this.isFeatured)&&(identical(other.deliveryAvailable, _this.deliveryAvailable) || other.deliveryAvailable == _this.deliveryAvailable)&&(identical(other.pickupAvailable, _this.pickupAvailable) || other.pickupAvailable == _this.pickupAvailable)&&(identical(other.estimatedDeliveryMinutes, _this.estimatedDeliveryMinutes) || other.estimatedDeliveryMinutes == _this.estimatedDeliveryMinutes)&&(identical(other.deliveryFee, _this.deliveryFee) || other.deliveryFee == _this.deliveryFee)&&(identical(other.minimumOrder, _this.minimumOrder) || other.minimumOrder == _this.minimumOrder)&&const DeepCollectionEquality().equals(other.tags, _this.tags)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Merchant;
  return Object.hashAll([runtimeType,_this.id,_this.name,_this.type,_this.latitude,_this.longitude,_this.address,_this.city,_this.rating,_this.ratingCount,_this.imageUrl,_this.description,_this.isOpenNow,_this.isVerified,_this.isFeatured,_this.deliveryAvailable,_this.pickupAvailable,_this.estimatedDeliveryMinutes,_this.deliveryFee,_this.minimumOrder,const DeepCollectionEquality().hash(_this.tags),_this.createdAt,_this.updatedAt]);
}

@override
String toString() {
  final _this = this as Merchant;
  return 'Merchant(id: ${_this.id}, name: ${_this.name}, type: ${_this.type}, latitude: ${_this.latitude}, longitude: ${_this.longitude}, address: ${_this.address}, city: ${_this.city}, rating: ${_this.rating}, ratingCount: ${_this.ratingCount}, imageUrl: ${_this.imageUrl}, description: ${_this.description}, isOpenNow: ${_this.isOpenNow}, isVerified: ${_this.isVerified}, isFeatured: ${_this.isFeatured}, deliveryAvailable: ${_this.deliveryAvailable}, pickupAvailable: ${_this.pickupAvailable}, estimatedDeliveryMinutes: ${_this.estimatedDeliveryMinutes}, deliveryFee: ${_this.deliveryFee}, minimumOrder: ${_this.minimumOrder}, tags: ${_this.tags}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $MerchantCopyWith<$Res>  {
  factory $MerchantCopyWith(Merchant value, $Res Function(Merchant) _then) = _$MerchantCopyWithImpl;
@useResult
$Res call({
 String id, String name, MerchantType type, double latitude, double longitude, String? address, String? city, double rating, int ratingCount, String? imageUrl, String? description, bool isOpenNow, bool isVerified, bool isFeatured, bool deliveryAvailable, bool pickupAvailable, int? estimatedDeliveryMinutes, double? deliveryFee, double? minimumOrder, List<String> tags, DateTime createdAt, DateTime? updatedAt
});




}
/// @nodoc
class _$MerchantCopyWithImpl<$Res>
    implements $MerchantCopyWith<$Res> {
  _$MerchantCopyWithImpl(this._self, this._then);

  final Merchant _self;
  final $Res Function(Merchant) _then;

/// Create a copy of Merchant
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? type = null,Object? latitude = null,Object? longitude = null,Object? address = freezed,Object? city = freezed,Object? rating = null,Object? ratingCount = null,Object? imageUrl = freezed,Object? description = freezed,Object? isOpenNow = null,Object? isVerified = null,Object? isFeatured = null,Object? deliveryAvailable = null,Object? pickupAvailable = null,Object? estimatedDeliveryMinutes = freezed,Object? deliveryFee = freezed,Object? minimumOrder = freezed,Object? tags = null,Object? createdAt = null,Object? updatedAt = freezed,}) {
  return _then(Merchant(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as MerchantType,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,rating: null == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double,ratingCount: null == ratingCount ? _self.ratingCount : ratingCount // ignore: cast_nullable_to_non_nullable
as int,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,isOpenNow: null == isOpenNow ? _self.isOpenNow : isOpenNow // ignore: cast_nullable_to_non_nullable
as bool,isVerified: null == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool,isFeatured: null == isFeatured ? _self.isFeatured : isFeatured // ignore: cast_nullable_to_non_nullable
as bool,deliveryAvailable: null == deliveryAvailable ? _self.deliveryAvailable : deliveryAvailable // ignore: cast_nullable_to_non_nullable
as bool,pickupAvailable: null == pickupAvailable ? _self.pickupAvailable : pickupAvailable // ignore: cast_nullable_to_non_nullable
as bool,estimatedDeliveryMinutes: freezed == estimatedDeliveryMinutes ? _self.estimatedDeliveryMinutes : estimatedDeliveryMinutes // ignore: cast_nullable_to_non_nullable
as int?,deliveryFee: freezed == deliveryFee ? _self.deliveryFee : deliveryFee // ignore: cast_nullable_to_non_nullable
as double?,minimumOrder: freezed == minimumOrder ? _self.minimumOrder : minimumOrder // ignore: cast_nullable_to_non_nullable
as double?,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Merchant].
extension MerchantPatterns on Merchant {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Merchant value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Merchant() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Merchant value)  $default,){
final _that = this;
switch (_that) {
case _Merchant():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Merchant value)?  $default,){
final _that = this;
switch (_that) {
case _Merchant() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  MerchantType type,  double latitude,  double longitude,  String? address,  String? city,  double rating,  int ratingCount,  String? imageUrl,  String? description,  bool isOpenNow,  bool isVerified,  bool isFeatured,  bool deliveryAvailable,  bool pickupAvailable,  int? estimatedDeliveryMinutes,  double? deliveryFee,  double? minimumOrder,  List<String> tags,  DateTime createdAt,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Merchant() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.latitude,_that.longitude,_that.address,_that.city,_that.rating,_that.ratingCount,_that.imageUrl,_that.description,_that.isOpenNow,_that.isVerified,_that.isFeatured,_that.deliveryAvailable,_that.pickupAvailable,_that.estimatedDeliveryMinutes,_that.deliveryFee,_that.minimumOrder,_that.tags,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  MerchantType type,  double latitude,  double longitude,  String? address,  String? city,  double rating,  int ratingCount,  String? imageUrl,  String? description,  bool isOpenNow,  bool isVerified,  bool isFeatured,  bool deliveryAvailable,  bool pickupAvailable,  int? estimatedDeliveryMinutes,  double? deliveryFee,  double? minimumOrder,  List<String> tags,  DateTime createdAt,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Merchant():
return $default(_that.id,_that.name,_that.type,_that.latitude,_that.longitude,_that.address,_that.city,_that.rating,_that.ratingCount,_that.imageUrl,_that.description,_that.isOpenNow,_that.isVerified,_that.isFeatured,_that.deliveryAvailable,_that.pickupAvailable,_that.estimatedDeliveryMinutes,_that.deliveryFee,_that.minimumOrder,_that.tags,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  MerchantType type,  double latitude,  double longitude,  String? address,  String? city,  double rating,  int ratingCount,  String? imageUrl,  String? description,  bool isOpenNow,  bool isVerified,  bool isFeatured,  bool deliveryAvailable,  bool pickupAvailable,  int? estimatedDeliveryMinutes,  double? deliveryFee,  double? minimumOrder,  List<String> tags,  DateTime createdAt,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Merchant() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.latitude,_that.longitude,_that.address,_that.city,_that.rating,_that.ratingCount,_that.imageUrl,_that.description,_that.isOpenNow,_that.isVerified,_that.isFeatured,_that.deliveryAvailable,_that.pickupAvailable,_that.estimatedDeliveryMinutes,_that.deliveryFee,_that.minimumOrder,_that.tags,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Merchant implements Merchant {
  const _Merchant({required this.id, required this.name, required this.type, required this.latitude, required this.longitude, this.address, this.city, this.rating = 0.0, this.ratingCount = 0, this.imageUrl, this.description, this.isOpenNow = false, this.isVerified = false, this.isFeatured = false, this.deliveryAvailable = false, this.pickupAvailable = false, this.estimatedDeliveryMinutes, this.deliveryFee, this.minimumOrder,  List<String> tags = const [], required this.createdAt, this.updatedAt}): _tags = tags;
  factory _Merchant.fromJson(Map<String, dynamic> json) => _$MerchantFromJson(json);

@override final  String id;
@override final  String name;
@override final  MerchantType type;
@override final  double latitude;
@override final  double longitude;
@override final  String? address;
@override final  String? city;
@override@JsonKey() final  double rating;
@override@JsonKey() final  int ratingCount;
@override final  String? imageUrl;
@override final  String? description;
@override@JsonKey() final  bool isOpenNow;
@override@JsonKey() final  bool isVerified;
@override@JsonKey() final  bool isFeatured;
@override@JsonKey() final  bool deliveryAvailable;
@override@JsonKey() final  bool pickupAvailable;
@override final  int? estimatedDeliveryMinutes;
@override final  double? deliveryFee;
@override final  double? minimumOrder;
 final  List<String> _tags;
@override@JsonKey() List<String> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

@override final  DateTime createdAt;
@override final  DateTime? updatedAt;

/// Create a copy of Merchant
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MerchantCopyWith<_Merchant> get copyWith => __$MerchantCopyWithImpl<_Merchant>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MerchantToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Merchant&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.address, address) || other.address == address)&&(identical(other.city, city) || other.city == city)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.ratingCount, ratingCount) || other.ratingCount == ratingCount)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.description, description) || other.description == description)&&(identical(other.isOpenNow, isOpenNow) || other.isOpenNow == isOpenNow)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified)&&(identical(other.isFeatured, isFeatured) || other.isFeatured == isFeatured)&&(identical(other.deliveryAvailable, deliveryAvailable) || other.deliveryAvailable == deliveryAvailable)&&(identical(other.pickupAvailable, pickupAvailable) || other.pickupAvailable == pickupAvailable)&&(identical(other.estimatedDeliveryMinutes, estimatedDeliveryMinutes) || other.estimatedDeliveryMinutes == estimatedDeliveryMinutes)&&(identical(other.deliveryFee, deliveryFee) || other.deliveryFee == deliveryFee)&&(identical(other.minimumOrder, minimumOrder) || other.minimumOrder == minimumOrder)&&const DeepCollectionEquality().equals(other.tags, _tags)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,id,name,type,latitude,longitude,address,city,rating,ratingCount,imageUrl,description,isOpenNow,isVerified,isFeatured,deliveryAvailable,pickupAvailable,estimatedDeliveryMinutes,deliveryFee,minimumOrder,const DeepCollectionEquality().hash(_tags),createdAt,updatedAt]);
}

@override
String toString() {
    return 'Merchant(id: $id, name: $name, type: $type, latitude: $latitude, longitude: $longitude, address: $address, city: $city, rating: $rating, ratingCount: $ratingCount, imageUrl: $imageUrl, description: $description, isOpenNow: $isOpenNow, isVerified: $isVerified, isFeatured: $isFeatured, deliveryAvailable: $deliveryAvailable, pickupAvailable: $pickupAvailable, estimatedDeliveryMinutes: $estimatedDeliveryMinutes, deliveryFee: $deliveryFee, minimumOrder: $minimumOrder, tags: $tags, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$MerchantCopyWith<$Res> implements $MerchantCopyWith<$Res> {
  factory _$MerchantCopyWith(_Merchant value, $Res Function(_Merchant) _then) = __$MerchantCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, MerchantType type, double latitude, double longitude, String? address, String? city, double rating, int ratingCount, String? imageUrl, String? description, bool isOpenNow, bool isVerified, bool isFeatured, bool deliveryAvailable, bool pickupAvailable, int? estimatedDeliveryMinutes, double? deliveryFee, double? minimumOrder, List<String> tags, DateTime createdAt, DateTime? updatedAt
});




}
/// @nodoc
class __$MerchantCopyWithImpl<$Res>
    implements _$MerchantCopyWith<$Res> {
  __$MerchantCopyWithImpl(this._self, this._then);

  final _Merchant _self;
  final $Res Function(_Merchant) _then;

/// Create a copy of Merchant
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? type = null,Object? latitude = null,Object? longitude = null,Object? address = freezed,Object? city = freezed,Object? rating = null,Object? ratingCount = null,Object? imageUrl = freezed,Object? description = freezed,Object? isOpenNow = null,Object? isVerified = null,Object? isFeatured = null,Object? deliveryAvailable = null,Object? pickupAvailable = null,Object? estimatedDeliveryMinutes = freezed,Object? deliveryFee = freezed,Object? minimumOrder = freezed,Object? tags = null,Object? createdAt = null,Object? updatedAt = freezed,}) {
  return _then(_Merchant(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as MerchantType,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,rating: null == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double,ratingCount: null == ratingCount ? _self.ratingCount : ratingCount // ignore: cast_nullable_to_non_nullable
as int,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,isOpenNow: null == isOpenNow ? _self.isOpenNow : isOpenNow // ignore: cast_nullable_to_non_nullable
as bool,isVerified: null == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool,isFeatured: null == isFeatured ? _self.isFeatured : isFeatured // ignore: cast_nullable_to_non_nullable
as bool,deliveryAvailable: null == deliveryAvailable ? _self.deliveryAvailable : deliveryAvailable // ignore: cast_nullable_to_non_nullable
as bool,pickupAvailable: null == pickupAvailable ? _self.pickupAvailable : pickupAvailable // ignore: cast_nullable_to_non_nullable
as bool,estimatedDeliveryMinutes: freezed == estimatedDeliveryMinutes ? _self.estimatedDeliveryMinutes : estimatedDeliveryMinutes // ignore: cast_nullable_to_non_nullable
as int?,deliveryFee: freezed == deliveryFee ? _self.deliveryFee : deliveryFee // ignore: cast_nullable_to_non_nullable
as double?,minimumOrder: freezed == minimumOrder ? _self.minimumOrder : minimumOrder // ignore: cast_nullable_to_non_nullable
as double?,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
