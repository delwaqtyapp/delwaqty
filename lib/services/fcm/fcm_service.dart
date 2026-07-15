import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/logger/app_logger.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Future<void>.delayed(Duration.zero);
}

final fcmServiceProvider = Provider<FCMService>((ref) {
  final logger = ref.watch(loggerProvider);
  return FCMService(logger);
});

class FCMService {
  FCMService(this._logger);

  final AppLogger _logger;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  StreamSubscription<RemoteMessage>? _foregroundSubscription;

  Future<void> initialize() async {
    try {
      final settings = await _messaging.requestPermission();

      _logger.i('FCM Authorization status: ${settings.authorizationStatus}');

      await _messaging.getToken();
      _logger.i('FCM token obtained');

      _messaging.onTokenRefresh.listen((newToken) {
        _logger.i('FCM token refreshed');
      });

      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      _foregroundSubscription?.cancel();
      _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
        _logger.i('FCM foreground message: ${message.notification?.title}');
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _logger.i(
          'FCM message opened app: ${message.notification?.title}',
        );
      });
    } catch (e, stack) {
      _logger.e('FCM initialization failed', e, stack);
    }
  }

  Future<String?> getToken() async {
    try {
      return _messaging.getToken();
    } catch (e, stack) {
      _logger.e('Failed to get FCM token', e, stack);
      return null;
    }
  }

  void dispose() {
    _foregroundSubscription?.cancel();
  }
}
