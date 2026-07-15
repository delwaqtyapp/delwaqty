import 'dart:async';
import 'package:delwaqty/services/notification/notification_service.dart';

/// Mock implementation of [NotificationService] for development.
///
/// Stores subscription topics in memory and provides empty streams for
/// notification events.
class NotificationServiceImpl implements NotificationService {
  final _messageController = StreamController<NotificationMessage>.broadcast();
  final _tapController = StreamController<NotificationMessage>.broadcast();
  final _subscribedTopics = <String>{};

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> getToken() async {
    return 'mock-fcm-token-abc123';
  }

  @override
  Future<void> subscribe(String topic) async {
    _subscribedTopics.add(topic);
  }

  @override
  Future<void> unsubscribe(String topic) async {
    _subscribedTopics.remove(topic);
  }

  @override
  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {}

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    return NotificationPermissionStatus.granted;
  }

  @override
  Stream<NotificationMessage> onMessageReceived() {
    return _messageController.stream;
  }

  @override
  Stream<NotificationMessage> onNotificationTapped() {
    return _tapController.stream;
  }

  /// Simulates receiving a notification message in the foreground.
  void simulateMessage(NotificationMessage message) {
    _messageController.add(message);
  }

  /// Simulates the user tapping on a notification.
  void simulateTap(NotificationMessage message) {
    _tapController.add(message);
  }

  /// Returns the set of currently subscribed topics.
  Set<String> get subscribedTopics => Set.unmodifiable(_subscribedTopics);

  /// Releases resources held by this service.
  void dispose() {
    _messageController.close();
    _tapController.close();
  }
}
