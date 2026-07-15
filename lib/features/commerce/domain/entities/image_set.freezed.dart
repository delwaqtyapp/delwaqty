// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'image_set.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ImageSet _$ImageSetFromJson(Map<String, dynamic> json) {
  return _ImageSet.fromJson(json);
}

/// @nodoc
mixin _$ImageSet {
  String? get thumbnail => throw _privateConstructorUsedError;
  String? get medium => throw _privateConstructorUsedError;
  String? get large => throw _privateConstructorUsedError;

  /// Serializes this ImageSet to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ImageSet
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ImageSetCopyWith<ImageSet> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ImageSetCopyWith<$Res> {
  factory $ImageSetCopyWith(ImageSet value, $Res Function(ImageSet) then) =
      _$ImageSetCopyWithImpl<$Res, ImageSet>;
  @useResult
  $Res call({String? thumbnail, String? medium, String? large});
}

/// @nodoc
class _$ImageSetCopyWithImpl<$Res, $Val extends ImageSet>
    implements $ImageSetCopyWith<$Res> {
  _$ImageSetCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ImageSet
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? thumbnail = freezed,
    Object? medium = freezed,
    Object? large = freezed,
  }) {
    return _then(
      _value.copyWith(
            thumbnail: freezed == thumbnail
                ? _value.thumbnail
                : thumbnail // ignore: cast_nullable_to_non_nullable
                      as String?,
            medium: freezed == medium
                ? _value.medium
                : medium // ignore: cast_nullable_to_non_nullable
                      as String?,
            large: freezed == large
                ? _value.large
                : large // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ImageSetImplCopyWith<$Res>
    implements $ImageSetCopyWith<$Res> {
  factory _$$ImageSetImplCopyWith(
    _$ImageSetImpl value,
    $Res Function(_$ImageSetImpl) then,
  ) = __$$ImageSetImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String? thumbnail, String? medium, String? large});
}

/// @nodoc
class __$$ImageSetImplCopyWithImpl<$Res>
    extends _$ImageSetCopyWithImpl<$Res, _$ImageSetImpl>
    implements _$$ImageSetImplCopyWith<$Res> {
  __$$ImageSetImplCopyWithImpl(
    _$ImageSetImpl _value,
    $Res Function(_$ImageSetImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ImageSet
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? thumbnail = freezed,
    Object? medium = freezed,
    Object? large = freezed,
  }) {
    return _then(
      _$ImageSetImpl(
        thumbnail: freezed == thumbnail
            ? _value.thumbnail
            : thumbnail // ignore: cast_nullable_to_non_nullable
                  as String?,
        medium: freezed == medium
            ? _value.medium
            : medium // ignore: cast_nullable_to_non_nullable
                  as String?,
        large: freezed == large
            ? _value.large
            : large // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ImageSetImpl implements _ImageSet {
  const _$ImageSetImpl({this.thumbnail, this.medium, this.large});

  factory _$ImageSetImpl.fromJson(Map<String, dynamic> json) =>
      _$$ImageSetImplFromJson(json);

  @override
  final String? thumbnail;
  @override
  final String? medium;
  @override
  final String? large;

  @override
  String toString() {
    return 'ImageSet(thumbnail: $thumbnail, medium: $medium, large: $large)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ImageSetImpl &&
            (identical(other.thumbnail, thumbnail) ||
                other.thumbnail == thumbnail) &&
            (identical(other.medium, medium) || other.medium == medium) &&
            (identical(other.large, large) || other.large == large));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, thumbnail, medium, large);

  /// Create a copy of ImageSet
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ImageSetImplCopyWith<_$ImageSetImpl> get copyWith =>
      __$$ImageSetImplCopyWithImpl<_$ImageSetImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ImageSetImplToJson(this);
  }
}

abstract class _ImageSet implements ImageSet {
  const factory _ImageSet({
    final String? thumbnail,
    final String? medium,
    final String? large,
  }) = _$ImageSetImpl;

  factory _ImageSet.fromJson(Map<String, dynamic> json) =
      _$ImageSetImpl.fromJson;

  @override
  String? get thumbnail;
  @override
  String? get medium;
  @override
  String? get large;

  /// Create a copy of ImageSet
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ImageSetImplCopyWith<_$ImageSetImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
