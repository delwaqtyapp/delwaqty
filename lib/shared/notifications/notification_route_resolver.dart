import 'package:delwaqty/domain/entities/app_notification.dart';
import 'package:delwaqty/shared/notifications/notification_channels.dart';

export 'package:delwaqty/shared/notifications/notification_channels.dart';

class NotificationRouteResolver {
  static const String fallbackRoute = '/notifications';

  /// Current app context. Each app sets this once at startup (see main.dart).
  /// Defaults to customer so an unset context is the least privileged.
  static AppContext appContext = AppContext.customer;

  static String normalize(String route, {required AppContext context}) {
    var normalized = route.trim();
    if (normalized.isEmpty) return '';
    while (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    final segments = normalized.split('/').where((e) => e.isNotEmpty).toList();
    if (segments.isEmpty) return normalized;

    final first = segments[0];
    if (segments.length == 2) {
      final second = segments[1];
      if (second.isEmpty || second == '.' || second == '..') {
        return normalized;
      }
      if (first == 'orders' &&
          (context == AppContext.customer || context == AppContext.provider)) {
        return '/market/orders/$second';
      }
      if (first == 'merchant' &&
          (context == AppContext.customer || context == AppContext.provider)) {
        return '/market/merchant/$second';
      }
      if (first == 'campaigns') {
        return '/campaign/$second';
      }
      if (first == 'complaints' && context != AppContext.admin) {
        return '/my-complaints';
      }
      if (first == 'delivery') {
        if (context == AppContext.customer) {
          return '/delivery/tracking/$second';
        }
        if (context == AppContext.driver) {
          return '/driver/delivery/$second';
        }
      }
      if (first == 'support' &&
          second != 'room' &&
          second != 'chat-permissions') {
        return '/support/room/$second';
      }
    } else if (segments.length == 1 &&
        first == 'complaints' &&
        context != AppContext.admin) {
      return '/my-complaints';
    }

    return normalized;
  }

  static String? resolve({String? deepLink, AppContext? context}) {
    final ctx = context ?? appContext;
    if (deepLink == null || deepLink.trim().isEmpty) return null;
    final normalized = normalize(deepLink, context: ctx);
    if (normalized.isEmpty) return null;
    if (!NotificationChannels.isAllowed(normalized, context: ctx)) return null;
    return normalized;
  }

  static String safe({String? deepLink, AppContext? context}) =>
      resolve(deepLink: deepLink, context: context) ?? fallbackRoute;

  static String safeNotification(
    AppNotification notification, {
    AppContext? context,
  }) {
    final deepLink = notification.deepLink;
    if (deepLink != null && deepLink.trim().isNotEmpty) {
      return safe(deepLink: deepLink, context: context);
    }
    return fallbackRoute;
  }

  static String? resolvePayload(
    NotificationPayload payload, {
    AppContext? context,
  }) {
    return resolve(deepLink: payload.resolveDeepLink(), context: context);
  }

  static String safePayload(
    NotificationPayload payload, {
    AppContext? context,
  }) {
    final resolved = resolvePayload(payload, context: context);
    return resolved ?? fallbackRoute;
  }
}
