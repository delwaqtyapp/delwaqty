// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_notification.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AppNotificationImpl _$$AppNotificationImplFromJson(
  Map<String, dynamic> json,
) => _$AppNotificationImpl(
  id: json['id'] as String,
  title: json['title'] as String,
  body: json['body'] as String,
  type: $enumDecode(_$NotificationTypeEnumMap, json['type']),
  isRead: json['isRead'] as bool? ?? false,
  deepLink: json['deepLink'] as String?,
  idempotencyKey: json['idempotencyKey'] as String?,
  readAt: json['readAt'] == null
      ? null
      : DateTime.parse(json['readAt'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$$AppNotificationImplToJson(
  _$AppNotificationImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'body': instance.body,
  'type': _$NotificationTypeEnumMap[instance.type]!,
  'isRead': instance.isRead,
  'deepLink': instance.deepLink,
  'idempotencyKey': instance.idempotencyKey,
  'readAt': instance.readAt?.toIso8601String(),
  'createdAt': instance.createdAt.toIso8601String(),
};

const _$NotificationTypeEnumMap = {
  NotificationType.system: 'system',
  NotificationType.order: 'order',
  NotificationType.payment: 'payment',
  NotificationType.promotion: 'promotion',
  NotificationType.service: 'service',
  NotificationType.account: 'account',
  NotificationType.security: 'security',
  NotificationType.message: 'message',
  NotificationType.info: 'info',
  NotificationType.warning: 'warning',
  NotificationType.success: 'success',
  NotificationType.reminder: 'reminder',
};
