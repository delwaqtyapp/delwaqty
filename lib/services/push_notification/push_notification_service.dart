import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/core/router/app_router.dart';
import 'package:delwaqty/domain/entities/app_notification.dart';
import 'package:delwaqty/features/notifications/notifications_module.dart';
import 'package:delwaqty/services/logger/app_logger.dart';
import 'package:delwaqty/services/push_notification/device_identity.dart';
import 'package:delwaqty/shared/notifications/notification_route_resolver.dart';

final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  final service = PushNotificationService(ref.watch(loggerProvider));
  service.onRealtimeNotification = (_) {
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadCountProvider);
    ref.invalidate(unreadCountStreamProvider);
  };
  return service;
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
  await _localNotifications.initialize(
    settings: initSettings,
    onDidReceiveNotificationResponse: (details) {
      if (details.payload == null) return;
      try {
        final data = jsonDecode(details.payload!) as Map<String, dynamic>;
        _handleNotificationTap(data);
      } catch (_) {}
    },
  );
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
  await _showLocalNotification(
    title: notification.title,
    body: notification.body,
    payload: jsonEncode(message.data),
  );
}

Future<void> _showLocalNotification({
  String? title,
  String? body,
  String? payload,
}) async {
  if (title == null && body == null) return;
  await _localNotifications.show(
    id: (title ?? body).hashCode,
    title: title,
    body: body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        _notificationChannelId,
        _notificationChannelName,
        channelDescription: _notificationChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    payload: payload,
  );
}

void _handleNotificationTap(Map<String, dynamic> data) {
  final payload = NotificationPayload.fromMap(data);
  final deepLink = NotificationRouteResolver.safePayload(payload);
  if (rootNavigatorKey.currentContext == null) return;

  final context = rootNavigatorKey.currentContext!;
  final router = GoRouter.of(context);
  router.push(deepLink);

  if (payload.notificationId != null) {
    _markNotificationRead(payload.notificationId!);
  }
}

Future<void> _markNotificationRead(String notificationId) async {
  try {
    final client = Supabase.instance.client;
    await client.from('notifications').update({
      'is_read': true,
      'read_at': DateTime.now().toIso8601String(),
    }).eq('id', notificationId);
  } catch (e) {
    debugPrint('Failed to mark notification read: $e');
  }
}

class PushNotificationService {
  PushNotificationService(this._logger);

  final AppLogger _logger;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  String? _lastToken;
  String? _deviceId;
  Timer? _heartbeat;
  RealtimeChannel? _realtimeChannel;
  bool _initialized = false;

  void Function(Map<String, dynamic> record)? onRealtimeNotification;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await _initLocalNotifications();
      _setupRealtimeNotifications();

      _deviceId = await DeviceIdentity.getOrCreate();

      final settings = await _messaging.requestPermission();

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        _logger.i('Push notification permission denied');
        return;
      }

      final token = await _messaging.getToken();
      if (token != null) {
        _lastToken = token;
        await _saveToken(token);
      }

      _messaging.onTokenRefresh.listen((token) {
        _lastToken = token;
        _saveToken(token);
      });

      _startHeartbeat();

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleBackgroundMessage(initialMessage);
      }

      _initialized = true;
      _logger.i('Push notifications initialized');
    } catch (e) {
      _initialized = false;
      _logger.e('Failed to initialize push notifications', e);
    }
  }

  void _setupRealtimeNotifications() {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      _realtimeChannel?.unsubscribe();
      _realtimeChannel = client
          .channel('in-app-notifications')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            callback: (payload) {
              final record = payload.newRecord;
              final title = record['title'] as String?;
              final body = record['body'] as String?;
              if (title == null && body == null) return;

              final recordUserId = record['user_id'] as String?;
              final isOwn = recordUserId == userId;
              if (!isOwn) return;

              _logger.i('Realtime notification: $title');
              _showLocalNotification(title: title, body: body);
              onRealtimeNotification?.call(record);
            },
          )
          .subscribe();
    } catch (e) {
      _logger.e('Failed to setup realtime notifications', e);
    }
  }

  Future<void> _saveToken(String token) async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) return;
      final deviceId = _deviceId ?? await DeviceIdentity.getOrCreate();
      _deviceId = deviceId;

      await client.rpc('register_device_token', params: {
        'p_token': token,
        'p_platform': _platformName(),
        'p_device_id': deviceId,
      });

      _logger.i('Push notification token saved');
    } catch (e) {
      _logger.e('Failed to save push token', e);
    }
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(minutes: 5), (_) async {
      final token = _lastToken;
      if (token == null) return;
      try {
        final client = Supabase.instance.client;
        final deviceId = _deviceId ?? await DeviceIdentity.getOrCreate();
        _deviceId = deviceId;
        await client.rpc('refresh_token_heartbeat', params: {
          'p_token': token,
          'p_device_id': deviceId,
        });
      } catch (e) {
        _logger.e('Failed to refresh push heartbeat', e);
      }
    });
  }

  String _platformName() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'android';
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    _logger.i('Foreground message: ${message.notification?.title}');
    _showNotification(message);
  }

  void _handleBackgroundMessage(RemoteMessage message) {
    _logger.i('Opened message: ${message.notification?.title}');
    final payload = NotificationPayload.fromMap(message.data);
    final deepLink = NotificationRouteResolver.safePayload(payload);

    if (rootNavigatorKey.currentContext != null) {
      final context = rootNavigatorKey.currentContext!;
      GoRouter.of(context).push(deepLink);
    }

    if (payload.notificationId != null) {
      _markNotificationRead(payload.notificationId!);
    }
  }

  Future<void> deactivateTokensOnLogout() async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) return;

      final deviceId = _deviceId ?? await DeviceIdentity.getOrCreate();
      _deviceId = deviceId;
      await client.rpc('deactivate_device_tokens', params: {
        'p_device_id': deviceId,
      });

      _heartbeat?.cancel();
      _heartbeat = null;
      await _realtimeChannel?.unsubscribe();
      _realtimeChannel = null;
      _lastToken = null;
      _initialized = false;

      _logger.i('Tokens deactivated on logout');
    } catch (e) {
      _logger.e('Failed to deactivate tokens on logout', e);
    }
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

  void dispose() {
    _heartbeat?.cancel();
  }
}
