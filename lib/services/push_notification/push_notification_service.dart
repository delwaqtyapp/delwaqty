import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/logger/app_logger.dart';

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(
    ref.watch(loggerProvider),
  );
});

class PushNotificationService {
  PushNotificationService(this._logger);

  final AppLogger _logger;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    try {
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
    _showInAppNotification(message);
  }

  void _handleBackgroundMessage(RemoteMessage message) {
    _logger.i('Background message: ${message.notification?.title}');
    _navigateFromPayload(message.data);
  }

  void _showInAppNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    debugPrint('In-app notification: ${notification.title} - ${notification.body}');
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
