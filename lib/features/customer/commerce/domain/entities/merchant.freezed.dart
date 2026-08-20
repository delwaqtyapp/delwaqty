// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'merchant.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Merchant _$MerchantFromJson(Map<String, dynamic> json) {
  return _Merchant.fromJson(json);
}

/// @nodoc
mixin _$Merchant {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  MerchantType get type => throw _privateConstructorUsedError;
  double get latitude => throw _privateConstructorUsedError;
  double get longitude => throw _privateConstructorUsedError;
  String? get address => throw _privateConstructorUsedError;
  String? get city => throw _privateConstructorUsedError;
  double get rating => throw _privateConstructorUsedError;
  int get ratingCount => throw _privateConstructorUsedError;
  String? get imageUrl => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  bool get isOpenNow => throw _privateConstructorUsedError;
  bool get isVerified => throw _privateConstructorUsedError;
  bool get isFeatured => throw _privateConstructorUsedError;
  bool get deliveryAvailable => throw _privateConstructorUsedError;
  bool get pickupAvailable => throw _privateConstructorUsedError;
  int? get estimatedDeliveryMinutes => throw _privateConstructorUsedError;
  double? get deliveryFee => throw _privateConstructorUsedError;
  double? get minimumOrder => throw _privateConstructorUsedError;
  List<String> get tags => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this Merchant to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Merchant
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MerchantCopyWith<Merchant> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MerchantCopyWith<$Res> {
  factory $MerchantCopyWith(Merchant value, $Res Function(Merchant) then) =
      _$MerchantCopyWithImpl<$Res, Merchant>;
  @useResult
  $Res call({
    String id,
    String name,
    MerchantType type,
    double latitude,
    double longitude,
    String? address,
    String? city,
    double rating,
    int ratingCount,
    String? imageUrl,
    String? description,
    bool isOpenNow,
    bool isVerified,
    bool isFeatured,
    bool deliveryAvailable,
    bool pickupAvailable,
    int? estimatedDeliveryMinutes,
    double? deliveryFee,
    double? minimumOrder,
    List<String> tags,
    DateTime createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class _$MerchantCopyWithImpl<$Res, $Val extends Merchant>
    implements $MerchantCopyWith<$Res> {
  _$MerchantCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Merchant
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? type = null,
    Object? latitude = null,
    Object? longitude = null,
    Object? address = freezed,
    Object? city = freezed,
    Object? rating = null,
    Object? ratingCount = null,
    Object? imageUrl = freezed,
    Object? description = freezed,
    Object? isOpenNow = null,
    Object? isVerified = null,
    Object? isFeatured = null,
    Object? deliveryAvailable = null,
    Object? pickupAvailable = null,
    Object? estimatedDeliveryMinutes = freezed,
    Object? deliveryFee = freezed,
    Object? minimumOrder = freezed,
    Object? tags = null,
    Object? createdAt = null,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as MerchantType,
            latitude: null == latitude
                ? _value.latitude
                : latitude // ignore: cast_nullable_to_non_nullable
                      as double,
            longitude: null == longitude
                ? _value.longitude
                : longitude // ignore: cast_nullable_to_non_nullable
                      as double,
            address: freezed == address
                ? _value.address
                : address // ignore: cast_nullable_to_non_nullable
                      as String?,
            city: freezed == city
                ? _value.city
                : city // ignore: cast_nullable_to_non_nullable
                      as String?,
            rating: null == rating
                ? _value.rating
                : rating // ignore: cast_nullable_to_non_nullable
                      as double,
            ratingCount: null == ratingCount
                ? _value.ratingCount
                : ratingCount // ignore: cast_nullable_to_non_nullable
                      as int,
            imageUrl: freezed == imageUrl
                ? _value.imageUrl
                : imageUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            isOpenNow: null == isOpenNow
                ? _value.isOpenNow
                : isOpenNow // ignore: cast_nullable_to_non_nullable
                      as bool,
            isVerified: null == isVerified
                ? _value.isVerified
                : isVerified // ignore: cast_nullable_to_non_nullable
                      as bool,
            isFeatured: null == isFeatured
                ? _value.isFeatured
                : isFeatured // ignore: cast_nullable_to_non_nullable
                      as bool,
            deliveryAvailable: null == deliveryAvailable
                ? _value.deliveryAvailable
                : deliveryAvailable // ignore: cast_nullable_to_non_nullable
                      as bool,
            pickupAvailable: null == pickupAvailable
                ? _value.pickupAvailable
                : pickupAvailable // ignore: cast_nullable_to_non_nullable
                      as bool,
            estimatedDeliveryMinutes: freezed == estimatedDeliveryMinutes
                ? _value.estimatedDeliveryMinutes
                : estimatedDeliveryMinutes // ignore: cast_nullable_to_non_nullable
                      as int?,
            deliveryFee: freezed == deliveryFee
                ? _value.deliveryFee
                : deliveryFee // ignore: cast_nullable_to_non_nullable
                      as double?,
            minimumOrder: freezed == minimumOrder
                ? _value.minimumOrder
                : minimumOrder // ignore: cast_nullable_to_non_nullable
                      as double?,
            tags: null == tags
                ? _value.tags
                : tags // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MerchantImplCopyWith<$Res>
    implements $MerchantCopyWith<$Res> {
  factory _$$MerchantImplCopyWith(
    _$MerchantImpl value,
    $Res Function(_$MerchantImpl) then,
  ) = __$$MerchantImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    MerchantType type,
    double latitude,
    double longitude,
    String? address,
    String? city,
    double rating,
    int ratingCount,
    String? imageUrl,
    String? description,
    bool isOpenNow,
    bool isVerified,
    bool isFeatured,
    bool deliveryAvailable,
    bool pickupAvailable,
    int? estimatedDeliveryMinutes,
    double? deliveryFee,
    double? minimumOrder,
    List<String> tags,
    DateTime createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class __$$MerchantImplCopyWithImpl<$Res>
    extends _$MerchantCopyWithImpl<$Res, _$MerchantImpl>
    implements _$$MerchantImplCopyWith<$Res> {
  __$$MerchantImplCopyWithImpl(
    _$MerchantImpl _value,
    $Res Function(_$MerchantImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Merchant
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? type = null,
    Object? latitude = null,
    Object? longitude = null,
    Object? address = freezed,
    Object? city = freezed,
    Object? rating = null,
    Object? ratingCount = null,
    Object? imageUrl = freezed,
    Object? description = freezed,
    Object? isOpenNow = null,
    Object? isVerified = null,
    Object? isFeatured = null,
    Object? deliveryAvailable = null,
    Object? pickupAvailable = null,
    Object? estimatedDeliveryMinutes = freezed,
    Object? deliveryFee = freezed,
    Object? minimumOrder = freezed,
    Object? tags = null,
    Object? createdAt = null,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$MerchantImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as MerchantType,
        latitude: null == latitude
            ? _value.latitude
            : latitude // ignore: cast_nullable_to_non_nullable
                  as double,
        longitude: null == longitude
            ? _value.longitude
            : longitude // ignore: cast_nullable_to_non_nullable
                  as double,
        address: freezed == address
            ? _value.address
            : address // ignore: cast_nullable_to_non_nullable
                  as String?,
        city: freezed == city
            ? _value.city
            : city // ignore: cast_nullable_to_non_nullable
                  as String?,
        rating: null == rating
            ? _value.rating
            : rating // ignore: cast_nullable_to_non_nullable
                  as double,
        ratingCount: null == ratingCount
            ? _value.ratingCount
            : ratingCount // ignore: cast_nullable_to_non_nullable
                  as int,
        imageUrl: freezed == imageUrl
            ? _value.imageUrl
            : imageUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        isOpenNow: null == isOpenNow
            ? _value.isOpenNow
            : isOpenNow // ignore: cast_nullable_to_non_nullable
                  as bool,
        isVerified: null == isVerified
            ? _value.isVerified
            : isVerified // ignore: cast_nullable_to_non_nullable
                  as bool,
        isFeatured: null == isFeatured
            ? _value.isFeatured
            : isFeatured // ignore: cast_nullable_to_non_nullable
                  as bool,
        deliveryAvailable: null == deliveryAvailable
            ? _value.deliveryAvailable
            : deliveryAvailable // ignore: cast_nullable_to_non_nullable
                  as bool,
        pickupAvailable: null == pickupAvailable
            ? _value.pickupAvailable
            : pickupAvailable // ignore: cast_nullable_to_non_nullable
                  as bool,
        estimatedDeliveryMinutes: freezed == estimatedDeliveryMinutes
            ? _value.estimatedDeliveryMinutes
            : estimatedDeliveryMinutes // ignore: cast_nullable_to_non_nullable
                  as int?,
        deliveryFee: freezed == deliveryFee
            ? _value.deliveryFee
            : deliveryFee // ignore: cast_nullable_to_non_nullable
                  as double?,
        minimumOrder: freezed == minimumOrder
            ? _value.minimumOrder
            : minimumOrder // ignore: cast_nullable_to_non_nullable
                  as double?,
        tags: null == tags
            ? _value._tags
            : tags // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: freezed == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MerchantImpl implements _Merchant {
  const _$MerchantImpl({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    this.address,
    this.city,
    this.rating = 0.0,
    this.ratingCount = 0,
    this.imageUrl,
    this.description,
    this.isOpenNow = false,
    this.isVerified = false,
    this.isFeatured = false,
    this.deliveryAvailable = false,
    this.pickupAvailable = false,
    this.estimatedDeliveryMinutes,
    this.deliveryFee,
    this.minimumOrder,
    final List<String> tags = const [],
    required this.createdAt,
    this.updatedAt,
  }) : _tags = tags;

  factory _$MerchantImpl.fromJson(Map<String, dynamic> json) =>
      _$$MerchantImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final MerchantType type;
  @override
  final double latitude;
  @override
  final double longitude;
  @override
  final String? address;
  @override
  final String? city;
  @override
  @JsonKey()
  final double rating;
  @override
  @JsonKey()
  final int ratingCount;
  @override
  final String? imageUrl;
  @override
  final String? description;
  @override
  @JsonKey()
  final bool isOpenNow;
  @override
  @JsonKey()
  final bool isVerified;
  @override
  @JsonKey()
  final bool isFeatured;
  @override
  @JsonKey()
  final bool deliveryAvailable;
  @override
  @JsonKey()
  final bool pickupAvailable;
  @override
  final int? estimatedDeliveryMinutes;
  @override
  final double? deliveryFee;
  @override
  final double? minimumOrder;
  final List<String> _tags;
  @override
  @JsonKey()
  List<String> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'Merchant(id: $id, name: $name, type: $type, latitude: $latitude, longitude: $longitude, address: $address, city: $city, rating: $rating, ratingCount: $ratingCount, imageUrl: $imageUrl, description: $description, isOpenNow: $isOpenNow, isVerified: $isVerified, isFeatured: $isFeatured, deliveryAvailable: $deliveryAvailable, pickupAvailable: $pickupAvailable, estimatedDeliveryMinutes: $estimatedDeliveryMinutes, deliveryFee: $deliveryFee, minimumOrder: $minimumOrder, tags: $tags, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MerchantImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            (identical(other.ratingCount, ratingCount) ||
                other.ratingCount == ratingCount) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.isOpenNow, isOpenNow) ||
                other.isOpenNow == isOpenNow) &&
            (identical(other.isVerified, isVerified) ||
                other.isVerified == isVerified) &&
            (identical(other.isFeatured, isFeatured) ||
                other.isFeatured == isFeatured) &&
            (identical(other.deliveryAvailable, deliveryAvailable) ||
                other.deliveryAvailable == deliveryAvailable) &&
            (identical(other.pickupAvailable, pickupAvailable) ||
                other.pickupAvailable == pickupAvailable) &&
            (identical(
                  other.estimatedDeliveryMinutes,
                  estimatedDeliveryMinutes,
                ) ||
                other.estimatedDeliveryMinutes == estimatedDeliveryMinutes) &&
            (identical(other.deliveryFee, deliveryFee) ||
                other.deliveryFee == deliveryFee) &&
            (identical(other.minimumOrder, minimumOrder) ||
                other.minimumOrder == minimumOrder) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    name,
    type,
    latitude,
    longitude,
    address,
    city,
    rating,
    ratingCount,
    imageUrl,
    description,
    isOpenNow,
    isVerified,
    isFeatured,
    deliveryAvailable,
    pickupAvailable,
    estimatedDeliveryMinutes,
    deliveryFee,
    minimumOrder,
    const DeepCollectionEquality().hash(_tags),
    createdAt,
    updatedAt,
  ]);

  /// Create a copy of Merchant
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MerchantImplCopyWith<_$MerchantImpl> get copyWith =>
      __$$MerchantImplCopyWithImpl<_$MerchantImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MerchantImplToJson(this);
  }
}

abstract class _Merchant implements Merchant {
  const factory _Merchant({
    required final String id,
    required final String name,
    required final MerchantType type,
    required final double latitude,
    required final double longitude,
    final String? address,
    final String? city,
    final double rating,
    final int ratingCount,
    final String? imageUrl,
    final String? description,
    final bool isOpenNow,
    final bool isVerified,
    final bool isFeatured,
    final bool deliveryAvailable,
    final bool pickupAvailable,
    final int? estimatedDeliveryMinutes,
    final double? deliveryFee,
    final double? minimumOrder,
    final List<String> tags,
    required final DateTime createdAt,
    final DateTime? updatedAt,
  }) = _$MerchantImpl;

  factory _Merchant.fromJson(Map<String, dynamic> json) =
      _$MerchantImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  MerchantType get type;
  @override
  double get latitude;
  @override
  double get longitude;
  @override
  String? get address;
  @override
  String? get city;
  @override
  double get rating;
  @override
  int get ratingCount;
  @override
  String? get imageUrl;
  @override
  String? get description;
  @override
  bool get isOpenNow;
  @override
  bool get isVerified;
  @override
  bool get isFeatured;
  @override
  bool get deliveryAvailable;
  @override
  bool get pickupAvailable;
  @override
  int? get estimatedDeliveryMinutes;
  @override
  double? get deliveryFee;
  @override
  double? get minimumOrder;
  @override
  List<String> get tags;
  @override
  DateTime get createdAt;
  @override
  DateTime? get updatedAt;

  /// Create a copy of Merchant
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MerchantImplCopyWith<_$MerchantImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
