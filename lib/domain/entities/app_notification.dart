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
    required DateTime createdAt,
  }) = _AppNotification;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);
}

enum NotificationType {
  @JsonValue('info')
  info,
  @JsonValue('warning')
  warning,
  @JsonValue('success')
  success,
  @JsonValue('reminder')
  reminder,
}
