// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$OrderImpl _$$OrderImplFromJson(Map<String, dynamic> json) => _$OrderImpl(
  id: json['id'] as String,
  merchantId: json['merchantId'] as String,
  merchantName: json['merchantName'] as String,
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  subtotal: (json['subtotal'] as num).toDouble(),
  deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0.0,
  discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
  total: (json['total'] as num?)?.toDouble() ?? 0.0,
  status: $enumDecode(_$OrderStatusEnumMap, json['status']),
  deliveryAddress: json['deliveryAddress'] as String?,
  paymentMethod: json['paymentMethod'] as String?,
  paymentStatus:
      $enumDecodeNullable(_$PaymentStatusEnumMap, json['paymentStatus']) ??
      PaymentStatus.unpaid,
  paymentId: json['paymentId'] as String?,
  transactionId: json['transactionId'] as String?,
  specialInstructions: json['specialInstructions'] as String?,
  confirmedAt: json['confirmedAt'] == null
      ? null
      : DateTime.parse(json['confirmedAt'] as String),
  preparingAt: json['preparingAt'] == null
      ? null
      : DateTime.parse(json['preparingAt'] as String),
  readyAt: json['readyAt'] == null
      ? null
      : DateTime.parse(json['readyAt'] as String),
  deliveredAt: json['deliveredAt'] == null
      ? null
      : DateTime.parse(json['deliveredAt'] as String),
  cancelledAt: json['cancelledAt'] == null
      ? null
      : DateTime.parse(json['cancelledAt'] as String),
  cancellationReason: json['cancellationReason'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$$OrderImplToJson(_$OrderImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'merchantId': instance.merchantId,
      'merchantName': instance.merchantName,
      'items': instance.items.map((e) => e.toJson()).toList(),
      'subtotal': instance.subtotal,
      'deliveryFee': instance.deliveryFee,
      'discount': instance.discount,
      'total': instance.total,
      'status': _$OrderStatusEnumMap[instance.status]!,
      'deliveryAddress': instance.deliveryAddress,
      'paymentMethod': instance.paymentMethod,
      'paymentStatus': _$PaymentStatusEnumMap[instance.paymentStatus]!,
      'paymentId': instance.paymentId,
      'transactionId': instance.transactionId,
      'specialInstructions': instance.specialInstructions,
      'confirmedAt': instance.confirmedAt?.toIso8601String(),
      'preparingAt': instance.preparingAt?.toIso8601String(),
      'readyAt': instance.readyAt?.toIso8601String(),
      'deliveredAt': instance.deliveredAt?.toIso8601String(),
      'cancelledAt': instance.cancelledAt?.toIso8601String(),
      'cancellationReason': instance.cancellationReason,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

const _$OrderStatusEnumMap = {
  OrderStatus.pending: 'pending',
  OrderStatus.confirmed: 'confirmed',
  OrderStatus.preparing: 'preparing',
  OrderStatus.ready: 'ready',
  OrderStatus.pickedUp: 'picked_up',
  OrderStatus.inTransit: 'in_transit',
  OrderStatus.delivered: 'delivered',
  OrderStatus.cancelled: 'cancelled',
};

const _$PaymentStatusEnumMap = {
  PaymentStatus.unpaid: 'unpaid',
  PaymentStatus.pending: 'pending',
  PaymentStatus.paid: 'paid',
  PaymentStatus.failed: 'failed',
  PaymentStatus.refunded: 'refunded',
};

_$OrderItemImpl _$$OrderItemImplFromJson(Map<String, dynamic> json) =>
    _$OrderItemImpl(
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      variantName: json['variantName'] as String?,
      quantity: (json['quantity'] as num).toInt(),
      unitPrice: (json['unitPrice'] as num).toDouble(),
      totalPrice: (json['totalPrice'] as num).toDouble(),
    );

Map<String, dynamic> _$$OrderItemImplToJson(_$OrderItemImpl instance) =>
    <String, dynamic>{
      'productId': instance.productId,
      'productName': instance.productName,
      'variantName': instance.variantName,
      'quantity': instance.quantity,
      'unitPrice': instance.unitPrice,
      'totalPrice': instance.totalPrice,
    };
