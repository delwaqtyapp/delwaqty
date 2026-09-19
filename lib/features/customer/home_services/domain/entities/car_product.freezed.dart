// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'car_product.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CarProduct {
  String get id;
  String get sellerId;
  String? get driverId;
  String? get merchantId;
  String get category;
  String? get make;
  String? get model;
  int? get year;
  String? get color;
  int get seats;
  String? get photoUrl;
  String get city;
  double get price;
  String? get description;
  bool get isAvailable;
  bool get isVerified;
  double? get latitude;
  double? get longitude;
  DateTime get createdAt;

  /// Create a copy of CarProduct
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CarProductCopyWith<CarProduct> get copyWith =>
      _$CarProductCopyWithImpl<CarProduct>(this as CarProduct, _$identity);

  /// Serializes this CarProduct to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as CarProduct;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CarProduct &&
            (identical(other.id, _this.id) || other.id == _this.id) &&
            (identical(other.sellerId, _this.sellerId) ||
                other.sellerId == _this.sellerId) &&
            (identical(other.driverId, _this.driverId) ||
                other.driverId == _this.driverId) &&
            (identical(other.merchantId, _this.merchantId) ||
                other.merchantId == _this.merchantId) &&
            (identical(other.category, _this.category) ||
                other.category == _this.category) &&
            (identical(other.make, _this.make) || other.make == _this.make) &&
            (identical(other.model, _this.model) ||
                other.model == _this.model) &&
            (identical(other.year, _this.year) || other.year == _this.year) &&
            (identical(other.color, _this.color) ||
                other.color == _this.color) &&
            (identical(other.seats, _this.seats) ||
                other.seats == _this.seats) &&
            (identical(other.photoUrl, _this.photoUrl) ||
                other.photoUrl == _this.photoUrl) &&
            (identical(other.city, _this.city) || other.city == _this.city) &&
            (identical(other.price, _this.price) ||
                other.price == _this.price) &&
            (identical(other.description, _this.description) ||
                other.description == _this.description) &&
            (identical(other.isAvailable, _this.isAvailable) ||
                other.isAvailable == _this.isAvailable) &&
            (identical(other.isVerified, _this.isVerified) ||
                other.isVerified == _this.isVerified) &&
            (identical(other.latitude, _this.latitude) ||
                other.latitude == _this.latitude) &&
            (identical(other.longitude, _this.longitude) ||
                other.longitude == _this.longitude) &&
            (identical(other.createdAt, _this.createdAt) ||
                other.createdAt == _this.createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as CarProduct;
    return Object.hash(
      runtimeType,
      _this.id,
      _this.sellerId,
      _this.driverId,
      _this.merchantId,
      _this.category,
      _this.make,
      _this.model,
      _this.year,
      _this.color,
      _this.seats,
      _this.photoUrl,
      _this.city,
      _this.price,
      _this.description,
      _this.isAvailable,
      _this.isVerified,
      _this.latitude,
      _this.longitude,
      _this.createdAt,
    );
  }

  @override
  String toString() {
    final _this = this as CarProduct;
    return 'CarProduct(id: ${_this.id}, sellerId: ${_this.sellerId}, driverId: ${_this.driverId}, merchantId: ${_this.merchantId}, category: ${_this.category}, make: ${_this.make}, model: ${_this.model}, year: ${_this.year}, color: ${_this.color}, seats: ${_this.seats}, photoUrl: ${_this.photoUrl}, city: ${_this.city}, price: ${_this.price}, description: ${_this.description}, isAvailable: ${_this.isAvailable}, isVerified: ${_this.isVerified}, latitude: ${_this.latitude}, longitude: ${_this.longitude}, createdAt: ${_this.createdAt})';
  }
}

/// @nodoc
abstract mixin class $CarProductCopyWith<$Res> {
  factory $CarProductCopyWith(
          CarProduct value, $Res Function(CarProduct) _then) =
      _$CarProductCopyWithImpl;
  @useResult
  $Res call({
    String id,
    String sellerId,
    String? driverId,
    String? merchantId,
    String category,
    String? make,
    String? model,
    int? year,
    String? color,
    int seats,
    String? photoUrl,
    String city,
    double price,
    String? description,
    bool isAvailable,
    bool isVerified,
    double? latitude,
    double? longitude,
    DateTime createdAt,
  });
}

/// @nodoc
class _$CarProductCopyWithImpl<$Res> implements $CarProductCopyWith<$Res> {
  _$CarProductCopyWithImpl(this._self, this._then);

  final CarProduct _self;
  final $Res Function(CarProduct) _then;

  /// Create a copy of CarProduct
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sellerId = null,
    Object? driverId = freezed,
    Object? merchantId = freezed,
    Object? category = null,
    Object? make = freezed,
    Object? model = freezed,
    Object? year = freezed,
    Object? color = freezed,
    Object? seats = null,
    Object? photoUrl = freezed,
    Object? city = null,
    Object? price = null,
    Object? description = freezed,
    Object? isAvailable = null,
    Object? isVerified = null,
    Object? latitude = freezed,
    Object? longitude = freezed,
    Object? createdAt = null,
  }) {
    return _then(CarProduct(
      id: null == id ? _self.id : id as String,
      sellerId: null == sellerId ? _self.sellerId : sellerId as String,
      driverId: freezed == driverId ? _self.driverId : driverId as String?,
      merchantId: freezed == merchantId
          ? _self.merchantId
          : merchantId as String?,
      category: null == category ? _self.category : category as String,
      make: freezed == make ? _self.make : make as String?,
      model: freezed == model ? _self.model : model as String?,
      year: freezed == year ? _self.year : year as int?,
      color: freezed == color ? _self.color : color as String?,
      seats: null == seats ? _self.seats : seats as int,
      photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl as String?,
      city: null == city ? _self.city : city as String,
      price: null == price ? _self.price : price as double,
      description:
          freezed == description ? _self.description : description as String?,
      isAvailable:
          null == isAvailable ? _self.isAvailable : isAvailable as bool,
      isVerified: null == isVerified ? _self.isVerified : isVerified as bool,
      latitude: freezed == latitude ? _self.latitude : latitude as double?,
      longitude: freezed == longitude ? _self.longitude : longitude as double?,
      createdAt: null == createdAt ? _self.createdAt : createdAt as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()

class _CarProduct implements CarProduct {
  const _CarProduct({
    required this.id,
    required this.sellerId,
    this.driverId,
    this.merchantId,
    this.category = 'car',
    this.make,
    this.model,
    this.year,
    this.color,
    this.seats = 4,
    this.photoUrl,
    required this.city,
    this.price = 0,
    this.description,
    this.isAvailable = true,
    this.isVerified = false,
    this.latitude,
    this.longitude,
    required this.createdAt,
  });
  factory _CarProduct.fromJson(Map<String, dynamic> json) =>
      _$CarProductFromJson(json);

  @override
  final String id;
  @override
  final String sellerId;
  @override
  final String? driverId;
  @override
  final String? merchantId;
  @override
  final String category;
  @override
  final String? make;
  @override
  final String? model;
  @override
  final int? year;
  @override
  final String? color;
  @override
  final int seats;
  @override
  final String? photoUrl;
  @override
  final String city;
  @override
  final double price;
  @override
  final String? description;
  @override
  final bool isAvailable;
  @override
  final bool isVerified;
  @override
  final double? latitude;
  @override
  final double? longitude;
  @override
  final DateTime createdAt;

  /// Create a copy of CarProduct
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CarProductCopyWith<_CarProduct> get copyWith =>
      __$CarProductCopyWithImpl<_CarProduct>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$CarProductToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CarProduct &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.sellerId, sellerId) ||
                other.sellerId == sellerId) &&
            (identical(other.driverId, driverId) ||
                other.driverId == driverId) &&
            (identical(other.merchantId, merchantId) ||
                other.merchantId == merchantId) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.make, make) || other.make == make) &&
            (identical(other.model, model) || other.model == model) &&
            (identical(other.year, year) || other.year == year) &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.seats, seats) || other.seats == seats) &&
            (identical(other.photoUrl, photoUrl) ||
                other.photoUrl == photoUrl) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.isAvailable, isAvailable) ||
                other.isAvailable == isAvailable) &&
            (identical(other.isVerified, isVerified) ||
                other.isVerified == isVerified) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      id,
      sellerId,
      driverId,
      merchantId,
      category,
      make,
      model,
      year,
      color,
      seats,
      photoUrl,
      city,
      price,
      description,
      isAvailable,
      isVerified,
      latitude,
      longitude,
      createdAt,
    );
  }

  @override
  String toString() {
    return 'CarProduct(id: $id, sellerId: $sellerId, driverId: $driverId, merchantId: $merchantId, category: $category, make: $make, model: $model, year: $year, color: $color, seats: $seats, photoUrl: $photoUrl, city: $city, price: $price, description: $description, isAvailable: $isAvailable, isVerified: $isVerified, latitude: $latitude, longitude: $longitude, createdAt: $createdAt)';
  }
}

/// @nodoc
abstract mixin class _$CarProductCopyWith<$Res>
    implements $CarProductCopyWith<$Res> {
  factory _$CarProductCopyWith(
          _CarProduct value, $Res Function(_CarProduct) _then) =
      __$CarProductCopyWithImpl;
  @override
  @useResult
  $Res call({
    String id,
    String sellerId,
    String? driverId,
    String? merchantId,
    String category,
    String? make,
    String? model,
    int? year,
    String? color,
    int seats,
    String? photoUrl,
    String city,
    double price,
    String? description,
    bool isAvailable,
    bool isVerified,
    double? latitude,
    double? longitude,
    DateTime createdAt,
  });
}

/// @nodoc
class __$CarProductCopyWithImpl<$Res>
    implements _$CarProductCopyWith<$Res> {
  __$CarProductCopyWithImpl(this._self, this._then);

  final _CarProduct _self;
  final $Res Function(_CarProduct) _then;

  /// Create a copy of CarProduct
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? sellerId = null,
    Object? driverId = freezed,
    Object? merchantId = freezed,
    Object? category = null,
    Object? make = freezed,
    Object? model = freezed,
    Object? year = freezed,
    Object? color = freezed,
    Object? seats = null,
    Object? photoUrl = freezed,
    Object? city = null,
    Object? price = null,
    Object? description = freezed,
    Object? isAvailable = null,
    Object? isVerified = null,
    Object? latitude = freezed,
    Object? longitude = freezed,
    Object? createdAt = null,
  }) {
    return _then(_CarProduct(
      id: null == id ? _self.id : id as String,
      sellerId: null == sellerId ? _self.sellerId : sellerId as String,
      driverId: freezed == driverId ? _self.driverId : driverId as String?,
      merchantId: freezed == merchantId
          ? _self.merchantId
          : merchantId as String?,
      category: null == category ? _self.category : category as String,
      make: freezed == make ? _self.make : make as String?,
      model: freezed == model ? _self.model : model as String?,
      year: freezed == year ? _self.year : year as int?,
      color: freezed == color ? _self.color : color as String?,
      seats: null == seats ? _self.seats : seats as int,
      photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl as String?,
      city: null == city ? _self.city : city as String,
      price: null == price ? _self.price : price as double,
      description:
          freezed == description ? _self.description : description as String?,
      isAvailable:
          null == isAvailable ? _self.isAvailable : isAvailable as bool,
      isVerified: null == isVerified ? _self.isVerified : isVerified as bool,
      latitude: freezed == latitude ? _self.latitude : latitude as double?,
      longitude: freezed == longitude ? _self.longitude : longitude as double?,
      createdAt: null == createdAt ? _self.createdAt : createdAt as DateTime,
    ));
  }
}

// dart format on