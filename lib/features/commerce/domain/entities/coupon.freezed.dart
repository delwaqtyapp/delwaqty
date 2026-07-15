// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'coupon.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Coupon _$CouponFromJson(Map<String, dynamic> json) {
  return _Coupon.fromJson(json);
}

/// @nodoc
mixin _$Coupon {
  String get id => throw _privateConstructorUsedError;
  String get code => throw _privateConstructorUsedError;
  CouponType get type => throw _privateConstructorUsedError;
  double get value => throw _privateConstructorUsedError;
  double? get minimumOrder => throw _privateConstructorUsedError;
  double? get maximumDiscount => throw _privateConstructorUsedError;
  List<String> get applicableMerchantIds => throw _privateConstructorUsedError;
  int? get usageLimit => throw _privateConstructorUsedError;
  int? get usedCount => throw _privateConstructorUsedError;
  DateTime? get expiresAt => throw _privateConstructorUsedError;
  bool get isActive => throw _privateConstructorUsedError;

  /// Serializes this Coupon to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Coupon
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CouponCopyWith<Coupon> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CouponCopyWith<$Res> {
  factory $CouponCopyWith(Coupon value, $Res Function(Coupon) then) =
      _$CouponCopyWithImpl<$Res, Coupon>;
  @useResult
  $Res call({
    String id,
    String code,
    CouponType type,
    double value,
    double? minimumOrder,
    double? maximumDiscount,
    List<String> applicableMerchantIds,
    int? usageLimit,
    int? usedCount,
    DateTime? expiresAt,
    bool isActive,
  });
}

/// @nodoc
class _$CouponCopyWithImpl<$Res, $Val extends Coupon>
    implements $CouponCopyWith<$Res> {
  _$CouponCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Coupon
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? code = null,
    Object? type = null,
    Object? value = null,
    Object? minimumOrder = freezed,
    Object? maximumDiscount = freezed,
    Object? applicableMerchantIds = null,
    Object? usageLimit = freezed,
    Object? usedCount = freezed,
    Object? expiresAt = freezed,
    Object? isActive = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            code: null == code
                ? _value.code
                : code // ignore: cast_nullable_to_non_nullable
                      as String,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as CouponType,
            value: null == value
                ? _value.value
                : value // ignore: cast_nullable_to_non_nullable
                      as double,
            minimumOrder: freezed == minimumOrder
                ? _value.minimumOrder
                : minimumOrder // ignore: cast_nullable_to_non_nullable
                      as double?,
            maximumDiscount: freezed == maximumDiscount
                ? _value.maximumDiscount
                : maximumDiscount // ignore: cast_nullable_to_non_nullable
                      as double?,
            applicableMerchantIds: null == applicableMerchantIds
                ? _value.applicableMerchantIds
                : applicableMerchantIds // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            usageLimit: freezed == usageLimit
                ? _value.usageLimit
                : usageLimit // ignore: cast_nullable_to_non_nullable
                      as int?,
            usedCount: freezed == usedCount
                ? _value.usedCount
                : usedCount // ignore: cast_nullable_to_non_nullable
                      as int?,
            expiresAt: freezed == expiresAt
                ? _value.expiresAt
                : expiresAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            isActive: null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CouponImplCopyWith<$Res> implements $CouponCopyWith<$Res> {
  factory _$$CouponImplCopyWith(
    _$CouponImpl value,
    $Res Function(_$CouponImpl) then,
  ) = __$$CouponImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String code,
    CouponType type,
    double value,
    double? minimumOrder,
    double? maximumDiscount,
    List<String> applicableMerchantIds,
    int? usageLimit,
    int? usedCount,
    DateTime? expiresAt,
    bool isActive,
  });
}

/// @nodoc
class __$$CouponImplCopyWithImpl<$Res>
    extends _$CouponCopyWithImpl<$Res, _$CouponImpl>
    implements _$$CouponImplCopyWith<$Res> {
  __$$CouponImplCopyWithImpl(
    _$CouponImpl _value,
    $Res Function(_$CouponImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Coupon
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? code = null,
    Object? type = null,
    Object? value = null,
    Object? minimumOrder = freezed,
    Object? maximumDiscount = freezed,
    Object? applicableMerchantIds = null,
    Object? usageLimit = freezed,
    Object? usedCount = freezed,
    Object? expiresAt = freezed,
    Object? isActive = null,
  }) {
    return _then(
      _$CouponImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        code: null == code
            ? _value.code
            : code // ignore: cast_nullable_to_non_nullable
                  as String,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as CouponType,
        value: null == value
            ? _value.value
            : value // ignore: cast_nullable_to_non_nullable
                  as double,
        minimumOrder: freezed == minimumOrder
            ? _value.minimumOrder
            : minimumOrder // ignore: cast_nullable_to_non_nullable
                  as double?,
        maximumDiscount: freezed == maximumDiscount
            ? _value.maximumDiscount
            : maximumDiscount // ignore: cast_nullable_to_non_nullable
                  as double?,
        applicableMerchantIds: null == applicableMerchantIds
            ? _value._applicableMerchantIds
            : applicableMerchantIds // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        usageLimit: freezed == usageLimit
            ? _value.usageLimit
            : usageLimit // ignore: cast_nullable_to_non_nullable
                  as int?,
        usedCount: freezed == usedCount
            ? _value.usedCount
            : usedCount // ignore: cast_nullable_to_non_nullable
                  as int?,
        expiresAt: freezed == expiresAt
            ? _value.expiresAt
            : expiresAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        isActive: null == isActive
            ? _value.isActive
            : isActive // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CouponImpl implements _Coupon {
  const _$CouponImpl({
    required this.id,
    required this.code,
    required this.type,
    required this.value,
    this.minimumOrder,
    this.maximumDiscount,
    final List<String> applicableMerchantIds = const [],
    this.usageLimit,
    this.usedCount,
    this.expiresAt,
    this.isActive = true,
  }) : _applicableMerchantIds = applicableMerchantIds;

  factory _$CouponImpl.fromJson(Map<String, dynamic> json) =>
      _$$CouponImplFromJson(json);

  @override
  final String id;
  @override
  final String code;
  @override
  final CouponType type;
  @override
  final double value;
  @override
  final double? minimumOrder;
  @override
  final double? maximumDiscount;
  final List<String> _applicableMerchantIds;
  @override
  @JsonKey()
  List<String> get applicableMerchantIds {
    if (_applicableMerchantIds is EqualUnmodifiableListView)
      return _applicableMerchantIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_applicableMerchantIds);
  }

  @override
  final int? usageLimit;
  @override
  final int? usedCount;
  @override
  final DateTime? expiresAt;
  @override
  @JsonKey()
  final bool isActive;

  @override
  String toString() {
    return 'Coupon(id: $id, code: $code, type: $type, value: $value, minimumOrder: $minimumOrder, maximumDiscount: $maximumDiscount, applicableMerchantIds: $applicableMerchantIds, usageLimit: $usageLimit, usedCount: $usedCount, expiresAt: $expiresAt, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CouponImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.code, code) || other.code == code) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.value, value) || other.value == value) &&
            (identical(other.minimumOrder, minimumOrder) ||
                other.minimumOrder == minimumOrder) &&
            (identical(other.maximumDiscount, maximumDiscount) ||
                other.maximumDiscount == maximumDiscount) &&
            const DeepCollectionEquality().equals(
              other._applicableMerchantIds,
              _applicableMerchantIds,
            ) &&
            (identical(other.usageLimit, usageLimit) ||
                other.usageLimit == usageLimit) &&
            (identical(other.usedCount, usedCount) ||
                other.usedCount == usedCount) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    code,
    type,
    value,
    minimumOrder,
    maximumDiscount,
    const DeepCollectionEquality().hash(_applicableMerchantIds),
    usageLimit,
    usedCount,
    expiresAt,
    isActive,
  );

  /// Create a copy of Coupon
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CouponImplCopyWith<_$CouponImpl> get copyWith =>
      __$$CouponImplCopyWithImpl<_$CouponImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CouponImplToJson(this);
  }
}

abstract class _Coupon implements Coupon {
  const factory _Coupon({
    required final String id,
    required final String code,
    required final CouponType type,
    required final double value,
    final double? minimumOrder,
    final double? maximumDiscount,
    final List<String> applicableMerchantIds,
    final int? usageLimit,
    final int? usedCount,
    final DateTime? expiresAt,
    final bool isActive,
  }) = _$CouponImpl;

  factory _Coupon.fromJson(Map<String, dynamic> json) = _$CouponImpl.fromJson;

  @override
  String get id;
  @override
  String get code;
  @override
  CouponType get type;
  @override
  double get value;
  @override
  double? get minimumOrder;
  @override
  double? get maximumDiscount;
  @override
  List<String> get applicableMerchantIds;
  @override
  int? get usageLimit;
  @override
  int? get usedCount;
  @override
  DateTime? get expiresAt;
  @override
  bool get isActive;

  /// Create a copy of Coupon
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CouponImplCopyWith<_$CouponImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
