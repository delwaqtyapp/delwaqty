import 'dart:async';

/// Permission status for push notification access.
enum NotificationPermissionStatus {
  /// Permission granted for all notification types.
  granted,

  /// Permission denied by the user.
  denied,

  /// Permission denied permanently; cannot request again.
  deniedForever,

  /// Permission status is unknown.
  unknown,
}

/// Represents a received or tapped notification message.
class NotificationMessage {
  /// Creates a [NotificationMessage].
  const NotificationMessage({
    required this.title,
    required this.body,
    this.data = const <String, dynamic>{},
    this.imageUrl,
    this.timestamp,
  });

  /// Notification title text.
  final String title;

  /// Notification body text.
  final String body;

  /// Arbitrary data payload attached to the notification.
  final Map<String, dynamic> data;

  /// Optional URL of an image to display in the notification.
  final String? imageUrl;

  /// Timestamp when the notification was received.
  final DateTime? timestamp;
}

/// Abstract interface for push and local notification services.
///
/// Handles device token management, topic subscriptions, local notification
/// display, and incoming notification event streams.
abstract interface class NotificationService {
  /// Initialises the notification service (FCM, channels, permissions).
  Future<void> initialize();

  /// Returns the current device push notification token, or null if unavailable.
  Future<String?> getToken();

  /// Subscribes the device to the given [topic] for push notifications.
  Future<void> subscribe(String topic);

  /// Unsubscribes the device from the given [topic].
  Future<void> unsubscribe(String topic);

  /// Displays a local notification with the given [title], [body], and
  /// optional [data] payload.
  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  });

  /// Requests notification permission from the user and returns the result.
  Future<NotificationPermissionStatus> requestPermission();

  /// Stream that emits when a notification is received while the app is in
  /// the foreground.
  Stream<NotificationMessage> onMessageReceived();

  /// Stream that emits when the user taps on a notification.
  Stream<NotificationMessage> onNotificationTapped();
}
