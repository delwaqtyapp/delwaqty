// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'catalog_category.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

CatalogCategory _$CatalogCategoryFromJson(Map<String, dynamic> json) {
  return _CatalogCategory.fromJson(json);
}

/// @nodoc
mixin _$CatalogCategory {
  String get id => throw _privateConstructorUsedError;
  String get merchantId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String? get icon => throw _privateConstructorUsedError;
  String? get imageUrl => throw _privateConstructorUsedError;
  int get sortOrder => throw _privateConstructorUsedError;
  bool get isVisible => throw _privateConstructorUsedError;

  /// Serializes this CatalogCategory to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CatalogCategory
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CatalogCategoryCopyWith<CatalogCategory> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CatalogCategoryCopyWith<$Res> {
  factory $CatalogCategoryCopyWith(
    CatalogCategory value,
    $Res Function(CatalogCategory) then,
  ) = _$CatalogCategoryCopyWithImpl<$Res, CatalogCategory>;
  @useResult
  $Res call({
    String id,
    String merchantId,
    String name,
    String? description,
    String? icon,
    String? imageUrl,
    int sortOrder,
    bool isVisible,
  });
}

/// @nodoc
class _$CatalogCategoryCopyWithImpl<$Res, $Val extends CatalogCategory>
    implements $CatalogCategoryCopyWith<$Res> {
  _$CatalogCategoryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CatalogCategory
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? merchantId = null,
    Object? name = null,
    Object? description = freezed,
    Object? icon = freezed,
    Object? imageUrl = freezed,
    Object? sortOrder = null,
    Object? isVisible = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            merchantId: null == merchantId
                ? _value.merchantId
                : merchantId // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            icon: freezed == icon
                ? _value.icon
                : icon // ignore: cast_nullable_to_non_nullable
                      as String?,
            imageUrl: freezed == imageUrl
                ? _value.imageUrl
                : imageUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            sortOrder: null == sortOrder
                ? _value.sortOrder
                : sortOrder // ignore: cast_nullable_to_non_nullable
                      as int,
            isVisible: null == isVisible
                ? _value.isVisible
                : isVisible // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CatalogCategoryImplCopyWith<$Res>
    implements $CatalogCategoryCopyWith<$Res> {
  factory _$$CatalogCategoryImplCopyWith(
    _$CatalogCategoryImpl value,
    $Res Function(_$CatalogCategoryImpl) then,
  ) = __$$CatalogCategoryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String merchantId,
    String name,
    String? description,
    String? icon,
    String? imageUrl,
    int sortOrder,
    bool isVisible,
  });
}

/// @nodoc
class __$$CatalogCategoryImplCopyWithImpl<$Res>
    extends _$CatalogCategoryCopyWithImpl<$Res, _$CatalogCategoryImpl>
    implements _$$CatalogCategoryImplCopyWith<$Res> {
  __$$CatalogCategoryImplCopyWithImpl(
    _$CatalogCategoryImpl _value,
    $Res Function(_$CatalogCategoryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CatalogCategory
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? merchantId = null,
    Object? name = null,
    Object? description = freezed,
    Object? icon = freezed,
    Object? imageUrl = freezed,
    Object? sortOrder = null,
    Object? isVisible = null,
  }) {
    return _then(
      _$CatalogCategoryImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        merchantId: null == merchantId
            ? _value.merchantId
            : merchantId // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        icon: freezed == icon
            ? _value.icon
            : icon // ignore: cast_nullable_to_non_nullable
                  as String?,
        imageUrl: freezed == imageUrl
            ? _value.imageUrl
            : imageUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        sortOrder: null == sortOrder
            ? _value.sortOrder
            : sortOrder // ignore: cast_nullable_to_non_nullable
                  as int,
        isVisible: null == isVisible
            ? _value.isVisible
            : isVisible // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CatalogCategoryImpl implements _CatalogCategory {
  const _$CatalogCategoryImpl({
    required this.id,
    required this.merchantId,
    required this.name,
    this.description,
    this.icon,
    this.imageUrl,
    this.sortOrder = 0,
    this.isVisible = true,
  });

  factory _$CatalogCategoryImpl.fromJson(Map<String, dynamic> json) =>
      _$$CatalogCategoryImplFromJson(json);

  @override
  final String id;
  @override
  final String merchantId;
  @override
  final String name;
  @override
  final String? description;
  @override
  final String? icon;
  @override
  final String? imageUrl;
  @override
  @JsonKey()
  final int sortOrder;
  @override
  @JsonKey()
  final bool isVisible;

  @override
  String toString() {
    return 'CatalogCategory(id: $id, merchantId: $merchantId, name: $name, description: $description, icon: $icon, imageUrl: $imageUrl, sortOrder: $sortOrder, isVisible: $isVisible)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CatalogCategoryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.merchantId, merchantId) ||
                other.merchantId == merchantId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.icon, icon) || other.icon == icon) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.sortOrder, sortOrder) ||
                other.sortOrder == sortOrder) &&
            (identical(other.isVisible, isVisible) ||
                other.isVisible == isVisible));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    merchantId,
    name,
    description,
    icon,
    imageUrl,
    sortOrder,
    isVisible,
  );

  /// Create a copy of CatalogCategory
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CatalogCategoryImplCopyWith<_$CatalogCategoryImpl> get copyWith =>
      __$$CatalogCategoryImplCopyWithImpl<_$CatalogCategoryImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$CatalogCategoryImplToJson(this);
  }
}

abstract class _CatalogCategory implements CatalogCategory {
  const factory _CatalogCategory({
    required final String id,
    required final String merchantId,
    required final String name,
    final String? description,
    final String? icon,
    final String? imageUrl,
    final int sortOrder,
    final bool isVisible,
  }) = _$CatalogCategoryImpl;

  factory _CatalogCategory.fromJson(Map<String, dynamic> json) =
      _$CatalogCategoryImpl.fromJson;

  @override
  String get id;
  @override
  String get merchantId;
  @override
  String get name;
  @override
  String? get description;
  @override
  String? get icon;
  @override
  String? get imageUrl;
  @override
  int get sortOrder;
  @override
  bool get isVisible;

  /// Create a copy of CatalogCategory
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CatalogCategoryImplCopyWith<_$CatalogCategoryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
