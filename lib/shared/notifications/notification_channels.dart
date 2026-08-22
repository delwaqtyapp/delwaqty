/// App contexts used to scope notification deep-link routing.
///
/// A notification deep link must only resolve inside the app that actually
/// owns the target route. Without this, a provider/owner deep link could be
/// pushed in the Customer app (where the route does not exist) or vice-versa.
enum AppContext { customer, admin, driver, provider }

class NotificationChannel {
  const NotificationChannel(
    this.pattern, {
    this.adminOnly = false,
    this.contexts,
  });

  final String pattern;
  final bool adminOnly;

  /// Null means the route is valid in every app context.
  final Set<AppContext>? contexts;

  bool matches(String route) {
    final routeSegments = route.split('/');
    final patternSegments = pattern.split('/');
    if (routeSegments.length != patternSegments.length) return false;
    for (var i = 0; i < patternSegments.length; i++) {
      final segment = patternSegments[i];
      if (segment.startsWith(':')) continue;
      if (segment != routeSegments[i]) return false;
    }
    return true;
  }

  bool allowedIn(AppContext ctx) => contexts == null || contexts!.contains(ctx);
}

class NotificationChannels {
  static const List<NotificationChannel> channels = [
    // ── Cross-app support ────────────────────────────────────────────────
    NotificationChannel('/notifications'),
    NotificationChannel(
      '/support/room/:roomId',
      contexts: {
        AppContext.customer,
        AppContext.provider,
        AppContext.driver,
        AppContext.admin,
      },
    ),

    // ── Customer ─────────────────────────────────────────────────────────
    NotificationChannel('/campaign/:id'),
    NotificationChannel('/my-complaints',
        contexts: {AppContext.customer, AppContext.provider, AppContext.driver}),
    NotificationChannel(
      '/orders',
      contexts: {AppContext.customer, AppContext.provider, AppContext.driver},
    ),
    NotificationChannel('/profile'),
    NotificationChannel('/rewards'),
    NotificationChannel('/safety'),
    NotificationChannel(
      '/wallet',
      contexts: {AppContext.customer, AppContext.provider, AppContext.driver},
    ),

    // ── Provider ─────────────────────────────────────────────────────────
    NotificationChannel('/provider-availability',
        contexts: {AppContext.provider}),
    NotificationChannel('/provider-verification',
        contexts: {AppContext.provider}),
    NotificationChannel('/provider-documents',
        contexts: {AppContext.provider}),
    NotificationChannel(
      '/pending-verification',
      contexts: {AppContext.provider, AppContext.driver},
    ),

    // ── Driver ───────────────────────────────────────────────────────────
    NotificationChannel('/earnings', contexts: {AppContext.driver}),
    NotificationChannel('/deliveries', contexts: {AppContext.driver}),

    // ── Admin / Owner ────────────────────────────────────────────────────
    NotificationChannel('/admin/complaints', adminOnly: true),
    NotificationChannel('/admin/live-tracking', adminOnly: true),
    NotificationChannel('/admin/support-chat/room/:roomId', adminOnly: true),
    NotificationChannel('/admin/financial', adminOnly: true),
    NotificationChannel('/financial', contexts: {AppContext.admin}),
    NotificationChannel('/owner-financial', contexts: {AppContext.admin}),
  ];

  static bool isAllowed(String route, {required AppContext context}) {
    final normalized = route.trim();
    if (normalized.isEmpty || !normalized.startsWith('/')) return false;
    final scheme = RegExp(
      r'^/(javascript|http|https|data|vbscript|file):',
      caseSensitive: false,
    );
    if (scheme.hasMatch(normalized)) return false;
    final traversal = RegExp(r'(^|/)\.\.?(/|$)');
    if (traversal.hasMatch(normalized)) return false;
    for (final channel in channels) {
      if (channel.matches(normalized) && channel.allowedIn(context)) {
        return channel.adminOnly ? context == AppContext.admin : true;
      }
    }
    return false;
  }
}
