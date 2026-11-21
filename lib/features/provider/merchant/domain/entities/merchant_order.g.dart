// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'merchant_order.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MerchantOrder _$MerchantOrderFromJson(Map<String, dynamic> json) =>
    _MerchantOrder(
      id: json['id'] as String,
      customerId: json['customerId'] as String,
      customerName: json['customerName'] as String?,
      customerPhone: json['customerPhone'] as String?,
      driverId: json['driverId'] as String?,
      items:
          (json['items'] as List<dynamic>?)
              ?.map(
                (e) => MerchantOrderItem.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      totalAmount: (json['totalAmount'] as num).toDouble(),
      status: json['status'] as String,
      dispatchStatus: json['dispatchStatus'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      deliveryAddress: json['deliveryAddress'] as String?,
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$MerchantOrderToJson(_MerchantOrder instance) =>
    <String, dynamic>{
      'id': instance.id,
      'customerId': instance.customerId,
      'customerName': instance.customerName,
      'customerPhone': instance.customerPhone,
      'driverId': instance.driverId,
      'items': instance.items.map((e) => e.toJson()).toList(),
      'totalAmount': instance.totalAmount,
      'status': instance.status,
      'dispatchStatus': instance.dispatchStatus,
      'createdAt': instance.createdAt.toIso8601String(),
      'deliveryAddress': instance.deliveryAddress,
      'notes': instance.notes,
    };

_MerchantOrderItem _$MerchantOrderItemFromJson(Map<String, dynamic> json) =>
    _MerchantOrderItem(
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      quantity: (json['quantity'] as num).toInt(),
      unitPrice: (json['unitPrice'] as num).toDouble(),
      modifiers:
          (json['modifiers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$MerchantOrderItemToJson(_MerchantOrderItem instance) =>
    <String, dynamic>{
      'productId': instance.productId,
      'productName': instance.productName,
      'quantity': instance.quantity,
      'unitPrice': instance.unitPrice,
      'modifiers': instance.modifiers,
    };
