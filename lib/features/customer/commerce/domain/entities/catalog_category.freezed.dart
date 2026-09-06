// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'catalog_category.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CatalogCategory {

 String get id; String get merchantId; String get name; String? get description; String? get icon; String? get imageUrl; int get sortOrder; bool get isVisible;
/// Create a copy of CatalogCategory
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CatalogCategoryCopyWith<CatalogCategory> get copyWith => _$CatalogCategoryCopyWithImpl<CatalogCategory>(this as CatalogCategory, _$identity);

  /// Serializes this CatalogCategory to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CatalogCategory;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CatalogCategory&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.merchantId, _this.merchantId) || other.merchantId == _this.merchantId)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.icon, _this.icon) || other.icon == _this.icon)&&(identical(other.imageUrl, _this.imageUrl) || other.imageUrl == _this.imageUrl)&&(identical(other.sortOrder, _this.sortOrder) || other.sortOrder == _this.sortOrder)&&(identical(other.isVisible, _this.isVisible) || other.isVisible == _this.isVisible));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CatalogCategory;
  return Object.hash(runtimeType,_this.id,_this.merchantId,_this.name,_this.description,_this.icon,_this.imageUrl,_this.sortOrder,_this.isVisible);
}

@override
String toString() {
  final _this = this as CatalogCategory;
  return 'CatalogCategory(id: ${_this.id}, merchantId: ${_this.merchantId}, name: ${_this.name}, description: ${_this.description}, icon: ${_this.icon}, imageUrl: ${_this.imageUrl}, sortOrder: ${_this.sortOrder}, isVisible: ${_this.isVisible})';
}


}

/// @nodoc
abstract mixin class $CatalogCategoryCopyWith<$Res>  {
  factory $CatalogCategoryCopyWith(CatalogCategory value, $Res Function(CatalogCategory) _then) = _$CatalogCategoryCopyWithImpl;
@useResult
$Res call({
 String id, String merchantId, String name, String? description, String? icon, String? imageUrl, int sortOrder, bool isVisible
});




}
/// @nodoc
class _$CatalogCategoryCopyWithImpl<$Res>
    implements $CatalogCategoryCopyWith<$Res> {
  _$CatalogCategoryCopyWithImpl(this._self, this._then);

  final CatalogCategory _self;
  final $Res Function(CatalogCategory) _then;

/// Create a copy of CatalogCategory
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? merchantId = null,Object? name = null,Object? description = freezed,Object? icon = freezed,Object? imageUrl = freezed,Object? sortOrder = null,Object? isVisible = null,}) {
  return _then(CatalogCategory(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,merchantId: null == merchantId ? _self.merchantId : merchantId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,icon: freezed == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String?,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,isVisible: null == isVisible ? _self.isVisible : isVisible // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [CatalogCategory].
extension CatalogCategoryPatterns on CatalogCategory {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CatalogCategory value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CatalogCategory() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CatalogCategory value)  $default,){
final _that = this;
switch (_that) {
case _CatalogCategory():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CatalogCategory value)?  $default,){
final _that = this;
switch (_that) {
case _CatalogCategory() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String merchantId,  String name,  String? description,  String? icon,  String? imageUrl,  int sortOrder,  bool isVisible)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CatalogCategory() when $default != null:
return $default(_that.id,_that.merchantId,_that.name,_that.description,_that.icon,_that.imageUrl,_that.sortOrder,_that.isVisible);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String merchantId,  String name,  String? description,  String? icon,  String? imageUrl,  int sortOrder,  bool isVisible)  $default,) {final _that = this;
switch (_that) {
case _CatalogCategory():
return $default(_that.id,_that.merchantId,_that.name,_that.description,_that.icon,_that.imageUrl,_that.sortOrder,_that.isVisible);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String merchantId,  String name,  String? description,  String? icon,  String? imageUrl,  int sortOrder,  bool isVisible)?  $default,) {final _that = this;
switch (_that) {
case _CatalogCategory() when $default != null:
return $default(_that.id,_that.merchantId,_that.name,_that.description,_that.icon,_that.imageUrl,_that.sortOrder,_that.isVisible);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CatalogCategory implements CatalogCategory {
  const _CatalogCategory({required this.id, required this.merchantId, required this.name, this.description, this.icon, this.imageUrl, this.sortOrder = 0, this.isVisible = true});
  factory _CatalogCategory.fromJson(Map<String, dynamic> json) => _$CatalogCategoryFromJson(json);

@override final  String id;
@override final  String merchantId;
@override final  String name;
@override final  String? description;
@override final  String? icon;
@override final  String? imageUrl;
@override@JsonKey() final  int sortOrder;
@override@JsonKey() final  bool isVisible;

/// Create a copy of CatalogCategory
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CatalogCategoryCopyWith<_CatalogCategory> get copyWith => __$CatalogCategoryCopyWithImpl<_CatalogCategory>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CatalogCategoryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CatalogCategory&&(identical(other.id, id) || other.id == id)&&(identical(other.merchantId, merchantId) || other.merchantId == merchantId)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.isVisible, isVisible) || other.isVisible == isVisible));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,merchantId,name,description,icon,imageUrl,sortOrder,isVisible);
}

@override
String toString() {
    return 'CatalogCategory(id: $id, merchantId: $merchantId, name: $name, description: $description, icon: $icon, imageUrl: $imageUrl, sortOrder: $sortOrder, isVisible: $isVisible)';
}


}

/// @nodoc
abstract mixin class _$CatalogCategoryCopyWith<$Res> implements $CatalogCategoryCopyWith<$Res> {
  factory _$CatalogCategoryCopyWith(_CatalogCategory value, $Res Function(_CatalogCategory) _then) = __$CatalogCategoryCopyWithImpl;
@override @useResult
$Res call({
 String id, String merchantId, String name, String? description, String? icon, String? imageUrl, int sortOrder, bool isVisible
});




}
/// @nodoc
class __$CatalogCategoryCopyWithImpl<$Res>
    implements _$CatalogCategoryCopyWith<$Res> {
  __$CatalogCategoryCopyWithImpl(this._self, this._then);

  final _CatalogCategory _self;
  final $Res Function(_CatalogCategory) _then;

/// Create a copy of CatalogCategory
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? merchantId = null,Object? name = null,Object? description = freezed,Object? icon = freezed,Object? imageUrl = freezed,Object? sortOrder = null,Object? isVisible = null,}) {
  return _then(_CatalogCategory(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,merchantId: null == merchantId ? _self.merchantId : merchantId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,icon: freezed == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String?,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,isVisible: null == isVisible ? _self.isVisible : isVisible // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
