import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_notification.freezed.dart';
part 'app_notification.g.dart';

@freezed
class AppNotification with _$AppNotification {
  const factory AppNotification({
    required String id,
    required String title,
    required String body,
    required NotificationType type,
    @Default(false) bool isRead,
    String? deepLink,
    String? idempotencyKey,
    DateTime? readAt,
    required DateTime createdAt,
    @Default(NotificationPriority.normal) NotificationPriority priority,
    String? senderId,
    @Default(NotificationPushStatus.pending)
    NotificationPushStatus pushStatus,
  }) = _AppNotification;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);
}

enum NotificationPriority {
  @JsonValue('low')
  low,
  @JsonValue('normal')
  normal,
  @JsonValue('high')
  high,
}

enum NotificationPushStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('sent')
  sent,
  @JsonValue('failed')
  failed,
  @JsonValue('unconfigured')
  unconfigured,
}

enum NotificationType {
  @JsonValue('system')
  system,
  @JsonValue('order')
  order,
  @JsonValue('payment')
  payment,
  @JsonValue('promotion')
  promotion,
  @JsonValue('service')
  service,
  @JsonValue('account')
  account,
  @JsonValue('security')
  security,
  @JsonValue('message')
  message,
  @JsonValue('info')
  info,
  @JsonValue('warning')
  warning,
  @JsonValue('success')
  success,
  @JsonValue('reminder')
  reminder,
  @JsonValue('reward')
  reward,
  @JsonValue('chat_reply')
  chatReply,
  @JsonValue('chat_assigned')
  chatAssigned,
  @JsonValue('chat_escalated')
  chatEscalated,
  @JsonValue('chat_closed')
  chatClosed,
  @JsonValue('complaint')
  complaint,
  @JsonValue('complaint_note')
  complaintNote,
  @JsonValue('emergency')
  emergency,
  @JsonValue('emergency_alert')
  emergencyAlert,
  @JsonValue('emergency_resolved')
  emergencyResolved,
  @JsonValue('admin_management')
  adminManagement,
  @JsonValue('moderation')
  moderation,
}

class NotificationPayload {
  const NotificationPayload({
    this.notificationId,
    this.type,
    this.deepLink,
    this.entityId,
    this.entityType,
    this.action,
  });

  factory NotificationPayload.fromMap(Map<String, dynamic> data) {
    return NotificationPayload(
      notificationId: data['notification_id'] as String?,
      type: data['type'] as String?,
      deepLink: data['deep_link'] as String?,
      entityId: data['entity_id'] as String?,
      entityType: data['entity_type'] as String?,
      action: data['action'] as String?,
    );
  }

  final String? notificationId;
  final String? type;
  final String? deepLink;
  final String? entityId;
  final String? entityType;
  final String? action;

  Map<String, dynamic> toMap() => {
        if (notificationId != null) 'notification_id': notificationId,
        if (type != null) 'type': type,
        if (deepLink != null) 'deep_link': deepLink,
        if (entityId != null) 'entity_id': entityId,
        if (entityType != null) 'entity_type': entityType,
        if (action != null) 'action': action,
      };

  String? resolveDeepLink() {
    if (deepLink != null && deepLink!.isNotEmpty) return deepLink;
    if (entityType == null || entityId == null) return null;
    return _defaultDeepLink(entityType!, entityId!);
  }

  String _defaultDeepLink(String entityType, String entityId) {
    switch (entityType) {
      case 'order':
        return '/market/orders/$entityId';
      case 'merchant':
        return '/market/merchant/$entityId';
      case 'service':
        return '/service-booking/$entityId';
      case 'ride':
        return '/ride/$entityId';
      case 'delivery':
        return '/ride/$entityId';
      default:
        return '/notifications';
    }
  }
}
