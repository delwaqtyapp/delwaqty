// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'merchant_order.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MerchantOrder {

 String get id; String get customerId; String? get customerName; String? get customerPhone; List<MerchantOrderItem> get items; double get totalAmount; String get status; String? get dispatchStatus; DateTime get createdAt; String? get deliveryAddress; String? get notes;
/// Create a copy of MerchantOrder
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MerchantOrderCopyWith<MerchantOrder> get copyWith => _$MerchantOrderCopyWithImpl<MerchantOrder>(this as MerchantOrder, _$identity);

  /// Serializes this MerchantOrder to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MerchantOrder;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MerchantOrder&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.customerId, _this.customerId) || other.customerId == _this.customerId)&&(identical(other.customerName, _this.customerName) || other.customerName == _this.customerName)&&(identical(other.customerPhone, _this.customerPhone) || other.customerPhone == _this.customerPhone)&&const DeepCollectionEquality().equals(other.items, _this.items)&&(identical(other.totalAmount, _this.totalAmount) || other.totalAmount == _this.totalAmount)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.dispatchStatus, _this.dispatchStatus) || other.dispatchStatus == _this.dispatchStatus)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.deliveryAddress, _this.deliveryAddress) || other.deliveryAddress == _this.deliveryAddress)&&(identical(other.notes, _this.notes) || other.notes == _this.notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MerchantOrder;
  return Object.hash(runtimeType,_this.id,_this.customerId,_this.customerName,_this.customerPhone,const DeepCollectionEquality().hash(_this.items),_this.totalAmount,_this.status,_this.dispatchStatus,_this.createdAt,_this.deliveryAddress,_this.notes);
}

@override
String toString() {
  final _this = this as MerchantOrder;
  return 'MerchantOrder(id: ${_this.id}, customerId: ${_this.customerId}, customerName: ${_this.customerName}, customerPhone: ${_this.customerPhone}, items: ${_this.items}, totalAmount: ${_this.totalAmount}, status: ${_this.status}, dispatchStatus: ${_this.dispatchStatus}, createdAt: ${_this.createdAt}, deliveryAddress: ${_this.deliveryAddress}, notes: ${_this.notes})';
}


}

/// @nodoc
abstract mixin class $MerchantOrderCopyWith<$Res>  {
  factory $MerchantOrderCopyWith(MerchantOrder value, $Res Function(MerchantOrder) _then) = _$MerchantOrderCopyWithImpl;
@useResult
$Res call({
 String id, String customerId, String? customerName, String? customerPhone, List<MerchantOrderItem> items, double totalAmount, String status, String? dispatchStatus, DateTime createdAt, String? deliveryAddress, String? notes
});




}
/// @nodoc
class _$MerchantOrderCopyWithImpl<$Res>
    implements $MerchantOrderCopyWith<$Res> {
  _$MerchantOrderCopyWithImpl(this._self, this._then);

  final MerchantOrder _self;
  final $Res Function(MerchantOrder) _then;

/// Create a copy of MerchantOrder
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? customerId = null,Object? customerName = freezed,Object? customerPhone = freezed,Object? items = null,Object? totalAmount = null,Object? status = null,Object? dispatchStatus = freezed,Object? createdAt = null,Object? deliveryAddress = freezed,Object? notes = freezed,}) {
  return _then(MerchantOrder(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,customerId: null == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String,customerName: freezed == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String?,customerPhone: freezed == customerPhone ? _self.customerPhone : customerPhone // ignore: cast_nullable_to_non_nullable
as String?,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<MerchantOrderItem>,totalAmount: null == totalAmount ? _self.totalAmount : totalAmount // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,dispatchStatus: freezed == dispatchStatus ? _self.dispatchStatus : dispatchStatus // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,deliveryAddress: freezed == deliveryAddress ? _self.deliveryAddress : deliveryAddress // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MerchantOrder].
extension MerchantOrderPatterns on MerchantOrder {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MerchantOrder value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MerchantOrder() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MerchantOrder value)  $default,){
final _that = this;
switch (_that) {
case _MerchantOrder():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MerchantOrder value)?  $default,){
final _that = this;
switch (_that) {
case _MerchantOrder() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String customerId,  String? customerName,  String? customerPhone,  List<MerchantOrderItem> items,  double totalAmount,  String status,  String? dispatchStatus,  DateTime createdAt,  String? deliveryAddress,  String? notes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MerchantOrder() when $default != null:
return $default(_that.id,_that.customerId,_that.customerName,_that.customerPhone,_that.items,_that.totalAmount,_that.status,_that.dispatchStatus,_that.createdAt,_that.deliveryAddress,_that.notes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String customerId,  String? customerName,  String? customerPhone,  List<MerchantOrderItem> items,  double totalAmount,  String status,  String? dispatchStatus,  DateTime createdAt,  String? deliveryAddress,  String? notes)  $default,) {final _that = this;
switch (_that) {
case _MerchantOrder():
return $default(_that.id,_that.customerId,_that.customerName,_that.customerPhone,_that.items,_that.totalAmount,_that.status,_that.dispatchStatus,_that.createdAt,_that.deliveryAddress,_that.notes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String customerId,  String? customerName,  String? customerPhone,  List<MerchantOrderItem> items,  double totalAmount,  String status,  String? dispatchStatus,  DateTime createdAt,  String? deliveryAddress,  String? notes)?  $default,) {final _that = this;
switch (_that) {
case _MerchantOrder() when $default != null:
return $default(_that.id,_that.customerId,_that.customerName,_that.customerPhone,_that.items,_that.totalAmount,_that.status,_that.dispatchStatus,_that.createdAt,_that.deliveryAddress,_that.notes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MerchantOrder implements MerchantOrder {
  const _MerchantOrder({required this.id, required this.customerId, this.customerName, this.customerPhone,  List<MerchantOrderItem> items = const [], required this.totalAmount, required this.status, this.dispatchStatus, required this.createdAt, this.deliveryAddress, this.notes}): _items = items;
  factory _MerchantOrder.fromJson(Map<String, dynamic> json) => _$MerchantOrderFromJson(json);

@override final  String id;
@override final  String customerId;
@override final  String? customerName;
@override final  String? customerPhone;
 final  List<MerchantOrderItem> _items;
@override@JsonKey() List<MerchantOrderItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  double totalAmount;
@override final  String status;
@override final  String? dispatchStatus;
@override final  DateTime createdAt;
@override final  String? deliveryAddress;
@override final  String? notes;

/// Create a copy of MerchantOrder
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MerchantOrderCopyWith<_MerchantOrder> get copyWith => __$MerchantOrderCopyWithImpl<_MerchantOrder>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MerchantOrderToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MerchantOrder&&(identical(other.id, id) || other.id == id)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.customerPhone, customerPhone) || other.customerPhone == customerPhone)&&const DeepCollectionEquality().equals(other.items, _items)&&(identical(other.totalAmount, totalAmount) || other.totalAmount == totalAmount)&&(identical(other.status, status) || other.status == status)&&(identical(other.dispatchStatus, dispatchStatus) || other.dispatchStatus == dispatchStatus)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.deliveryAddress, deliveryAddress) || other.deliveryAddress == deliveryAddress)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,customerId,customerName,customerPhone,const DeepCollectionEquality().hash(_items),totalAmount,status,dispatchStatus,createdAt,deliveryAddress,notes);
}

@override
String toString() {
    return 'MerchantOrder(id: $id, customerId: $customerId, customerName: $customerName, customerPhone: $customerPhone, items: $items, totalAmount: $totalAmount, status: $status, dispatchStatus: $dispatchStatus, createdAt: $createdAt, deliveryAddress: $deliveryAddress, notes: $notes)';
}


}

/// @nodoc
abstract mixin class _$MerchantOrderCopyWith<$Res> implements $MerchantOrderCopyWith<$Res> {
  factory _$MerchantOrderCopyWith(_MerchantOrder value, $Res Function(_MerchantOrder) _then) = __$MerchantOrderCopyWithImpl;
@override @useResult
$Res call({
 String id, String customerId, String? customerName, String? customerPhone, List<MerchantOrderItem> items, double totalAmount, String status, String? dispatchStatus, DateTime createdAt, String? deliveryAddress, String? notes
});




}
/// @nodoc
class __$MerchantOrderCopyWithImpl<$Res>
    implements _$MerchantOrderCopyWith<$Res> {
  __$MerchantOrderCopyWithImpl(this._self, this._then);

  final _MerchantOrder _self;
  final $Res Function(_MerchantOrder) _then;

/// Create a copy of MerchantOrder
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? customerId = null,Object? customerName = freezed,Object? customerPhone = freezed,Object? items = null,Object? totalAmount = null,Object? status = null,Object? dispatchStatus = freezed,Object? createdAt = null,Object? deliveryAddress = freezed,Object? notes = freezed,}) {
  return _then(_MerchantOrder(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,customerId: null == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String,customerName: freezed == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String?,customerPhone: freezed == customerPhone ? _self.customerPhone : customerPhone // ignore: cast_nullable_to_non_nullable
as String?,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<MerchantOrderItem>,totalAmount: null == totalAmount ? _self.totalAmount : totalAmount // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,dispatchStatus: freezed == dispatchStatus ? _self.dispatchStatus : dispatchStatus // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,deliveryAddress: freezed == deliveryAddress ? _self.deliveryAddress : deliveryAddress // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$MerchantOrderItem {

 String get productId; String get productName; int get quantity; double get unitPrice; List<String> get modifiers;
/// Create a copy of MerchantOrderItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MerchantOrderItemCopyWith<MerchantOrderItem> get copyWith => _$MerchantOrderItemCopyWithImpl<MerchantOrderItem>(this as MerchantOrderItem, _$identity);

  /// Serializes this MerchantOrderItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MerchantOrderItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MerchantOrderItem&&(identical(other.productId, _this.productId) || other.productId == _this.productId)&&(identical(other.productName, _this.productName) || other.productName == _this.productName)&&(identical(other.quantity, _this.quantity) || other.quantity == _this.quantity)&&(identical(other.unitPrice, _this.unitPrice) || other.unitPrice == _this.unitPrice)&&const DeepCollectionEquality().equals(other.modifiers, _this.modifiers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MerchantOrderItem;
  return Object.hash(runtimeType,_this.productId,_this.productName,_this.quantity,_this.unitPrice,const DeepCollectionEquality().hash(_this.modifiers));
}

@override
String toString() {
  final _this = this as MerchantOrderItem;
  return 'MerchantOrderItem(productId: ${_this.productId}, productName: ${_this.productName}, quantity: ${_this.quantity}, unitPrice: ${_this.unitPrice}, modifiers: ${_this.modifiers})';
}


}

/// @nodoc
abstract mixin class $MerchantOrderItemCopyWith<$Res>  {
  factory $MerchantOrderItemCopyWith(MerchantOrderItem value, $Res Function(MerchantOrderItem) _then) = _$MerchantOrderItemCopyWithImpl;
@useResult
$Res call({
 String productId, String productName, int quantity, double unitPrice, List<String> modifiers
});




}
/// @nodoc
class _$MerchantOrderItemCopyWithImpl<$Res>
    implements $MerchantOrderItemCopyWith<$Res> {
  _$MerchantOrderItemCopyWithImpl(this._self, this._then);

  final MerchantOrderItem _self;
  final $Res Function(MerchantOrderItem) _then;

/// Create a copy of MerchantOrderItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? productId = null,Object? productName = null,Object? quantity = null,Object? unitPrice = null,Object? modifiers = null,}) {
  return _then(MerchantOrderItem(
productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String,productName: null == productName ? _self.productName : productName // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,unitPrice: null == unitPrice ? _self.unitPrice : unitPrice // ignore: cast_nullable_to_non_nullable
as double,modifiers: null == modifiers ? _self.modifiers : modifiers // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [MerchantOrderItem].
extension MerchantOrderItemPatterns on MerchantOrderItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MerchantOrderItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MerchantOrderItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MerchantOrderItem value)  $default,){
final _that = this;
switch (_that) {
case _MerchantOrderItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MerchantOrderItem value)?  $default,){
final _that = this;
switch (_that) {
case _MerchantOrderItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String productId,  String productName,  int quantity,  double unitPrice,  List<String> modifiers)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MerchantOrderItem() when $default != null:
return $default(_that.productId,_that.productName,_that.quantity,_that.unitPrice,_that.modifiers);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String productId,  String productName,  int quantity,  double unitPrice,  List<String> modifiers)  $default,) {final _that = this;
switch (_that) {
case _MerchantOrderItem():
return $default(_that.productId,_that.productName,_that.quantity,_that.unitPrice,_that.modifiers);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String productId,  String productName,  int quantity,  double unitPrice,  List<String> modifiers)?  $default,) {final _that = this;
switch (_that) {
case _MerchantOrderItem() when $default != null:
return $default(_that.productId,_that.productName,_that.quantity,_that.unitPrice,_that.modifiers);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MerchantOrderItem implements MerchantOrderItem {
  const _MerchantOrderItem({required this.productId, required this.productName, required this.quantity, required this.unitPrice,  List<String> modifiers = const []}): _modifiers = modifiers;
  factory _MerchantOrderItem.fromJson(Map<String, dynamic> json) => _$MerchantOrderItemFromJson(json);

@override final  String productId;
@override final  String productName;
@override final  int quantity;
@override final  double unitPrice;
 final  List<String> _modifiers;
@override@JsonKey() List<String> get modifiers {
  if (_modifiers is EqualUnmodifiableListView) return _modifiers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_modifiers);
}


/// Create a copy of MerchantOrderItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MerchantOrderItemCopyWith<_MerchantOrderItem> get copyWith => __$MerchantOrderItemCopyWithImpl<_MerchantOrderItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MerchantOrderItemToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MerchantOrderItem&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.productName, productName) || other.productName == productName)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.unitPrice, unitPrice) || other.unitPrice == unitPrice)&&const DeepCollectionEquality().equals(other.modifiers, _modifiers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,productId,productName,quantity,unitPrice,const DeepCollectionEquality().hash(_modifiers));
}

@override
String toString() {
    return 'MerchantOrderItem(productId: $productId, productName: $productName, quantity: $quantity, unitPrice: $unitPrice, modifiers: $modifiers)';
}


}

/// @nodoc
abstract mixin class _$MerchantOrderItemCopyWith<$Res> implements $MerchantOrderItemCopyWith<$Res> {
  factory _$MerchantOrderItemCopyWith(_MerchantOrderItem value, $Res Function(_MerchantOrderItem) _then) = __$MerchantOrderItemCopyWithImpl;
@override @useResult
$Res call({
 String productId, String productName, int quantity, double unitPrice, List<String> modifiers
});




}
/// @nodoc
class __$MerchantOrderItemCopyWithImpl<$Res>
    implements _$MerchantOrderItemCopyWith<$Res> {
  __$MerchantOrderItemCopyWithImpl(this._self, this._then);

  final _MerchantOrderItem _self;
  final $Res Function(_MerchantOrderItem) _then;

/// Create a copy of MerchantOrderItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? productId = null,Object? productName = null,Object? quantity = null,Object? unitPrice = null,Object? modifiers = null,}) {
  return _then(_MerchantOrderItem(
productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String,productName: null == productName ? _self.productName : productName // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,unitPrice: null == unitPrice ? _self.unitPrice : unitPrice // ignore: cast_nullable_to_non_nullable
as double,modifiers: null == modifiers ? _self._modifiers : modifiers // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
