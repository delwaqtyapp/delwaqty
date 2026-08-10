// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'order.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Order _$OrderFromJson(Map<String, dynamic> json) {
  return _Order.fromJson(json);
}

/// @nodoc
mixin _$Order {
  String get id => throw _privateConstructorUsedError;
  String get merchantId => throw _privateConstructorUsedError;
  String get merchantName => throw _privateConstructorUsedError;
  List<OrderItem> get items => throw _privateConstructorUsedError;
  double get subtotal => throw _privateConstructorUsedError;
  double get deliveryFee => throw _privateConstructorUsedError;
  double get discount => throw _privateConstructorUsedError;
  double get total => throw _privateConstructorUsedError;
  OrderStatus get status => throw _privateConstructorUsedError;
  String? get deliveryAddress => throw _privateConstructorUsedError;
  String? get paymentMethod => throw _privateConstructorUsedError;
  PaymentStatus get paymentStatus => throw _privateConstructorUsedError;
  String? get paymentId => throw _privateConstructorUsedError;
  String? get transactionId => throw _privateConstructorUsedError;
  String? get specialInstructions => throw _privateConstructorUsedError;
  DateTime? get confirmedAt => throw _privateConstructorUsedError;
  DateTime? get preparingAt => throw _privateConstructorUsedError;
  DateTime? get readyAt => throw _privateConstructorUsedError;
  DateTime? get deliveredAt => throw _privateConstructorUsedError;
  DateTime? get cancelledAt => throw _privateConstructorUsedError;
  String? get cancellationReason => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this Order to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Order
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OrderCopyWith<Order> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OrderCopyWith<$Res> {
  factory $OrderCopyWith(Order value, $Res Function(Order) then) =
      _$OrderCopyWithImpl<$Res, Order>;
  @useResult
  $Res call({
    String id,
    String merchantId,
    String merchantName,
    List<OrderItem> items,
    double subtotal,
    double deliveryFee,
    double discount,
    double total,
    OrderStatus status,
    String? deliveryAddress,
    String? paymentMethod,
    PaymentStatus paymentStatus,
    String? paymentId,
    String? transactionId,
    String? specialInstructions,
    DateTime? confirmedAt,
    DateTime? preparingAt,
    DateTime? readyAt,
    DateTime? deliveredAt,
    DateTime? cancelledAt,
    String? cancellationReason,
    DateTime createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class _$OrderCopyWithImpl<$Res, $Val extends Order>
    implements $OrderCopyWith<$Res> {
  _$OrderCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Order
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? merchantId = null,
    Object? merchantName = null,
    Object? items = null,
    Object? subtotal = null,
    Object? deliveryFee = null,
    Object? discount = null,
    Object? total = null,
    Object? status = null,
    Object? deliveryAddress = freezed,
    Object? paymentMethod = freezed,
    Object? paymentStatus = null,
    Object? paymentId = freezed,
    Object? transactionId = freezed,
    Object? specialInstructions = freezed,
    Object? confirmedAt = freezed,
    Object? preparingAt = freezed,
    Object? readyAt = freezed,
    Object? deliveredAt = freezed,
    Object? cancelledAt = freezed,
    Object? cancellationReason = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
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
            merchantName: null == merchantName
                ? _value.merchantName
                : merchantName // ignore: cast_nullable_to_non_nullable
                      as String,
            items: null == items
                ? _value.items
                : items // ignore: cast_nullable_to_non_nullable
                      as List<OrderItem>,
            subtotal: null == subtotal
                ? _value.subtotal
                : subtotal // ignore: cast_nullable_to_non_nullable
                      as double,
            deliveryFee: null == deliveryFee
                ? _value.deliveryFee
                : deliveryFee // ignore: cast_nullable_to_non_nullable
                      as double,
            discount: null == discount
                ? _value.discount
                : discount // ignore: cast_nullable_to_non_nullable
                      as double,
            total: null == total
                ? _value.total
                : total // ignore: cast_nullable_to_non_nullable
                      as double,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as OrderStatus,
            deliveryAddress: freezed == deliveryAddress
                ? _value.deliveryAddress
                : deliveryAddress // ignore: cast_nullable_to_non_nullable
                      as String?,
            paymentMethod: freezed == paymentMethod
                ? _value.paymentMethod
                : paymentMethod // ignore: cast_nullable_to_non_nullable
                      as String?,
            paymentStatus: null == paymentStatus
                ? _value.paymentStatus
                : paymentStatus // ignore: cast_nullable_to_non_nullable
                      as PaymentStatus,
            paymentId: freezed == paymentId
                ? _value.paymentId
                : paymentId // ignore: cast_nullable_to_non_nullable
                      as String?,
            transactionId: freezed == transactionId
                ? _value.transactionId
                : transactionId // ignore: cast_nullable_to_non_nullable
                      as String?,
            specialInstructions: freezed == specialInstructions
                ? _value.specialInstructions
                : specialInstructions // ignore: cast_nullable_to_non_nullable
                      as String?,
            confirmedAt: freezed == confirmedAt
                ? _value.confirmedAt
                : confirmedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            preparingAt: freezed == preparingAt
                ? _value.preparingAt
                : preparingAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            readyAt: freezed == readyAt
                ? _value.readyAt
                : readyAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            deliveredAt: freezed == deliveredAt
                ? _value.deliveredAt
                : deliveredAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            cancelledAt: freezed == cancelledAt
                ? _value.cancelledAt
                : cancelledAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            cancellationReason: freezed == cancellationReason
                ? _value.cancellationReason
                : cancellationReason // ignore: cast_nullable_to_non_nullable
                      as String?,
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
abstract class _$$OrderImplCopyWith<$Res> implements $OrderCopyWith<$Res> {
  factory _$$OrderImplCopyWith(
    _$OrderImpl value,
    $Res Function(_$OrderImpl) then,
  ) = __$$OrderImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String merchantId,
    String merchantName,
    List<OrderItem> items,
    double subtotal,
    double deliveryFee,
    double discount,
    double total,
    OrderStatus status,
    String? deliveryAddress,
    String? paymentMethod,
    PaymentStatus paymentStatus,
    String? paymentId,
    String? transactionId,
    String? specialInstructions,
    DateTime? confirmedAt,
    DateTime? preparingAt,
    DateTime? readyAt,
    DateTime? deliveredAt,
    DateTime? cancelledAt,
    String? cancellationReason,
    DateTime createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class __$$OrderImplCopyWithImpl<$Res>
    extends _$OrderCopyWithImpl<$Res, _$OrderImpl>
    implements _$$OrderImplCopyWith<$Res> {
  __$$OrderImplCopyWithImpl(
    _$OrderImpl _value,
    $Res Function(_$OrderImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Order
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? merchantId = null,
    Object? merchantName = null,
    Object? items = null,
    Object? subtotal = null,
    Object? deliveryFee = null,
    Object? discount = null,
    Object? total = null,
    Object? status = null,
    Object? deliveryAddress = freezed,
    Object? paymentMethod = freezed,
    Object? paymentStatus = null,
    Object? paymentId = freezed,
    Object? transactionId = freezed,
    Object? specialInstructions = freezed,
    Object? confirmedAt = freezed,
    Object? preparingAt = freezed,
    Object? readyAt = freezed,
    Object? deliveredAt = freezed,
    Object? cancelledAt = freezed,
    Object? cancellationReason = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$OrderImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        merchantId: null == merchantId
            ? _value.merchantId
            : merchantId // ignore: cast_nullable_to_non_nullable
                  as String,
        merchantName: null == merchantName
            ? _value.merchantName
            : merchantName // ignore: cast_nullable_to_non_nullable
                  as String,
        items: null == items
            ? _value._items
            : items // ignore: cast_nullable_to_non_nullable
                  as List<OrderItem>,
        subtotal: null == subtotal
            ? _value.subtotal
            : subtotal // ignore: cast_nullable_to_non_nullable
                  as double,
        deliveryFee: null == deliveryFee
            ? _value.deliveryFee
            : deliveryFee // ignore: cast_nullable_to_non_nullable
                  as double,
        discount: null == discount
            ? _value.discount
            : discount // ignore: cast_nullable_to_non_nullable
                  as double,
        total: null == total
            ? _value.total
            : total // ignore: cast_nullable_to_non_nullable
                  as double,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as OrderStatus,
        deliveryAddress: freezed == deliveryAddress
            ? _value.deliveryAddress
            : deliveryAddress // ignore: cast_nullable_to_non_nullable
                  as String?,
        paymentMethod: freezed == paymentMethod
            ? _value.paymentMethod
            : paymentMethod // ignore: cast_nullable_to_non_nullable
                  as String?,
        paymentStatus: null == paymentStatus
            ? _value.paymentStatus
            : paymentStatus // ignore: cast_nullable_to_non_nullable
                  as PaymentStatus,
        paymentId: freezed == paymentId
            ? _value.paymentId
            : paymentId // ignore: cast_nullable_to_non_nullable
                  as String?,
        transactionId: freezed == transactionId
            ? _value.transactionId
            : transactionId // ignore: cast_nullable_to_non_nullable
                  as String?,
        specialInstructions: freezed == specialInstructions
            ? _value.specialInstructions
            : specialInstructions // ignore: cast_nullable_to_non_nullable
                  as String?,
        confirmedAt: freezed == confirmedAt
            ? _value.confirmedAt
            : confirmedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        preparingAt: freezed == preparingAt
            ? _value.preparingAt
            : preparingAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        readyAt: freezed == readyAt
            ? _value.readyAt
            : readyAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        deliveredAt: freezed == deliveredAt
            ? _value.deliveredAt
            : deliveredAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        cancelledAt: freezed == cancelledAt
            ? _value.cancelledAt
            : cancelledAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        cancellationReason: freezed == cancellationReason
            ? _value.cancellationReason
            : cancellationReason // ignore: cast_nullable_to_non_nullable
                  as String?,
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
class _$OrderImpl implements _Order {
  const _$OrderImpl({
    required this.id,
    required this.merchantId,
    required this.merchantName,
    final List<OrderItem> items = const [],
    required this.subtotal,
    this.deliveryFee = 0.0,
    this.discount = 0.0,
    this.total = 0.0,
    required this.status,
    this.deliveryAddress,
    this.paymentMethod,
    this.paymentStatus = PaymentStatus.unpaid,
    this.paymentId,
    this.transactionId,
    this.specialInstructions,
    this.confirmedAt,
    this.preparingAt,
    this.readyAt,
    this.deliveredAt,
    this.cancelledAt,
    this.cancellationReason,
    required this.createdAt,
    this.updatedAt,
  }) : _items = items;

  factory _$OrderImpl.fromJson(Map<String, dynamic> json) =>
      _$$OrderImplFromJson(json);

  @override
  final String id;
  @override
  final String merchantId;
  @override
  final String merchantName;
  final List<OrderItem> _items;
  @override
  @JsonKey()
  List<OrderItem> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  final double subtotal;
  @override
  @JsonKey()
  final double deliveryFee;
  @override
  @JsonKey()
  final double discount;
  @override
  @JsonKey()
  final double total;
  @override
  final OrderStatus status;
  @override
  final String? deliveryAddress;
  @override
  final String? paymentMethod;
  @override
  @JsonKey()
  final PaymentStatus paymentStatus;
  @override
  final String? paymentId;
  @override
  final String? transactionId;
  @override
  final String? specialInstructions;
  @override
  final DateTime? confirmedAt;
  @override
  final DateTime? preparingAt;
  @override
  final DateTime? readyAt;
  @override
  final DateTime? deliveredAt;
  @override
  final DateTime? cancelledAt;
  @override
  final String? cancellationReason;
  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'Order(id: $id, merchantId: $merchantId, merchantName: $merchantName, items: $items, subtotal: $subtotal, deliveryFee: $deliveryFee, discount: $discount, total: $total, status: $status, deliveryAddress: $deliveryAddress, paymentMethod: $paymentMethod, paymentStatus: $paymentStatus, paymentId: $paymentId, transactionId: $transactionId, specialInstructions: $specialInstructions, confirmedAt: $confirmedAt, preparingAt: $preparingAt, readyAt: $readyAt, deliveredAt: $deliveredAt, cancelledAt: $cancelledAt, cancellationReason: $cancellationReason, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrderImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.merchantId, merchantId) ||
                other.merchantId == merchantId) &&
            (identical(other.merchantName, merchantName) ||
                other.merchantName == merchantName) &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.subtotal, subtotal) ||
                other.subtotal == subtotal) &&
            (identical(other.deliveryFee, deliveryFee) ||
                other.deliveryFee == deliveryFee) &&
            (identical(other.discount, discount) ||
                other.discount == discount) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.deliveryAddress, deliveryAddress) ||
                other.deliveryAddress == deliveryAddress) &&
            (identical(other.paymentMethod, paymentMethod) ||
                other.paymentMethod == paymentMethod) &&
            (identical(other.paymentStatus, paymentStatus) ||
                other.paymentStatus == paymentStatus) &&
            (identical(other.paymentId, paymentId) ||
                other.paymentId == paymentId) &&
            (identical(other.transactionId, transactionId) ||
                other.transactionId == transactionId) &&
            (identical(other.specialInstructions, specialInstructions) ||
                other.specialInstructions == specialInstructions) &&
            (identical(other.confirmedAt, confirmedAt) ||
                other.confirmedAt == confirmedAt) &&
            (identical(other.preparingAt, preparingAt) ||
                other.preparingAt == preparingAt) &&
            (identical(other.readyAt, readyAt) || other.readyAt == readyAt) &&
            (identical(other.deliveredAt, deliveredAt) ||
                other.deliveredAt == deliveredAt) &&
            (identical(other.cancelledAt, cancelledAt) ||
                other.cancelledAt == cancelledAt) &&
            (identical(other.cancellationReason, cancellationReason) ||
                other.cancellationReason == cancellationReason) &&
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
    merchantId,
    merchantName,
    const DeepCollectionEquality().hash(_items),
    subtotal,
    deliveryFee,
    discount,
    total,
    status,
    deliveryAddress,
    paymentMethod,
    paymentStatus,
    paymentId,
    transactionId,
    specialInstructions,
    confirmedAt,
    preparingAt,
    readyAt,
    deliveredAt,
    cancelledAt,
    cancellationReason,
    createdAt,
    updatedAt,
  ]);

  /// Create a copy of Order
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrderImplCopyWith<_$OrderImpl> get copyWith =>
      __$$OrderImplCopyWithImpl<_$OrderImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OrderImplToJson(this);
  }
}

abstract class _Order implements Order {
  const factory _Order({
    required final String id,
    required final String merchantId,
    required final String merchantName,
    final List<OrderItem> items,
    required final double subtotal,
    final double deliveryFee,
    final double discount,
    final double total,
    required final OrderStatus status,
    final String? deliveryAddress,
    final String? paymentMethod,
    final PaymentStatus paymentStatus,
    final String? paymentId,
    final String? transactionId,
    final String? specialInstructions,
    final DateTime? confirmedAt,
    final DateTime? preparingAt,
    final DateTime? readyAt,
    final DateTime? deliveredAt,
    final DateTime? cancelledAt,
    final String? cancellationReason,
    required final DateTime createdAt,
    final DateTime? updatedAt,
  }) = _$OrderImpl;

  factory _Order.fromJson(Map<String, dynamic> json) = _$OrderImpl.fromJson;

  @override
  String get id;
  @override
  String get merchantId;
  @override
  String get merchantName;
  @override
  List<OrderItem> get items;
  @override
  double get subtotal;
  @override
  double get deliveryFee;
  @override
  double get discount;
  @override
  double get total;
  @override
  OrderStatus get status;
  @override
  String? get deliveryAddress;
  @override
  String? get paymentMethod;
  @override
  PaymentStatus get paymentStatus;
  @override
  String? get paymentId;
  @override
  String? get transactionId;
  @override
  String? get specialInstructions;
  @override
  DateTime? get confirmedAt;
  @override
  DateTime? get preparingAt;
  @override
  DateTime? get readyAt;
  @override
  DateTime? get deliveredAt;
  @override
  DateTime? get cancelledAt;
  @override
  String? get cancellationReason;
  @override
  DateTime get createdAt;
  @override
  DateTime? get updatedAt;

  /// Create a copy of Order
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrderImplCopyWith<_$OrderImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

OrderItem _$OrderItemFromJson(Map<String, dynamic> json) {
  return _OrderItem.fromJson(json);
}

/// @nodoc
mixin _$OrderItem {
  String get productId => throw _privateConstructorUsedError;
  String get productName => throw _privateConstructorUsedError;
  String? get variantName => throw _privateConstructorUsedError;
  int get quantity => throw _privateConstructorUsedError;
  double get unitPrice => throw _privateConstructorUsedError;
  double get totalPrice => throw _privateConstructorUsedError;

  /// Serializes this OrderItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OrderItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OrderItemCopyWith<OrderItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OrderItemCopyWith<$Res> {
  factory $OrderItemCopyWith(OrderItem value, $Res Function(OrderItem) then) =
      _$OrderItemCopyWithImpl<$Res, OrderItem>;
  @useResult
  $Res call({
    String productId,
    String productName,
    String? variantName,
    int quantity,
    double unitPrice,
    double totalPrice,
  });
}

/// @nodoc
class _$OrderItemCopyWithImpl<$Res, $Val extends OrderItem>
    implements $OrderItemCopyWith<$Res> {
  _$OrderItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OrderItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? productId = null,
    Object? productName = null,
    Object? variantName = freezed,
    Object? quantity = null,
    Object? unitPrice = null,
    Object? totalPrice = null,
  }) {
    return _then(
      _value.copyWith(
            productId: null == productId
                ? _value.productId
                : productId // ignore: cast_nullable_to_non_nullable
                      as String,
            productName: null == productName
                ? _value.productName
                : productName // ignore: cast_nullable_to_non_nullable
                      as String,
            variantName: freezed == variantName
                ? _value.variantName
                : variantName // ignore: cast_nullable_to_non_nullable
                      as String?,
            quantity: null == quantity
                ? _value.quantity
                : quantity // ignore: cast_nullable_to_non_nullable
                      as int,
            unitPrice: null == unitPrice
                ? _value.unitPrice
                : unitPrice // ignore: cast_nullable_to_non_nullable
                      as double,
            totalPrice: null == totalPrice
                ? _value.totalPrice
                : totalPrice // ignore: cast_nullable_to_non_nullable
                      as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$OrderItemImplCopyWith<$Res>
    implements $OrderItemCopyWith<$Res> {
  factory _$$OrderItemImplCopyWith(
    _$OrderItemImpl value,
    $Res Function(_$OrderItemImpl) then,
  ) = __$$OrderItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String productId,
    String productName,
    String? variantName,
    int quantity,
    double unitPrice,
    double totalPrice,
  });
}

/// @nodoc
class __$$OrderItemImplCopyWithImpl<$Res>
    extends _$OrderItemCopyWithImpl<$Res, _$OrderItemImpl>
    implements _$$OrderItemImplCopyWith<$Res> {
  __$$OrderItemImplCopyWithImpl(
    _$OrderItemImpl _value,
    $Res Function(_$OrderItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of OrderItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? productId = null,
    Object? productName = null,
    Object? variantName = freezed,
    Object? quantity = null,
    Object? unitPrice = null,
    Object? totalPrice = null,
  }) {
    return _then(
      _$OrderItemImpl(
        productId: null == productId
            ? _value.productId
            : productId // ignore: cast_nullable_to_non_nullable
                  as String,
        productName: null == productName
            ? _value.productName
            : productName // ignore: cast_nullable_to_non_nullable
                  as String,
        variantName: freezed == variantName
            ? _value.variantName
            : variantName // ignore: cast_nullable_to_non_nullable
                  as String?,
        quantity: null == quantity
            ? _value.quantity
            : quantity // ignore: cast_nullable_to_non_nullable
                  as int,
        unitPrice: null == unitPrice
            ? _value.unitPrice
            : unitPrice // ignore: cast_nullable_to_non_nullable
                  as double,
        totalPrice: null == totalPrice
            ? _value.totalPrice
            : totalPrice // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$OrderItemImpl implements _OrderItem {
  const _$OrderItemImpl({
    required this.productId,
    required this.productName,
    this.variantName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory _$OrderItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$OrderItemImplFromJson(json);

  @override
  final String productId;
  @override
  final String productName;
  @override
  final String? variantName;
  @override
  final int quantity;
  @override
  final double unitPrice;
  @override
  final double totalPrice;

  @override
  String toString() {
    return 'OrderItem(productId: $productId, productName: $productName, variantName: $variantName, quantity: $quantity, unitPrice: $unitPrice, totalPrice: $totalPrice)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrderItemImpl &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.productName, productName) ||
                other.productName == productName) &&
            (identical(other.variantName, variantName) ||
                other.variantName == variantName) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.unitPrice, unitPrice) ||
                other.unitPrice == unitPrice) &&
            (identical(other.totalPrice, totalPrice) ||
                other.totalPrice == totalPrice));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    productId,
    productName,
    variantName,
    quantity,
    unitPrice,
    totalPrice,
  );

  /// Create a copy of OrderItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrderItemImplCopyWith<_$OrderItemImpl> get copyWith =>
      __$$OrderItemImplCopyWithImpl<_$OrderItemImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OrderItemImplToJson(this);
  }
}

abstract class _OrderItem implements OrderItem {
  const factory _OrderItem({
    required final String productId,
    required final String productName,
    final String? variantName,
    required final int quantity,
    required final double unitPrice,
    required final double totalPrice,
  }) = _$OrderItemImpl;

  factory _OrderItem.fromJson(Map<String, dynamic> json) =
      _$OrderItemImpl.fromJson;

  @override
  String get productId;
  @override
  String get productName;
  @override
  String? get variantName;
  @override
  int get quantity;
  @override
  double get unitPrice;
  @override
  double get totalPrice;

  /// Create a copy of OrderItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrderItemImplCopyWith<_$OrderItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
