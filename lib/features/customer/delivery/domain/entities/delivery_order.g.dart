// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delivery_order.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DeliveryOrder _$DeliveryOrderFromJson(Map<String, dynamic> json) =>
    _DeliveryOrder(
      id: json['id'] as String,
      serviceType: json['serviceType'] as String,
      merchantId: json['merchantId'] as String?,
      merchantName: json['merchantName'] as String?,
      merchantAddress: json['merchantAddress'] as String?,
      riderId: json['riderId'] as String?,
      driverId: json['driverId'] as String?,
      driverName: json['driverName'] as String?,
      driverPhone: json['driverPhone'] as String?,
      pickupLatitude: (json['pickupLatitude'] as num).toDouble(),
      pickupLongitude: (json['pickupLongitude'] as num).toDouble(),
      pickupAddress: json['pickupAddress'] as String? ?? '',
      pickupNotes: json['pickupNotes'] as String?,
      dropoffLatitude: (json['dropoffLatitude'] as num).toDouble(),
      dropoffLongitude: (json['dropoffLongitude'] as num).toDouble(),
      dropoffAddress: json['dropoffAddress'] as String? ?? '',
      dropoffNotes: json['dropoffNotes'] as String?,
      priority: json['priority'] as String? ?? 'standard',
      status: json['status'] as String? ?? 'searching',
      fare: (json['fare'] as num?)?.toDouble(),
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'EGP',
      distance: (json['distance'] as num?)?.toDouble(),
      estimatedMinutes: (json['estimatedMinutes'] as num?)?.toInt(),
      itemsSummary: json['itemsSummary'] as String?,
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      signatureRequired: json['signatureRequired'] as bool? ?? false,
      otpRequired: json['otpRequired'] as bool? ?? true,
      deliveryProofUrl: json['deliveryProofUrl'] as String?,
      scheduledAt: json['scheduledAt'] == null
          ? null
          : DateTime.parse(json['scheduledAt'] as String),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      matchedAt: json['matchedAt'] == null
          ? null
          : DateTime.parse(json['matchedAt'] as String),
      arrivedAt: json['arrivedAt'] == null
          ? null
          : DateTime.parse(json['arrivedAt'] as String),
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.parse(json['startedAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      cancelledAt: json['cancelledAt'] == null
          ? null
          : DateTime.parse(json['cancelledAt'] as String),
      cancellationReason: json['cancellationReason'] as String?,
      recipientName: json['recipientName'] as String?,
      recipientPhone: json['recipientPhone'] as String?,
      pickupOtp: json['pickupOtp'] as String?,
    );

Map<String, dynamic> _$DeliveryOrderToJson(_DeliveryOrder instance) =>
    <String, dynamic>{
      'id': instance.id,
      'serviceType': instance.serviceType,
      'merchantId': instance.merchantId,
      'merchantName': instance.merchantName,
      'merchantAddress': instance.merchantAddress,
      'riderId': instance.riderId,
      'driverId': instance.driverId,
      'driverName': instance.driverName,
      'driverPhone': instance.driverPhone,
      'pickupLatitude': instance.pickupLatitude,
      'pickupLongitude': instance.pickupLongitude,
      'pickupAddress': instance.pickupAddress,
      'pickupNotes': instance.pickupNotes,
      'dropoffLatitude': instance.dropoffLatitude,
      'dropoffLongitude': instance.dropoffLongitude,
      'dropoffAddress': instance.dropoffAddress,
      'dropoffNotes': instance.dropoffNotes,
      'priority': instance.priority,
      'status': instance.status,
      'fare': instance.fare,
      'deliveryFee': instance.deliveryFee,
      'currency': instance.currency,
      'distance': instance.distance,
      'estimatedMinutes': instance.estimatedMinutes,
      'itemsSummary': instance.itemsSummary,
      'weightKg': instance.weightKg,
      'signatureRequired': instance.signatureRequired,
      'otpRequired': instance.otpRequired,
      'deliveryProofUrl': instance.deliveryProofUrl,
      'scheduledAt': instance.scheduledAt?.toIso8601String(),
      'createdAt': instance.createdAt?.toIso8601String(),
      'matchedAt': instance.matchedAt?.toIso8601String(),
      'arrivedAt': instance.arrivedAt?.toIso8601String(),
      'startedAt': instance.startedAt?.toIso8601String(),
      'completedAt': instance.completedAt?.toIso8601String(),
      'cancelledAt': instance.cancelledAt?.toIso8601String(),
      'cancellationReason': instance.cancellationReason,
      'recipientName': instance.recipientName,
      'recipientPhone': instance.recipientPhone,
      'pickupOtp': instance.pickupOtp,
    };
