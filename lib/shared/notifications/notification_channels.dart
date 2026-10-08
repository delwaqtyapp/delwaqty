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

  /// Matches the exact path OR any deeper path beneath it.
  ///
  /// The previous implementation required an EXACT segment count, so
  /// `/orders/123`, `/wallet/topup`, `/admin/members/42` and
  /// '/region-selection' never matched any channel and every such
  /// notification silently fell back to '/notifications'.
  bool matches(String route) {
    final patternSegments = pattern.split('/').where((e) => e.isNotEmpty).toList();
    final routeSegments = route.split('/').where((e) => e.isNotEmpty).toList();
    if (routeSegments.length < patternSegments.length) return false;
    for (var i = 0; i < patternSegments.length; i++) {
      final segment = patternSegments[i];
      if (segment == '*') continue;
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
      contexts: {AppContext.admin, AppContext.customer},
    ),

    // ── Customer ─────────────────────────────────────────────────────────
    NotificationChannel('/campaign/:id',
        contexts: {
          AppContext.customer,
          AppContext.admin,
          AppContext.provider,
        }),
    NotificationChannel('/my-complaints',
        contexts: {
          AppContext.customer,
          AppContext.provider,
          AppContext.driver,
        }),
    NotificationChannel(
      '/orders',
      contexts: {AppContext.customer, AppContext.provider},
    ),
    NotificationChannel('/profile',
        contexts: {
          AppContext.customer,
          AppContext.driver,
          AppContext.provider,
        }),
    NotificationChannel('/rewards',
        contexts: {AppContext.customer, AppContext.provider}),
    NotificationChannel(
      '/wallet',
      contexts: {AppContext.customer, AppContext.provider},
    ),
    NotificationChannel('/home-services',
        contexts: {AppContext.customer}),
    NotificationChannel(
      '/market/orders/:orderId',
      contexts: {AppContext.customer, AppContext.provider},
    ),
    NotificationChannel(
      '/market/merchant/:id',
      contexts: {AppContext.customer, AppContext.provider},
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
    // The driver registry has no '/earnings' or '/deliveries' route at all
    // (they are '/driver/earnings' and '/driver/hub'), so those taps used
    // to land in the router's unrecoverable error page.
    NotificationChannel('/driver/earnings', contexts: {AppContext.driver}),
    NotificationChannel('/driver/hub', contexts: {AppContext.driver}),
    NotificationChannel(
      '/driver/delivery/:id',
      contexts: {AppContext.driver},
    ),

    // ── Admin / Owner ────────────────────────────────────────────────────
    NotificationChannel('/admin/complaints', adminOnly: true),
    NotificationChannel('/admin/live-tracking', adminOnly: true),
    NotificationChannel('/admin/support-chat/room/:roomId', adminOnly: true),
    NotificationChannel('/admin/financial-center', adminOnly: true),
    NotificationChannel('/admin/owner-dashboard', contexts: {AppContext.admin}),
    NotificationChannel('/admin/emergency', adminOnly: true),
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
