// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'order.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Order {

 String get id; String get merchantId; String get merchantName; List<OrderItem> get items; double get subtotal; double get deliveryFee; double get discount; double get total; OrderStatus get status; String? get deliveryAddress; String? get paymentMethod; PaymentStatus get paymentStatus; String? get paymentId; String? get transactionId; String? get specialInstructions; DateTime? get confirmedAt; DateTime? get preparingAt; DateTime? get readyAt; DateTime? get deliveredAt; DateTime? get cancelledAt; String? get cancellationReason; DateTime get createdAt; DateTime? get updatedAt;
/// Create a copy of Order
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrderCopyWith<Order> get copyWith => _$OrderCopyWithImpl<Order>(this as Order, _$identity);

  /// Serializes this Order to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Order;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Order&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.merchantId, _this.merchantId) || other.merchantId == _this.merchantId)&&(identical(other.merchantName, _this.merchantName) || other.merchantName == _this.merchantName)&&const DeepCollectionEquality().equals(other.items, _this.items)&&(identical(other.subtotal, _this.subtotal) || other.subtotal == _this.subtotal)&&(identical(other.deliveryFee, _this.deliveryFee) || other.deliveryFee == _this.deliveryFee)&&(identical(other.discount, _this.discount) || other.discount == _this.discount)&&(identical(other.total, _this.total) || other.total == _this.total)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.deliveryAddress, _this.deliveryAddress) || other.deliveryAddress == _this.deliveryAddress)&&(identical(other.paymentMethod, _this.paymentMethod) || other.paymentMethod == _this.paymentMethod)&&(identical(other.paymentStatus, _this.paymentStatus) || other.paymentStatus == _this.paymentStatus)&&(identical(other.paymentId, _this.paymentId) || other.paymentId == _this.paymentId)&&(identical(other.transactionId, _this.transactionId) || other.transactionId == _this.transactionId)&&(identical(other.specialInstructions, _this.specialInstructions) || other.specialInstructions == _this.specialInstructions)&&(identical(other.confirmedAt, _this.confirmedAt) || other.confirmedAt == _this.confirmedAt)&&(identical(other.preparingAt, _this.preparingAt) || other.preparingAt == _this.preparingAt)&&(identical(other.readyAt, _this.readyAt) || other.readyAt == _this.readyAt)&&(identical(other.deliveredAt, _this.deliveredAt) || other.deliveredAt == _this.deliveredAt)&&(identical(other.cancelledAt, _this.cancelledAt) || other.cancelledAt == _this.cancelledAt)&&(identical(other.cancellationReason, _this.cancellationReason) || other.cancellationReason == _this.cancellationReason)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Order;
  return Object.hashAll([runtimeType,_this.id,_this.merchantId,_this.merchantName,const DeepCollectionEquality().hash(_this.items),_this.subtotal,_this.deliveryFee,_this.discount,_this.total,_this.status,_this.deliveryAddress,_this.paymentMethod,_this.paymentStatus,_this.paymentId,_this.transactionId,_this.specialInstructions,_this.confirmedAt,_this.preparingAt,_this.readyAt,_this.deliveredAt,_this.cancelledAt,_this.cancellationReason,_this.createdAt,_this.updatedAt]);
}

@override
String toString() {
  final _this = this as Order;
  return 'Order(id: ${_this.id}, merchantId: ${_this.merchantId}, merchantName: ${_this.merchantName}, items: ${_this.items}, subtotal: ${_this.subtotal}, deliveryFee: ${_this.deliveryFee}, discount: ${_this.discount}, total: ${_this.total}, status: ${_this.status}, deliveryAddress: ${_this.deliveryAddress}, paymentMethod: ${_this.paymentMethod}, paymentStatus: ${_this.paymentStatus}, paymentId: ${_this.paymentId}, transactionId: ${_this.transactionId}, specialInstructions: ${_this.specialInstructions}, confirmedAt: ${_this.confirmedAt}, preparingAt: ${_this.preparingAt}, readyAt: ${_this.readyAt}, deliveredAt: ${_this.deliveredAt}, cancelledAt: ${_this.cancelledAt}, cancellationReason: ${_this.cancellationReason}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $OrderCopyWith<$Res>  {
  factory $OrderCopyWith(Order value, $Res Function(Order) _then) = _$OrderCopyWithImpl;
@useResult
$Res call({
 String id, String merchantId, String merchantName, List<OrderItem> items, double subtotal, double deliveryFee, double discount, double total, OrderStatus status, String? deliveryAddress, String? paymentMethod, PaymentStatus paymentStatus, String? paymentId, String? transactionId, String? specialInstructions, DateTime? confirmedAt, DateTime? preparingAt, DateTime? readyAt, DateTime? deliveredAt, DateTime? cancelledAt, String? cancellationReason, DateTime createdAt, DateTime? updatedAt
});




}
/// @nodoc
class _$OrderCopyWithImpl<$Res>
    implements $OrderCopyWith<$Res> {
  _$OrderCopyWithImpl(this._self, this._then);

  final Order _self;
  final $Res Function(Order) _then;

/// Create a copy of Order
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? merchantId = null,Object? merchantName = null,Object? items = null,Object? subtotal = null,Object? deliveryFee = null,Object? discount = null,Object? total = null,Object? status = null,Object? deliveryAddress = freezed,Object? paymentMethod = freezed,Object? paymentStatus = null,Object? paymentId = freezed,Object? transactionId = freezed,Object? specialInstructions = freezed,Object? confirmedAt = freezed,Object? preparingAt = freezed,Object? readyAt = freezed,Object? deliveredAt = freezed,Object? cancelledAt = freezed,Object? cancellationReason = freezed,Object? createdAt = null,Object? updatedAt = freezed,}) {
  return _then(Order(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,merchantId: null == merchantId ? _self.merchantId : merchantId // ignore: cast_nullable_to_non_nullable
as String,merchantName: null == merchantName ? _self.merchantName : merchantName // ignore: cast_nullable_to_non_nullable
as String,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<OrderItem>,subtotal: null == subtotal ? _self.subtotal : subtotal // ignore: cast_nullable_to_non_nullable
as double,deliveryFee: null == deliveryFee ? _self.deliveryFee : deliveryFee // ignore: cast_nullable_to_non_nullable
as double,discount: null == discount ? _self.discount : discount // ignore: cast_nullable_to_non_nullable
as double,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as OrderStatus,deliveryAddress: freezed == deliveryAddress ? _self.deliveryAddress : deliveryAddress // ignore: cast_nullable_to_non_nullable
as String?,paymentMethod: freezed == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as String?,paymentStatus: null == paymentStatus ? _self.paymentStatus : paymentStatus // ignore: cast_nullable_to_non_nullable
as PaymentStatus,paymentId: freezed == paymentId ? _self.paymentId : paymentId // ignore: cast_nullable_to_non_nullable
as String?,transactionId: freezed == transactionId ? _self.transactionId : transactionId // ignore: cast_nullable_to_non_nullable
as String?,specialInstructions: freezed == specialInstructions ? _self.specialInstructions : specialInstructions // ignore: cast_nullable_to_non_nullable
as String?,confirmedAt: freezed == confirmedAt ? _self.confirmedAt : confirmedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,preparingAt: freezed == preparingAt ? _self.preparingAt : preparingAt // ignore: cast_nullable_to_non_nullable
as DateTime?,readyAt: freezed == readyAt ? _self.readyAt : readyAt // ignore: cast_nullable_to_non_nullable
as DateTime?,deliveredAt: freezed == deliveredAt ? _self.deliveredAt : deliveredAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cancelledAt: freezed == cancelledAt ? _self.cancelledAt : cancelledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cancellationReason: freezed == cancellationReason ? _self.cancellationReason : cancellationReason // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Order].
extension OrderPatterns on Order {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Order value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Order() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Order value)  $default,){
final _that = this;
switch (_that) {
case _Order():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Order value)?  $default,){
final _that = this;
switch (_that) {
case _Order() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String merchantId,  String merchantName,  List<OrderItem> items,  double subtotal,  double deliveryFee,  double discount,  double total,  OrderStatus status,  String? deliveryAddress,  String? paymentMethod,  PaymentStatus paymentStatus,  String? paymentId,  String? transactionId,  String? specialInstructions,  DateTime? confirmedAt,  DateTime? preparingAt,  DateTime? readyAt,  DateTime? deliveredAt,  DateTime? cancelledAt,  String? cancellationReason,  DateTime createdAt,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Order() when $default != null:
return $default(_that.id,_that.merchantId,_that.merchantName,_that.items,_that.subtotal,_that.deliveryFee,_that.discount,_that.total,_that.status,_that.deliveryAddress,_that.paymentMethod,_that.paymentStatus,_that.paymentId,_that.transactionId,_that.specialInstructions,_that.confirmedAt,_that.preparingAt,_that.readyAt,_that.deliveredAt,_that.cancelledAt,_that.cancellationReason,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String merchantId,  String merchantName,  List<OrderItem> items,  double subtotal,  double deliveryFee,  double discount,  double total,  OrderStatus status,  String? deliveryAddress,  String? paymentMethod,  PaymentStatus paymentStatus,  String? paymentId,  String? transactionId,  String? specialInstructions,  DateTime? confirmedAt,  DateTime? preparingAt,  DateTime? readyAt,  DateTime? deliveredAt,  DateTime? cancelledAt,  String? cancellationReason,  DateTime createdAt,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Order():
return $default(_that.id,_that.merchantId,_that.merchantName,_that.items,_that.subtotal,_that.deliveryFee,_that.discount,_that.total,_that.status,_that.deliveryAddress,_that.paymentMethod,_that.paymentStatus,_that.paymentId,_that.transactionId,_that.specialInstructions,_that.confirmedAt,_that.preparingAt,_that.readyAt,_that.deliveredAt,_that.cancelledAt,_that.cancellationReason,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String merchantId,  String merchantName,  List<OrderItem> items,  double subtotal,  double deliveryFee,  double discount,  double total,  OrderStatus status,  String? deliveryAddress,  String? paymentMethod,  PaymentStatus paymentStatus,  String? paymentId,  String? transactionId,  String? specialInstructions,  DateTime? confirmedAt,  DateTime? preparingAt,  DateTime? readyAt,  DateTime? deliveredAt,  DateTime? cancelledAt,  String? cancellationReason,  DateTime createdAt,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Order() when $default != null:
return $default(_that.id,_that.merchantId,_that.merchantName,_that.items,_that.subtotal,_that.deliveryFee,_that.discount,_that.total,_that.status,_that.deliveryAddress,_that.paymentMethod,_that.paymentStatus,_that.paymentId,_that.transactionId,_that.specialInstructions,_that.confirmedAt,_that.preparingAt,_that.readyAt,_that.deliveredAt,_that.cancelledAt,_that.cancellationReason,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Order implements Order {
  const _Order({required this.id, required this.merchantId, required this.merchantName,  List<OrderItem> items = const [], required this.subtotal, this.deliveryFee = 0.0, this.discount = 0.0, this.total = 0.0, required this.status, this.deliveryAddress, this.paymentMethod, this.paymentStatus = PaymentStatus.unpaid, this.paymentId, this.transactionId, this.specialInstructions, this.confirmedAt, this.preparingAt, this.readyAt, this.deliveredAt, this.cancelledAt, this.cancellationReason, required this.createdAt, this.updatedAt}): _items = items;
  factory _Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);

@override final  String id;
@override final  String merchantId;
@override final  String merchantName;
 final  List<OrderItem> _items;
@override@JsonKey() List<OrderItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  double subtotal;
@override@JsonKey() final  double deliveryFee;
@override@JsonKey() final  double discount;
@override@JsonKey() final  double total;
@override final  OrderStatus status;
@override final  String? deliveryAddress;
@override final  String? paymentMethod;
@override@JsonKey() final  PaymentStatus paymentStatus;
@override final  String? paymentId;
@override final  String? transactionId;
@override final  String? specialInstructions;
@override final  DateTime? confirmedAt;
@override final  DateTime? preparingAt;
@override final  DateTime? readyAt;
@override final  DateTime? deliveredAt;
@override final  DateTime? cancelledAt;
@override final  String? cancellationReason;
@override final  DateTime createdAt;
@override final  DateTime? updatedAt;

/// Create a copy of Order
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrderCopyWith<_Order> get copyWith => __$OrderCopyWithImpl<_Order>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrderToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Order&&(identical(other.id, id) || other.id == id)&&(identical(other.merchantId, merchantId) || other.merchantId == merchantId)&&(identical(other.merchantName, merchantName) || other.merchantName == merchantName)&&const DeepCollectionEquality().equals(other.items, _items)&&(identical(other.subtotal, subtotal) || other.subtotal == subtotal)&&(identical(other.deliveryFee, deliveryFee) || other.deliveryFee == deliveryFee)&&(identical(other.discount, discount) || other.discount == discount)&&(identical(other.total, total) || other.total == total)&&(identical(other.status, status) || other.status == status)&&(identical(other.deliveryAddress, deliveryAddress) || other.deliveryAddress == deliveryAddress)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod)&&(identical(other.paymentStatus, paymentStatus) || other.paymentStatus == paymentStatus)&&(identical(other.paymentId, paymentId) || other.paymentId == paymentId)&&(identical(other.transactionId, transactionId) || other.transactionId == transactionId)&&(identical(other.specialInstructions, specialInstructions) || other.specialInstructions == specialInstructions)&&(identical(other.confirmedAt, confirmedAt) || other.confirmedAt == confirmedAt)&&(identical(other.preparingAt, preparingAt) || other.preparingAt == preparingAt)&&(identical(other.readyAt, readyAt) || other.readyAt == readyAt)&&(identical(other.deliveredAt, deliveredAt) || other.deliveredAt == deliveredAt)&&(identical(other.cancelledAt, cancelledAt) || other.cancelledAt == cancelledAt)&&(identical(other.cancellationReason, cancellationReason) || other.cancellationReason == cancellationReason)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,id,merchantId,merchantName,const DeepCollectionEquality().hash(_items),subtotal,deliveryFee,discount,total,status,deliveryAddress,paymentMethod,paymentStatus,paymentId,transactionId,specialInstructions,confirmedAt,preparingAt,readyAt,deliveredAt,cancelledAt,cancellationReason,createdAt,updatedAt]);
}

@override
String toString() {
    return 'Order(id: $id, merchantId: $merchantId, merchantName: $merchantName, items: $items, subtotal: $subtotal, deliveryFee: $deliveryFee, discount: $discount, total: $total, status: $status, deliveryAddress: $deliveryAddress, paymentMethod: $paymentMethod, paymentStatus: $paymentStatus, paymentId: $paymentId, transactionId: $transactionId, specialInstructions: $specialInstructions, confirmedAt: $confirmedAt, preparingAt: $preparingAt, readyAt: $readyAt, deliveredAt: $deliveredAt, cancelledAt: $cancelledAt, cancellationReason: $cancellationReason, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$OrderCopyWith<$Res> implements $OrderCopyWith<$Res> {
  factory _$OrderCopyWith(_Order value, $Res Function(_Order) _then) = __$OrderCopyWithImpl;
@override @useResult
$Res call({
 String id, String merchantId, String merchantName, List<OrderItem> items, double subtotal, double deliveryFee, double discount, double total, OrderStatus status, String? deliveryAddress, String? paymentMethod, PaymentStatus paymentStatus, String? paymentId, String? transactionId, String? specialInstructions, DateTime? confirmedAt, DateTime? preparingAt, DateTime? readyAt, DateTime? deliveredAt, DateTime? cancelledAt, String? cancellationReason, DateTime createdAt, DateTime? updatedAt
});




}
/// @nodoc
class __$OrderCopyWithImpl<$Res>
    implements _$OrderCopyWith<$Res> {
  __$OrderCopyWithImpl(this._self, this._then);

  final _Order _self;
  final $Res Function(_Order) _then;

/// Create a copy of Order
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? merchantId = null,Object? merchantName = null,Object? items = null,Object? subtotal = null,Object? deliveryFee = null,Object? discount = null,Object? total = null,Object? status = null,Object? deliveryAddress = freezed,Object? paymentMethod = freezed,Object? paymentStatus = null,Object? paymentId = freezed,Object? transactionId = freezed,Object? specialInstructions = freezed,Object? confirmedAt = freezed,Object? preparingAt = freezed,Object? readyAt = freezed,Object? deliveredAt = freezed,Object? cancelledAt = freezed,Object? cancellationReason = freezed,Object? createdAt = null,Object? updatedAt = freezed,}) {
  return _then(_Order(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,merchantId: null == merchantId ? _self.merchantId : merchantId // ignore: cast_nullable_to_non_nullable
as String,merchantName: null == merchantName ? _self.merchantName : merchantName // ignore: cast_nullable_to_non_nullable
as String,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<OrderItem>,subtotal: null == subtotal ? _self.subtotal : subtotal // ignore: cast_nullable_to_non_nullable
as double,deliveryFee: null == deliveryFee ? _self.deliveryFee : deliveryFee // ignore: cast_nullable_to_non_nullable
as double,discount: null == discount ? _self.discount : discount // ignore: cast_nullable_to_non_nullable
as double,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as OrderStatus,deliveryAddress: freezed == deliveryAddress ? _self.deliveryAddress : deliveryAddress // ignore: cast_nullable_to_non_nullable
as String?,paymentMethod: freezed == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as String?,paymentStatus: null == paymentStatus ? _self.paymentStatus : paymentStatus // ignore: cast_nullable_to_non_nullable
as PaymentStatus,paymentId: freezed == paymentId ? _self.paymentId : paymentId // ignore: cast_nullable_to_non_nullable
as String?,transactionId: freezed == transactionId ? _self.transactionId : transactionId // ignore: cast_nullable_to_non_nullable
as String?,specialInstructions: freezed == specialInstructions ? _self.specialInstructions : specialInstructions // ignore: cast_nullable_to_non_nullable
as String?,confirmedAt: freezed == confirmedAt ? _self.confirmedAt : confirmedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,preparingAt: freezed == preparingAt ? _self.preparingAt : preparingAt // ignore: cast_nullable_to_non_nullable
as DateTime?,readyAt: freezed == readyAt ? _self.readyAt : readyAt // ignore: cast_nullable_to_non_nullable
as DateTime?,deliveredAt: freezed == deliveredAt ? _self.deliveredAt : deliveredAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cancelledAt: freezed == cancelledAt ? _self.cancelledAt : cancelledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cancellationReason: freezed == cancellationReason ? _self.cancellationReason : cancellationReason // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$OrderItem {

 String get productId; String get productName; String? get variantName; int get quantity; double get unitPrice; double get totalPrice;
/// Create a copy of OrderItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrderItemCopyWith<OrderItem> get copyWith => _$OrderItemCopyWithImpl<OrderItem>(this as OrderItem, _$identity);

  /// Serializes this OrderItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as OrderItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrderItem&&(identical(other.productId, _this.productId) || other.productId == _this.productId)&&(identical(other.productName, _this.productName) || other.productName == _this.productName)&&(identical(other.variantName, _this.variantName) || other.variantName == _this.variantName)&&(identical(other.quantity, _this.quantity) || other.quantity == _this.quantity)&&(identical(other.unitPrice, _this.unitPrice) || other.unitPrice == _this.unitPrice)&&(identical(other.totalPrice, _this.totalPrice) || other.totalPrice == _this.totalPrice));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as OrderItem;
  return Object.hash(runtimeType,_this.productId,_this.productName,_this.variantName,_this.quantity,_this.unitPrice,_this.totalPrice);
}

@override
String toString() {
  final _this = this as OrderItem;
  return 'OrderItem(productId: ${_this.productId}, productName: ${_this.productName}, variantName: ${_this.variantName}, quantity: ${_this.quantity}, unitPrice: ${_this.unitPrice}, totalPrice: ${_this.totalPrice})';
}


}

/// @nodoc
abstract mixin class $OrderItemCopyWith<$Res>  {
  factory $OrderItemCopyWith(OrderItem value, $Res Function(OrderItem) _then) = _$OrderItemCopyWithImpl;
@useResult
$Res call({
 String productId, String productName, String? variantName, int quantity, double unitPrice, double totalPrice
});




}
/// @nodoc
class _$OrderItemCopyWithImpl<$Res>
    implements $OrderItemCopyWith<$Res> {
  _$OrderItemCopyWithImpl(this._self, this._then);

  final OrderItem _self;
  final $Res Function(OrderItem) _then;

/// Create a copy of OrderItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? productId = null,Object? productName = null,Object? variantName = freezed,Object? quantity = null,Object? unitPrice = null,Object? totalPrice = null,}) {
  return _then(OrderItem(
productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String,productName: null == productName ? _self.productName : productName // ignore: cast_nullable_to_non_nullable
as String,variantName: freezed == variantName ? _self.variantName : variantName // ignore: cast_nullable_to_non_nullable
as String?,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,unitPrice: null == unitPrice ? _self.unitPrice : unitPrice // ignore: cast_nullable_to_non_nullable
as double,totalPrice: null == totalPrice ? _self.totalPrice : totalPrice // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [OrderItem].
extension OrderItemPatterns on OrderItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrderItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrderItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrderItem value)  $default,){
final _that = this;
switch (_that) {
case _OrderItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrderItem value)?  $default,){
final _that = this;
switch (_that) {
case _OrderItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String productId,  String productName,  String? variantName,  int quantity,  double unitPrice,  double totalPrice)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrderItem() when $default != null:
return $default(_that.productId,_that.productName,_that.variantName,_that.quantity,_that.unitPrice,_that.totalPrice);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String productId,  String productName,  String? variantName,  int quantity,  double unitPrice,  double totalPrice)  $default,) {final _that = this;
switch (_that) {
case _OrderItem():
return $default(_that.productId,_that.productName,_that.variantName,_that.quantity,_that.unitPrice,_that.totalPrice);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String productId,  String productName,  String? variantName,  int quantity,  double unitPrice,  double totalPrice)?  $default,) {final _that = this;
switch (_that) {
case _OrderItem() when $default != null:
return $default(_that.productId,_that.productName,_that.variantName,_that.quantity,_that.unitPrice,_that.totalPrice);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OrderItem implements OrderItem {
  const _OrderItem({required this.productId, required this.productName, this.variantName, required this.quantity, required this.unitPrice, required this.totalPrice});
  factory _OrderItem.fromJson(Map<String, dynamic> json) => _$OrderItemFromJson(json);

@override final  String productId;
@override final  String productName;
@override final  String? variantName;
@override final  int quantity;
@override final  double unitPrice;
@override final  double totalPrice;

/// Create a copy of OrderItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrderItemCopyWith<_OrderItem> get copyWith => __$OrderItemCopyWithImpl<_OrderItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrderItemToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrderItem&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.productName, productName) || other.productName == productName)&&(identical(other.variantName, variantName) || other.variantName == variantName)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.unitPrice, unitPrice) || other.unitPrice == unitPrice)&&(identical(other.totalPrice, totalPrice) || other.totalPrice == totalPrice));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,productId,productName,variantName,quantity,unitPrice,totalPrice);
}

@override
String toString() {
    return 'OrderItem(productId: $productId, productName: $productName, variantName: $variantName, quantity: $quantity, unitPrice: $unitPrice, totalPrice: $totalPrice)';
}


}

/// @nodoc
abstract mixin class _$OrderItemCopyWith<$Res> implements $OrderItemCopyWith<$Res> {
  factory _$OrderItemCopyWith(_OrderItem value, $Res Function(_OrderItem) _then) = __$OrderItemCopyWithImpl;
@override @useResult
$Res call({
 String productId, String productName, String? variantName, int quantity, double unitPrice, double totalPrice
});




}
/// @nodoc
class __$OrderItemCopyWithImpl<$Res>
    implements _$OrderItemCopyWith<$Res> {
  __$OrderItemCopyWithImpl(this._self, this._then);

  final _OrderItem _self;
  final $Res Function(_OrderItem) _then;

/// Create a copy of OrderItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? productId = null,Object? productName = null,Object? variantName = freezed,Object? quantity = null,Object? unitPrice = null,Object? totalPrice = null,}) {
  return _then(_OrderItem(
productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String,productName: null == productName ? _self.productName : productName // ignore: cast_nullable_to_non_nullable
as String,variantName: freezed == variantName ? _self.variantName : variantName // ignore: cast_nullable_to_non_nullable
as String?,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,unitPrice: null == unitPrice ? _self.unitPrice : unitPrice // ignore: cast_nullable_to_non_nullable
as double,totalPrice: null == totalPrice ? _self.totalPrice : totalPrice // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
