// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'delivery_order.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DeliveryOrder {

 String get id; String get serviceType; String? get merchantId; String? get merchantName; String? get merchantAddress; String? get riderId; String? get driverId; String? get driverName; String? get driverPhone; double get pickupLatitude; double get pickupLongitude; String get pickupAddress; String? get pickupNotes; double get dropoffLatitude; double get dropoffLongitude; String get dropoffAddress; String? get dropoffNotes; String get priority; String get status; double? get fare; double? get deliveryFee; String get currency; double? get distance; int? get estimatedMinutes; String? get itemsSummary; double? get weightKg; bool get signatureRequired; bool get otpRequired; String? get deliveryProofUrl; DateTime? get scheduledAt; DateTime? get createdAt; DateTime? get matchedAt; DateTime? get arrivedAt; DateTime? get startedAt; DateTime? get completedAt; DateTime? get cancelledAt; String? get cancellationReason; String? get recipientName; String? get recipientPhone; String? get pickupOtp;
/// Create a copy of DeliveryOrder
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeliveryOrderCopyWith<DeliveryOrder> get copyWith => _$DeliveryOrderCopyWithImpl<DeliveryOrder>(this as DeliveryOrder, _$identity);

  /// Serializes this DeliveryOrder to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DeliveryOrder;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeliveryOrder&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.serviceType, _this.serviceType) || other.serviceType == _this.serviceType)&&(identical(other.merchantId, _this.merchantId) || other.merchantId == _this.merchantId)&&(identical(other.merchantName, _this.merchantName) || other.merchantName == _this.merchantName)&&(identical(other.merchantAddress, _this.merchantAddress) || other.merchantAddress == _this.merchantAddress)&&(identical(other.riderId, _this.riderId) || other.riderId == _this.riderId)&&(identical(other.driverId, _this.driverId) || other.driverId == _this.driverId)&&(identical(other.driverName, _this.driverName) || other.driverName == _this.driverName)&&(identical(other.driverPhone, _this.driverPhone) || other.driverPhone == _this.driverPhone)&&(identical(other.pickupLatitude, _this.pickupLatitude) || other.pickupLatitude == _this.pickupLatitude)&&(identical(other.pickupLongitude, _this.pickupLongitude) || other.pickupLongitude == _this.pickupLongitude)&&(identical(other.pickupAddress, _this.pickupAddress) || other.pickupAddress == _this.pickupAddress)&&(identical(other.pickupNotes, _this.pickupNotes) || other.pickupNotes == _this.pickupNotes)&&(identical(other.dropoffLatitude, _this.dropoffLatitude) || other.dropoffLatitude == _this.dropoffLatitude)&&(identical(other.dropoffLongitude, _this.dropoffLongitude) || other.dropoffLongitude == _this.dropoffLongitude)&&(identical(other.dropoffAddress, _this.dropoffAddress) || other.dropoffAddress == _this.dropoffAddress)&&(identical(other.dropoffNotes, _this.dropoffNotes) || other.dropoffNotes == _this.dropoffNotes)&&(identical(other.priority, _this.priority) || other.priority == _this.priority)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.fare, _this.fare) || other.fare == _this.fare)&&(identical(other.deliveryFee, _this.deliveryFee) || other.deliveryFee == _this.deliveryFee)&&(identical(other.currency, _this.currency) || other.currency == _this.currency)&&(identical(other.distance, _this.distance) || other.distance == _this.distance)&&(identical(other.estimatedMinutes, _this.estimatedMinutes) || other.estimatedMinutes == _this.estimatedMinutes)&&(identical(other.itemsSummary, _this.itemsSummary) || other.itemsSummary == _this.itemsSummary)&&(identical(other.weightKg, _this.weightKg) || other.weightKg == _this.weightKg)&&(identical(other.signatureRequired, _this.signatureRequired) || other.signatureRequired == _this.signatureRequired)&&(identical(other.otpRequired, _this.otpRequired) || other.otpRequired == _this.otpRequired)&&(identical(other.deliveryProofUrl, _this.deliveryProofUrl) || other.deliveryProofUrl == _this.deliveryProofUrl)&&(identical(other.scheduledAt, _this.scheduledAt) || other.scheduledAt == _this.scheduledAt)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.matchedAt, _this.matchedAt) || other.matchedAt == _this.matchedAt)&&(identical(other.arrivedAt, _this.arrivedAt) || other.arrivedAt == _this.arrivedAt)&&(identical(other.startedAt, _this.startedAt) || other.startedAt == _this.startedAt)&&(identical(other.completedAt, _this.completedAt) || other.completedAt == _this.completedAt)&&(identical(other.cancelledAt, _this.cancelledAt) || other.cancelledAt == _this.cancelledAt)&&(identical(other.cancellationReason, _this.cancellationReason) || other.cancellationReason == _this.cancellationReason)&&(identical(other.recipientName, _this.recipientName) || other.recipientName == _this.recipientName)&&(identical(other.recipientPhone, _this.recipientPhone) || other.recipientPhone == _this.recipientPhone)&&(identical(other.pickupOtp, _this.pickupOtp) || other.pickupOtp == _this.pickupOtp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DeliveryOrder;
  return Object.hashAll([runtimeType,_this.id,_this.serviceType,_this.merchantId,_this.merchantName,_this.merchantAddress,_this.riderId,_this.driverId,_this.driverName,_this.driverPhone,_this.pickupLatitude,_this.pickupLongitude,_this.pickupAddress,_this.pickupNotes,_this.dropoffLatitude,_this.dropoffLongitude,_this.dropoffAddress,_this.dropoffNotes,_this.priority,_this.status,_this.fare,_this.deliveryFee,_this.currency,_this.distance,_this.estimatedMinutes,_this.itemsSummary,_this.weightKg,_this.signatureRequired,_this.otpRequired,_this.deliveryProofUrl,_this.scheduledAt,_this.createdAt,_this.matchedAt,_this.arrivedAt,_this.startedAt,_this.completedAt,_this.cancelledAt,_this.cancellationReason,_this.recipientName,_this.recipientPhone,_this.pickupOtp]);
}

@override
String toString() {
  final _this = this as DeliveryOrder;
  return 'DeliveryOrder(id: ${_this.id}, serviceType: ${_this.serviceType}, merchantId: ${_this.merchantId}, merchantName: ${_this.merchantName}, merchantAddress: ${_this.merchantAddress}, riderId: ${_this.riderId}, driverId: ${_this.driverId}, driverName: ${_this.driverName}, driverPhone: ${_this.driverPhone}, pickupLatitude: ${_this.pickupLatitude}, pickupLongitude: ${_this.pickupLongitude}, pickupAddress: ${_this.pickupAddress}, pickupNotes: ${_this.pickupNotes}, dropoffLatitude: ${_this.dropoffLatitude}, dropoffLongitude: ${_this.dropoffLongitude}, dropoffAddress: ${_this.dropoffAddress}, dropoffNotes: ${_this.dropoffNotes}, priority: ${_this.priority}, status: ${_this.status}, fare: ${_this.fare}, deliveryFee: ${_this.deliveryFee}, currency: ${_this.currency}, distance: ${_this.distance}, estimatedMinutes: ${_this.estimatedMinutes}, itemsSummary: ${_this.itemsSummary}, weightKg: ${_this.weightKg}, signatureRequired: ${_this.signatureRequired}, otpRequired: ${_this.otpRequired}, deliveryProofUrl: ${_this.deliveryProofUrl}, scheduledAt: ${_this.scheduledAt}, createdAt: ${_this.createdAt}, matchedAt: ${_this.matchedAt}, arrivedAt: ${_this.arrivedAt}, startedAt: ${_this.startedAt}, completedAt: ${_this.completedAt}, cancelledAt: ${_this.cancelledAt}, cancellationReason: ${_this.cancellationReason}, recipientName: ${_this.recipientName}, recipientPhone: ${_this.recipientPhone}, pickupOtp: ${_this.pickupOtp})';
}


}

/// @nodoc
abstract mixin class $DeliveryOrderCopyWith<$Res>  {
  factory $DeliveryOrderCopyWith(DeliveryOrder value, $Res Function(DeliveryOrder) _then) = _$DeliveryOrderCopyWithImpl;
@useResult
$Res call({
 String id, String serviceType, String? merchantId, String? merchantName, String? merchantAddress, String? riderId, String? driverId, String? driverName, String? driverPhone, double pickupLatitude, double pickupLongitude, String pickupAddress, String? pickupNotes, double dropoffLatitude, double dropoffLongitude, String dropoffAddress, String? dropoffNotes, String priority, String status, double? fare, double? deliveryFee, String currency, double? distance, int? estimatedMinutes, String? itemsSummary, double? weightKg, bool signatureRequired, bool otpRequired, String? deliveryProofUrl, DateTime? scheduledAt, DateTime? createdAt, DateTime? matchedAt, DateTime? arrivedAt, DateTime? startedAt, DateTime? completedAt, DateTime? cancelledAt, String? cancellationReason, String? recipientName, String? recipientPhone, String? pickupOtp
});




}
/// @nodoc
class _$DeliveryOrderCopyWithImpl<$Res>
    implements $DeliveryOrderCopyWith<$Res> {
  _$DeliveryOrderCopyWithImpl(this._self, this._then);

  final DeliveryOrder _self;
  final $Res Function(DeliveryOrder) _then;

/// Create a copy of DeliveryOrder
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? serviceType = null,Object? merchantId = freezed,Object? merchantName = freezed,Object? merchantAddress = freezed,Object? riderId = freezed,Object? driverId = freezed,Object? driverName = freezed,Object? driverPhone = freezed,Object? pickupLatitude = null,Object? pickupLongitude = null,Object? pickupAddress = null,Object? pickupNotes = freezed,Object? dropoffLatitude = null,Object? dropoffLongitude = null,Object? dropoffAddress = null,Object? dropoffNotes = freezed,Object? priority = null,Object? status = null,Object? fare = freezed,Object? deliveryFee = freezed,Object? currency = null,Object? distance = freezed,Object? estimatedMinutes = freezed,Object? itemsSummary = freezed,Object? weightKg = freezed,Object? signatureRequired = null,Object? otpRequired = null,Object? deliveryProofUrl = freezed,Object? scheduledAt = freezed,Object? createdAt = freezed,Object? matchedAt = freezed,Object? arrivedAt = freezed,Object? startedAt = freezed,Object? completedAt = freezed,Object? cancelledAt = freezed,Object? cancellationReason = freezed,Object? recipientName = freezed,Object? recipientPhone = freezed,Object? pickupOtp = freezed,}) {
  return _then(DeliveryOrder(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,serviceType: null == serviceType ? _self.serviceType : serviceType // ignore: cast_nullable_to_non_nullable
as String,merchantId: freezed == merchantId ? _self.merchantId : merchantId // ignore: cast_nullable_to_non_nullable
as String?,merchantName: freezed == merchantName ? _self.merchantName : merchantName // ignore: cast_nullable_to_non_nullable
as String?,merchantAddress: freezed == merchantAddress ? _self.merchantAddress : merchantAddress // ignore: cast_nullable_to_non_nullable
as String?,riderId: freezed == riderId ? _self.riderId : riderId // ignore: cast_nullable_to_non_nullable
as String?,driverId: freezed == driverId ? _self.driverId : driverId // ignore: cast_nullable_to_non_nullable
as String?,driverName: freezed == driverName ? _self.driverName : driverName // ignore: cast_nullable_to_non_nullable
as String?,driverPhone: freezed == driverPhone ? _self.driverPhone : driverPhone // ignore: cast_nullable_to_non_nullable
as String?,pickupLatitude: null == pickupLatitude ? _self.pickupLatitude : pickupLatitude // ignore: cast_nullable_to_non_nullable
as double,pickupLongitude: null == pickupLongitude ? _self.pickupLongitude : pickupLongitude // ignore: cast_nullable_to_non_nullable
as double,pickupAddress: null == pickupAddress ? _self.pickupAddress : pickupAddress // ignore: cast_nullable_to_non_nullable
as String,pickupNotes: freezed == pickupNotes ? _self.pickupNotes : pickupNotes // ignore: cast_nullable_to_non_nullable
as String?,dropoffLatitude: null == dropoffLatitude ? _self.dropoffLatitude : dropoffLatitude // ignore: cast_nullable_to_non_nullable
as double,dropoffLongitude: null == dropoffLongitude ? _self.dropoffLongitude : dropoffLongitude // ignore: cast_nullable_to_non_nullable
as double,dropoffAddress: null == dropoffAddress ? _self.dropoffAddress : dropoffAddress // ignore: cast_nullable_to_non_nullable
as String,dropoffNotes: freezed == dropoffNotes ? _self.dropoffNotes : dropoffNotes // ignore: cast_nullable_to_non_nullable
as String?,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,fare: freezed == fare ? _self.fare : fare // ignore: cast_nullable_to_non_nullable
as double?,deliveryFee: freezed == deliveryFee ? _self.deliveryFee : deliveryFee // ignore: cast_nullable_to_non_nullable
as double?,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,distance: freezed == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double?,estimatedMinutes: freezed == estimatedMinutes ? _self.estimatedMinutes : estimatedMinutes // ignore: cast_nullable_to_non_nullable
as int?,itemsSummary: freezed == itemsSummary ? _self.itemsSummary : itemsSummary // ignore: cast_nullable_to_non_nullable
as String?,weightKg: freezed == weightKg ? _self.weightKg : weightKg // ignore: cast_nullable_to_non_nullable
as double?,signatureRequired: null == signatureRequired ? _self.signatureRequired : signatureRequired // ignore: cast_nullable_to_non_nullable
as bool,otpRequired: null == otpRequired ? _self.otpRequired : otpRequired // ignore: cast_nullable_to_non_nullable
as bool,deliveryProofUrl: freezed == deliveryProofUrl ? _self.deliveryProofUrl : deliveryProofUrl // ignore: cast_nullable_to_non_nullable
as String?,scheduledAt: freezed == scheduledAt ? _self.scheduledAt : scheduledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,matchedAt: freezed == matchedAt ? _self.matchedAt : matchedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,arrivedAt: freezed == arrivedAt ? _self.arrivedAt : arrivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cancelledAt: freezed == cancelledAt ? _self.cancelledAt : cancelledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cancellationReason: freezed == cancellationReason ? _self.cancellationReason : cancellationReason // ignore: cast_nullable_to_non_nullable
as String?,recipientName: freezed == recipientName ? _self.recipientName : recipientName // ignore: cast_nullable_to_non_nullable
as String?,recipientPhone: freezed == recipientPhone ? _self.recipientPhone : recipientPhone // ignore: cast_nullable_to_non_nullable
as String?,pickupOtp: freezed == pickupOtp ? _self.pickupOtp : pickupOtp // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [DeliveryOrder].
extension DeliveryOrderPatterns on DeliveryOrder {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeliveryOrder value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeliveryOrder() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeliveryOrder value)  $default,){
final _that = this;
switch (_that) {
case _DeliveryOrder():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeliveryOrder value)?  $default,){
final _that = this;
switch (_that) {
case _DeliveryOrder() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String serviceType,  String? merchantId,  String? merchantName,  String? merchantAddress,  String? riderId,  String? driverId,  String? driverName,  String? driverPhone,  double pickupLatitude,  double pickupLongitude,  String pickupAddress,  String? pickupNotes,  double dropoffLatitude,  double dropoffLongitude,  String dropoffAddress,  String? dropoffNotes,  String priority,  String status,  double? fare,  double? deliveryFee,  String currency,  double? distance,  int? estimatedMinutes,  String? itemsSummary,  double? weightKg,  bool signatureRequired,  bool otpRequired,  String? deliveryProofUrl,  DateTime? scheduledAt,  DateTime? createdAt,  DateTime? matchedAt,  DateTime? arrivedAt,  DateTime? startedAt,  DateTime? completedAt,  DateTime? cancelledAt,  String? cancellationReason,  String? recipientName,  String? recipientPhone,  String? pickupOtp)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeliveryOrder() when $default != null:
return $default(_that.id,_that.serviceType,_that.merchantId,_that.merchantName,_that.merchantAddress,_that.riderId,_that.driverId,_that.driverName,_that.driverPhone,_that.pickupLatitude,_that.pickupLongitude,_that.pickupAddress,_that.pickupNotes,_that.dropoffLatitude,_that.dropoffLongitude,_that.dropoffAddress,_that.dropoffNotes,_that.priority,_that.status,_that.fare,_that.deliveryFee,_that.currency,_that.distance,_that.estimatedMinutes,_that.itemsSummary,_that.weightKg,_that.signatureRequired,_that.otpRequired,_that.deliveryProofUrl,_that.scheduledAt,_that.createdAt,_that.matchedAt,_that.arrivedAt,_that.startedAt,_that.completedAt,_that.cancelledAt,_that.cancellationReason,_that.recipientName,_that.recipientPhone,_that.pickupOtp);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String serviceType,  String? merchantId,  String? merchantName,  String? merchantAddress,  String? riderId,  String? driverId,  String? driverName,  String? driverPhone,  double pickupLatitude,  double pickupLongitude,  String pickupAddress,  String? pickupNotes,  double dropoffLatitude,  double dropoffLongitude,  String dropoffAddress,  String? dropoffNotes,  String priority,  String status,  double? fare,  double? deliveryFee,  String currency,  double? distance,  int? estimatedMinutes,  String? itemsSummary,  double? weightKg,  bool signatureRequired,  bool otpRequired,  String? deliveryProofUrl,  DateTime? scheduledAt,  DateTime? createdAt,  DateTime? matchedAt,  DateTime? arrivedAt,  DateTime? startedAt,  DateTime? completedAt,  DateTime? cancelledAt,  String? cancellationReason,  String? recipientName,  String? recipientPhone,  String? pickupOtp)  $default,) {final _that = this;
switch (_that) {
case _DeliveryOrder():
return $default(_that.id,_that.serviceType,_that.merchantId,_that.merchantName,_that.merchantAddress,_that.riderId,_that.driverId,_that.driverName,_that.driverPhone,_that.pickupLatitude,_that.pickupLongitude,_that.pickupAddress,_that.pickupNotes,_that.dropoffLatitude,_that.dropoffLongitude,_that.dropoffAddress,_that.dropoffNotes,_that.priority,_that.status,_that.fare,_that.deliveryFee,_that.currency,_that.distance,_that.estimatedMinutes,_that.itemsSummary,_that.weightKg,_that.signatureRequired,_that.otpRequired,_that.deliveryProofUrl,_that.scheduledAt,_that.createdAt,_that.matchedAt,_that.arrivedAt,_that.startedAt,_that.completedAt,_that.cancelledAt,_that.cancellationReason,_that.recipientName,_that.recipientPhone,_that.pickupOtp);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String serviceType,  String? merchantId,  String? merchantName,  String? merchantAddress,  String? riderId,  String? driverId,  String? driverName,  String? driverPhone,  double pickupLatitude,  double pickupLongitude,  String pickupAddress,  String? pickupNotes,  double dropoffLatitude,  double dropoffLongitude,  String dropoffAddress,  String? dropoffNotes,  String priority,  String status,  double? fare,  double? deliveryFee,  String currency,  double? distance,  int? estimatedMinutes,  String? itemsSummary,  double? weightKg,  bool signatureRequired,  bool otpRequired,  String? deliveryProofUrl,  DateTime? scheduledAt,  DateTime? createdAt,  DateTime? matchedAt,  DateTime? arrivedAt,  DateTime? startedAt,  DateTime? completedAt,  DateTime? cancelledAt,  String? cancellationReason,  String? recipientName,  String? recipientPhone,  String? pickupOtp)?  $default,) {final _that = this;
switch (_that) {
case _DeliveryOrder() when $default != null:
return $default(_that.id,_that.serviceType,_that.merchantId,_that.merchantName,_that.merchantAddress,_that.riderId,_that.driverId,_that.driverName,_that.driverPhone,_that.pickupLatitude,_that.pickupLongitude,_that.pickupAddress,_that.pickupNotes,_that.dropoffLatitude,_that.dropoffLongitude,_that.dropoffAddress,_that.dropoffNotes,_that.priority,_that.status,_that.fare,_that.deliveryFee,_that.currency,_that.distance,_that.estimatedMinutes,_that.itemsSummary,_that.weightKg,_that.signatureRequired,_that.otpRequired,_that.deliveryProofUrl,_that.scheduledAt,_that.createdAt,_that.matchedAt,_that.arrivedAt,_that.startedAt,_that.completedAt,_that.cancelledAt,_that.cancellationReason,_that.recipientName,_that.recipientPhone,_that.pickupOtp);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeliveryOrder implements DeliveryOrder {
  const _DeliveryOrder({required this.id, required this.serviceType, this.merchantId, this.merchantName, this.merchantAddress, this.riderId, this.driverId, this.driverName, this.driverPhone, required this.pickupLatitude, required this.pickupLongitude, this.pickupAddress = '', this.pickupNotes, required this.dropoffLatitude, required this.dropoffLongitude, this.dropoffAddress = '', this.dropoffNotes, this.priority = 'standard', this.status = 'searching', this.fare, this.deliveryFee, this.currency = 'EGP', this.distance, this.estimatedMinutes, this.itemsSummary, this.weightKg, this.signatureRequired = false, this.otpRequired = true, this.deliveryProofUrl, this.scheduledAt, this.createdAt, this.matchedAt, this.arrivedAt, this.startedAt, this.completedAt, this.cancelledAt, this.cancellationReason, this.recipientName, this.recipientPhone, this.pickupOtp});
  factory _DeliveryOrder.fromJson(Map<String, dynamic> json) => _$DeliveryOrderFromJson(json);

@override final  String id;
@override final  String serviceType;
@override final  String? merchantId;
@override final  String? merchantName;
@override final  String? merchantAddress;
@override final  String? riderId;
@override final  String? driverId;
@override final  String? driverName;
@override final  String? driverPhone;
@override final  double pickupLatitude;
@override final  double pickupLongitude;
@override@JsonKey() final  String pickupAddress;
@override final  String? pickupNotes;
@override final  double dropoffLatitude;
@override final  double dropoffLongitude;
@override@JsonKey() final  String dropoffAddress;
@override final  String? dropoffNotes;
@override@JsonKey() final  String priority;
@override@JsonKey() final  String status;
@override final  double? fare;
@override final  double? deliveryFee;
@override@JsonKey() final  String currency;
@override final  double? distance;
@override final  int? estimatedMinutes;
@override final  String? itemsSummary;
@override final  double? weightKg;
@override@JsonKey() final  bool signatureRequired;
@override@JsonKey() final  bool otpRequired;
@override final  String? deliveryProofUrl;
@override final  DateTime? scheduledAt;
@override final  DateTime? createdAt;
@override final  DateTime? matchedAt;
@override final  DateTime? arrivedAt;
@override final  DateTime? startedAt;
@override final  DateTime? completedAt;
@override final  DateTime? cancelledAt;
@override final  String? cancellationReason;
@override final  String? recipientName;
@override final  String? recipientPhone;
@override final  String? pickupOtp;

/// Create a copy of DeliveryOrder
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeliveryOrderCopyWith<_DeliveryOrder> get copyWith => __$DeliveryOrderCopyWithImpl<_DeliveryOrder>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeliveryOrderToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeliveryOrder&&(identical(other.id, id) || other.id == id)&&(identical(other.serviceType, serviceType) || other.serviceType == serviceType)&&(identical(other.merchantId, merchantId) || other.merchantId == merchantId)&&(identical(other.merchantName, merchantName) || other.merchantName == merchantName)&&(identical(other.merchantAddress, merchantAddress) || other.merchantAddress == merchantAddress)&&(identical(other.riderId, riderId) || other.riderId == riderId)&&(identical(other.driverId, driverId) || other.driverId == driverId)&&(identical(other.driverName, driverName) || other.driverName == driverName)&&(identical(other.driverPhone, driverPhone) || other.driverPhone == driverPhone)&&(identical(other.pickupLatitude, pickupLatitude) || other.pickupLatitude == pickupLatitude)&&(identical(other.pickupLongitude, pickupLongitude) || other.pickupLongitude == pickupLongitude)&&(identical(other.pickupAddress, pickupAddress) || other.pickupAddress == pickupAddress)&&(identical(other.pickupNotes, pickupNotes) || other.pickupNotes == pickupNotes)&&(identical(other.dropoffLatitude, dropoffLatitude) || other.dropoffLatitude == dropoffLatitude)&&(identical(other.dropoffLongitude, dropoffLongitude) || other.dropoffLongitude == dropoffLongitude)&&(identical(other.dropoffAddress, dropoffAddress) || other.dropoffAddress == dropoffAddress)&&(identical(other.dropoffNotes, dropoffNotes) || other.dropoffNotes == dropoffNotes)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.status, status) || other.status == status)&&(identical(other.fare, fare) || other.fare == fare)&&(identical(other.deliveryFee, deliveryFee) || other.deliveryFee == deliveryFee)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.distance, distance) || other.distance == distance)&&(identical(other.estimatedMinutes, estimatedMinutes) || other.estimatedMinutes == estimatedMinutes)&&(identical(other.itemsSummary, itemsSummary) || other.itemsSummary == itemsSummary)&&(identical(other.weightKg, weightKg) || other.weightKg == weightKg)&&(identical(other.signatureRequired, signatureRequired) || other.signatureRequired == signatureRequired)&&(identical(other.otpRequired, otpRequired) || other.otpRequired == otpRequired)&&(identical(other.deliveryProofUrl, deliveryProofUrl) || other.deliveryProofUrl == deliveryProofUrl)&&(identical(other.scheduledAt, scheduledAt) || other.scheduledAt == scheduledAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.matchedAt, matchedAt) || other.matchedAt == matchedAt)&&(identical(other.arrivedAt, arrivedAt) || other.arrivedAt == arrivedAt)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.cancelledAt, cancelledAt) || other.cancelledAt == cancelledAt)&&(identical(other.cancellationReason, cancellationReason) || other.cancellationReason == cancellationReason)&&(identical(other.recipientName, recipientName) || other.recipientName == recipientName)&&(identical(other.recipientPhone, recipientPhone) || other.recipientPhone == recipientPhone)&&(identical(other.pickupOtp, pickupOtp) || other.pickupOtp == pickupOtp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,id,serviceType,merchantId,merchantName,merchantAddress,riderId,driverId,driverName,driverPhone,pickupLatitude,pickupLongitude,pickupAddress,pickupNotes,dropoffLatitude,dropoffLongitude,dropoffAddress,dropoffNotes,priority,status,fare,deliveryFee,currency,distance,estimatedMinutes,itemsSummary,weightKg,signatureRequired,otpRequired,deliveryProofUrl,scheduledAt,createdAt,matchedAt,arrivedAt,startedAt,completedAt,cancelledAt,cancellationReason,recipientName,recipientPhone,pickupOtp]);
}

@override
String toString() {
    return 'DeliveryOrder(id: $id, serviceType: $serviceType, merchantId: $merchantId, merchantName: $merchantName, merchantAddress: $merchantAddress, riderId: $riderId, driverId: $driverId, driverName: $driverName, driverPhone: $driverPhone, pickupLatitude: $pickupLatitude, pickupLongitude: $pickupLongitude, pickupAddress: $pickupAddress, pickupNotes: $pickupNotes, dropoffLatitude: $dropoffLatitude, dropoffLongitude: $dropoffLongitude, dropoffAddress: $dropoffAddress, dropoffNotes: $dropoffNotes, priority: $priority, status: $status, fare: $fare, deliveryFee: $deliveryFee, currency: $currency, distance: $distance, estimatedMinutes: $estimatedMinutes, itemsSummary: $itemsSummary, weightKg: $weightKg, signatureRequired: $signatureRequired, otpRequired: $otpRequired, deliveryProofUrl: $deliveryProofUrl, scheduledAt: $scheduledAt, createdAt: $createdAt, matchedAt: $matchedAt, arrivedAt: $arrivedAt, startedAt: $startedAt, completedAt: $completedAt, cancelledAt: $cancelledAt, cancellationReason: $cancellationReason, recipientName: $recipientName, recipientPhone: $recipientPhone, pickupOtp: $pickupOtp)';
}


}

/// @nodoc
abstract mixin class _$DeliveryOrderCopyWith<$Res> implements $DeliveryOrderCopyWith<$Res> {
  factory _$DeliveryOrderCopyWith(_DeliveryOrder value, $Res Function(_DeliveryOrder) _then) = __$DeliveryOrderCopyWithImpl;
@override @useResult
$Res call({
 String id, String serviceType, String? merchantId, String? merchantName, String? merchantAddress, String? riderId, String? driverId, String? driverName, String? driverPhone, double pickupLatitude, double pickupLongitude, String pickupAddress, String? pickupNotes, double dropoffLatitude, double dropoffLongitude, String dropoffAddress, String? dropoffNotes, String priority, String status, double? fare, double? deliveryFee, String currency, double? distance, int? estimatedMinutes, String? itemsSummary, double? weightKg, bool signatureRequired, bool otpRequired, String? deliveryProofUrl, DateTime? scheduledAt, DateTime? createdAt, DateTime? matchedAt, DateTime? arrivedAt, DateTime? startedAt, DateTime? completedAt, DateTime? cancelledAt, String? cancellationReason, String? recipientName, String? recipientPhone, String? pickupOtp
});




}
/// @nodoc
class __$DeliveryOrderCopyWithImpl<$Res>
    implements _$DeliveryOrderCopyWith<$Res> {
  __$DeliveryOrderCopyWithImpl(this._self, this._then);

  final _DeliveryOrder _self;
  final $Res Function(_DeliveryOrder) _then;

/// Create a copy of DeliveryOrder
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? serviceType = null,Object? merchantId = freezed,Object? merchantName = freezed,Object? merchantAddress = freezed,Object? riderId = freezed,Object? driverId = freezed,Object? driverName = freezed,Object? driverPhone = freezed,Object? pickupLatitude = null,Object? pickupLongitude = null,Object? pickupAddress = null,Object? pickupNotes = freezed,Object? dropoffLatitude = null,Object? dropoffLongitude = null,Object? dropoffAddress = null,Object? dropoffNotes = freezed,Object? priority = null,Object? status = null,Object? fare = freezed,Object? deliveryFee = freezed,Object? currency = null,Object? distance = freezed,Object? estimatedMinutes = freezed,Object? itemsSummary = freezed,Object? weightKg = freezed,Object? signatureRequired = null,Object? otpRequired = null,Object? deliveryProofUrl = freezed,Object? scheduledAt = freezed,Object? createdAt = freezed,Object? matchedAt = freezed,Object? arrivedAt = freezed,Object? startedAt = freezed,Object? completedAt = freezed,Object? cancelledAt = freezed,Object? cancellationReason = freezed,Object? recipientName = freezed,Object? recipientPhone = freezed,Object? pickupOtp = freezed,}) {
  return _then(_DeliveryOrder(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,serviceType: null == serviceType ? _self.serviceType : serviceType // ignore: cast_nullable_to_non_nullable
as String,merchantId: freezed == merchantId ? _self.merchantId : merchantId // ignore: cast_nullable_to_non_nullable
as String?,merchantName: freezed == merchantName ? _self.merchantName : merchantName // ignore: cast_nullable_to_non_nullable
as String?,merchantAddress: freezed == merchantAddress ? _self.merchantAddress : merchantAddress // ignore: cast_nullable_to_non_nullable
as String?,riderId: freezed == riderId ? _self.riderId : riderId // ignore: cast_nullable_to_non_nullable
as String?,driverId: freezed == driverId ? _self.driverId : driverId // ignore: cast_nullable_to_non_nullable
as String?,driverName: freezed == driverName ? _self.driverName : driverName // ignore: cast_nullable_to_non_nullable
as String?,driverPhone: freezed == driverPhone ? _self.driverPhone : driverPhone // ignore: cast_nullable_to_non_nullable
as String?,pickupLatitude: null == pickupLatitude ? _self.pickupLatitude : pickupLatitude // ignore: cast_nullable_to_non_nullable
as double,pickupLongitude: null == pickupLongitude ? _self.pickupLongitude : pickupLongitude // ignore: cast_nullable_to_non_nullable
as double,pickupAddress: null == pickupAddress ? _self.pickupAddress : pickupAddress // ignore: cast_nullable_to_non_nullable
as String,pickupNotes: freezed == pickupNotes ? _self.pickupNotes : pickupNotes // ignore: cast_nullable_to_non_nullable
as String?,dropoffLatitude: null == dropoffLatitude ? _self.dropoffLatitude : dropoffLatitude // ignore: cast_nullable_to_non_nullable
as double,dropoffLongitude: null == dropoffLongitude ? _self.dropoffLongitude : dropoffLongitude // ignore: cast_nullable_to_non_nullable
as double,dropoffAddress: null == dropoffAddress ? _self.dropoffAddress : dropoffAddress // ignore: cast_nullable_to_non_nullable
as String,dropoffNotes: freezed == dropoffNotes ? _self.dropoffNotes : dropoffNotes // ignore: cast_nullable_to_non_nullable
as String?,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,fare: freezed == fare ? _self.fare : fare // ignore: cast_nullable_to_non_nullable
as double?,deliveryFee: freezed == deliveryFee ? _self.deliveryFee : deliveryFee // ignore: cast_nullable_to_non_nullable
as double?,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,distance: freezed == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double?,estimatedMinutes: freezed == estimatedMinutes ? _self.estimatedMinutes : estimatedMinutes // ignore: cast_nullable_to_non_nullable
as int?,itemsSummary: freezed == itemsSummary ? _self.itemsSummary : itemsSummary // ignore: cast_nullable_to_non_nullable
as String?,weightKg: freezed == weightKg ? _self.weightKg : weightKg // ignore: cast_nullable_to_non_nullable
as double?,signatureRequired: null == signatureRequired ? _self.signatureRequired : signatureRequired // ignore: cast_nullable_to_non_nullable
as bool,otpRequired: null == otpRequired ? _self.otpRequired : otpRequired // ignore: cast_nullable_to_non_nullable
as bool,deliveryProofUrl: freezed == deliveryProofUrl ? _self.deliveryProofUrl : deliveryProofUrl // ignore: cast_nullable_to_non_nullable
as String?,scheduledAt: freezed == scheduledAt ? _self.scheduledAt : scheduledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,matchedAt: freezed == matchedAt ? _self.matchedAt : matchedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,arrivedAt: freezed == arrivedAt ? _self.arrivedAt : arrivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cancelledAt: freezed == cancelledAt ? _self.cancelledAt : cancelledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cancellationReason: freezed == cancellationReason ? _self.cancellationReason : cancellationReason // ignore: cast_nullable_to_non_nullable
as String?,recipientName: freezed == recipientName ? _self.recipientName : recipientName // ignore: cast_nullable_to_non_nullable
as String?,recipientPhone: freezed == recipientPhone ? _self.recipientPhone : recipientPhone // ignore: cast_nullable_to_non_nullable
as String?,pickupOtp: freezed == pickupOtp ? _self.pickupOtp : pickupOtp // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
