import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/notification/notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationServiceImpl(
    FirebaseMessaging.instance,
    FlutterLocalNotificationsPlugin(),
  );
});

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {}

class NotificationServiceImpl implements NotificationService {
  NotificationServiceImpl(this._messaging, this._localNotifications);

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  final _messageController = StreamController<NotificationMessage>.broadcast();
  final _tapController = StreamController<NotificationMessage>.broadcast();

  static const _channel = AndroidNotificationChannel(
    'delwaqty_default',
    'Default Notifications',
    description: 'General app notifications',
    importance: Importance.high,
  );

  @override
  Future<void> initialize() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        final payload = details.payload;
        if (payload != null) {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          _tapController.add(
            NotificationMessage(
              title: data['title'] as String? ?? '',
              body: data['body'] as String? ?? '',
              data: data,
            ),
          );
        }
      },
    );

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification != null) {
        _messageController.add(
          NotificationMessage(
            title: notification.title ?? '',
            body: notification.body ?? '',
            data: message.data,
          ),
        );
        _showLocalNotification(message);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _tapController.add(
        NotificationMessage(
          title: message.notification?.title ?? '',
          body: message.notification?.body ?? '',
          data: message.data,
        ),
      );
    });

    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
  }

  @override
  Future<String?> getToken() async {
    return _messaging.getToken();
  }

  @override
  Future<void> subscribe(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  @override
  Future<void> unsubscribe(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }

  @override
  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: data != null ? jsonEncode(data) : null,
    );
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized => NotificationPermissionStatus.granted,
      AuthorizationStatus.provisional => NotificationPermissionStatus.granted,
      AuthorizationStatus.denied => NotificationPermissionStatus.denied,
      AuthorizationStatus.notDetermined => NotificationPermissionStatus.unknown,
    };
  }

  @override
  Stream<NotificationMessage> onMessageReceived() => _messageController.stream;

  @override
  Stream<NotificationMessage> onNotificationTapped() => _tapController.stream;

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      notification.title,
      notification.body,
      details,
      payload: jsonEncode(message.data),
    );
  }

  void dispose() {
    _messageController.close();
    _tapController.close();
  }
}
