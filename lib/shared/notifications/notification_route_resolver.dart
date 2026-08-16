import 'package:delwaqty/domain/entities/app_notification.dart';
import 'package:delwaqty/shared/notifications/notification_channels.dart';

class NotificationRouteResolver {
  static const String fallbackRoute = '/notifications';

  static String? resolve({String? deepLink, bool isAdmin = false}) {
    if (deepLink == null || deepLink.isEmpty) return null;
    if (!NotificationChannels.isAllowed(deepLink, isAdmin: isAdmin)) return null;
    return deepLink;
  }

  static String safe({String? deepLink, bool isAdmin = false}) =>
      resolve(deepLink: deepLink, isAdmin: isAdmin) ?? fallbackRoute;

  static String? resolvePayload(
    NotificationPayload payload, {
    bool isAdmin = false,
  }) {
    return resolve(deepLink: payload.resolveDeepLink(), isAdmin: isAdmin);
  }

  static String safePayload(NotificationPayload payload, {bool isAdmin = false}) {
    final resolved = resolvePayload(payload, isAdmin: isAdmin);
    return resolved ?? fallbackRoute;
  }
}
