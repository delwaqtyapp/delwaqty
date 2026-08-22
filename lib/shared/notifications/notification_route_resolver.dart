import 'package:delwaqty/domain/entities/app_notification.dart';
import 'package:delwaqty/shared/notifications/notification_channels.dart';

export 'package:delwaqty/shared/notifications/notification_channels.dart';

class NotificationRouteResolver {
  static const String fallbackRoute = '/notifications';

  /// Current app context. Each app sets this once at startup (see main.dart).
  /// Defaults to customer so an unset context is the least privileged.
  static AppContext appContext = AppContext.customer;

  static String? resolve({String? deepLink, AppContext? context}) {
    final ctx = context ?? appContext;
    if (deepLink == null || deepLink.isEmpty) return null;
    if (!NotificationChannels.isAllowed(deepLink, context: ctx)) return null;
    return deepLink;
  }

  static String safe({String? deepLink, AppContext? context}) =>
      resolve(deepLink: deepLink, context: context) ?? fallbackRoute;

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
