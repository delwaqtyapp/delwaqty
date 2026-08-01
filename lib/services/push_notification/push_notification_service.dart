import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/logger/app_logger.dart';

final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  return PushNotificationService(ref.watch(loggerProvider));
});

const _notificationChannelId = 'delwaqty_notifications';
const _notificationChannelName = 'Delwaqty Notifications';
const _notificationChannelDescription =
    'Order updates, delivery tracking and service alerts';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message: ${message.notification?.title}');
  await _initLocalNotifications();
  await _showNotification(message);
}

Future<void> _initLocalNotifications() async {
  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );
  await _localNotifications.initialize(settings: initSettings);
  await _localNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          _notificationChannelId,
          _notificationChannelName,
          description: _notificationChannelDescription,
          importance: Importance.high,
        ),
      );
}

Future<void> _showNotification(RemoteMessage message) async {
  final notification = message.notification;
  if (notification == null) return;
  await _localNotifications.show(
    id: notification.hashCode,
    title: notification.title,
    body: notification.body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        _notificationChannelId,
        _notificationChannelName,
        channelDescription: _notificationChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    payload: jsonEncode(message.data),
  );
}

class PushNotificationService {
  PushNotificationService(this._logger);

  final AppLogger _logger;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    try {
      await _initLocalNotifications();

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        _logger.i('Push notification permission denied');
        return;
      }

      final token = await _messaging.getToken();
      if (token != null) {
        await _saveToken(token);
      }

      _messaging.onTokenRefresh.listen(_saveToken);

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleBackgroundMessage(initialMessage);
      }

      _logger.i('Push notifications initialized');
    } catch (e) {
      _logger.e('Failed to initialize push notifications', e);
    }
  }

  Future<void> _saveToken(String token) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      await client.from('notification_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': defaultTargetPlatform.name,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'token');

      _logger.i('Push notification token saved');
    } catch (e) {
      _logger.e('Failed to save push token', e);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    _logger.i('Foreground message: ${message.notification?.title}');
    _showNotification(message);
  }

  void _handleBackgroundMessage(RemoteMessage message) {
    _logger.i('Opened message: ${message.notification?.title}');
    _navigateFromPayload(message.data);
  }

  void _navigateFromPayload(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final id = data['id'] as String?;
    debugPrint('Navigate from payload: type=$type, id=$id');
  }

  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
    } catch (e) {
      _logger.e('Failed to subscribe to topic: $topic', e);
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
    } catch (e) {
      _logger.e('Failed to unsubscribe from topic: $topic', e);
    }
  }
}
