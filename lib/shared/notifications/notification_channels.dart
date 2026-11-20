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
    final patternSegments = pattern
        .split('/')
        .where((e) => e.isNotEmpty)
        .toList();
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
    NotificationChannel('/safety'),
    NotificationChannel(
      '/support/room/:roomId',
      contexts: {
        AppContext.admin,
        AppContext.customer,
        AppContext.driver,
        AppContext.provider,
      },
    ),
    NotificationChannel(
      '/region-selection',
      contexts: {AppContext.customer, AppContext.driver, AppContext.provider},
    ),

    // ── Customer ─────────────────────────────────────────────────────────
    NotificationChannel(
      '/campaign/:id',
      contexts: {AppContext.customer, AppContext.admin, AppContext.provider},
    ),
    NotificationChannel(
      '/my-complaints',
      contexts: {AppContext.customer, AppContext.provider, AppContext.driver},
    ),
    NotificationChannel(
      '/orders',
      contexts: {AppContext.customer, AppContext.provider},
    ),
    NotificationChannel(
      '/profile',
      contexts: {AppContext.customer, AppContext.driver, AppContext.provider},
    ),
    NotificationChannel(
      '/rewards',
      contexts: {AppContext.customer, AppContext.provider},
    ),
    NotificationChannel(
      '/wallet',
      contexts: {AppContext.customer, AppContext.provider},
    ),
    NotificationChannel('/home-services', contexts: {AppContext.customer}),
    NotificationChannel(
      '/market/orders/:orderId',
      contexts: {AppContext.customer, AppContext.provider},
    ),
    NotificationChannel(
      '/market/merchant/:id',
      contexts: {AppContext.customer, AppContext.provider},
    ),
    NotificationChannel(
      '/delivery/tracking/:rideId',
      contexts: {AppContext.customer},
    ),

    // ── Provider ─────────────────────────────────────────────────────────
    NotificationChannel(
      '/provider-availability',
      contexts: {AppContext.provider},
    ),
    NotificationChannel(
      '/provider-verification',
      contexts: {AppContext.provider},
    ),
    NotificationChannel('/provider-documents', contexts: {AppContext.provider}),
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
    NotificationChannel('/driver/delivery/:id', contexts: {AppContext.driver}),

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

  static const Set<String> _adminOperationalTypes = {
    'admin_management',
    'adminManagement',
    'moderation',
    'approval',
    'admin_topup',
    'adminTopup',
    'emergency_alert',
    'emergencyAlert',
    'complaint_escalated',
    'complaintEscalated',
    'complaint_assigned',
    'complaintAssigned',
    'chat_assigned',
    'chatAssigned',
    'chat_escalated',
    'chatEscalated',
  };

  static const Set<String> _providerOnlyTypes = {
    'provider_profile',
    'providerProfile',
  };

  static const Set<String> _customerOnlyTypes = {'promotion', 'reward'};

  static const Set<String> _userTransactionalTypes = {
    'order',
    'order_update',
    'delivery_update',
    'ride_update',
    'payment',
    'service',
    'topup_approved',
    'topupApproved',
    'complaint',
    'complaint_note',
    'complaintNote',
    'account',
    'security',
    'reminder',
  };

  static bool _matchesAnyChannel(String route) {
    final normalized = route.trim();
    if (normalized.isEmpty || !normalized.startsWith('/')) return false;
    for (final channel in channels) {
      if (channel.matches(normalized)) return true;
    }
    return false;
  }

  /// Determines whether a notification row/entity belongs to the running [context] app.
  ///
  /// Rules:
  /// 1. Explicit broadcast (`target_app == 'all'` or `target_role == 'all'` or `audience == 'all'`):
  ///    Visible in ALL apps (`customer`, `admin`, `driver`, `provider`).
  /// 2. Explicit app target in `data` (`target_app` / `target_role` / `audience`):
  ///    - `'admin'`, `'owner'`, `'super_admin'`, `'operational'` -> ONLY `AppContext.admin`
  ///    - `'customer'` -> ONLY `AppContext.customer`
  ///    - `'driver'`, `'delivery'` -> ONLY `AppContext.driver`
  ///    - `'provider'`, `'merchant'` -> ONLY `AppContext.provider`
  /// 3. Deep-link prefix classification (when not an explicit `'all'` broadcast):
  ///    - starts with `'/admin'` -> ONLY `AppContext.admin`
  ///    - starts with `'/driver'` -> ONLY `AppContext.driver`
  ///    - starts with `'/provider'` -> ONLY `AppContext.provider`
  ///    - starts with `'/pending-verification'` -> `AppContext.provider` or `AppContext.driver`
  ///    - starts with `'/delivery/tracking'` or `'/home-services'` or `'/rewards'` -> ONLY `AppContext.customer`
  /// 4. Operational / Role-specific Notification Type classification:
  ///    - Operational admin types: `'admin_management'`, `'adminManagement'`, `'moderation'`,
  ///      `'approval'`, `'admin_topup'`, `'adminTopup'`, `'emergency_alert'`, `'emergencyAlert'`,
  ///      `'complaint_escalated'`, `'complaintEscalated'`, `'complaint_assigned'`, `'complaintAssigned'`,
  ///      `'chat_assigned'`, `'chatAssigned'`, `'chat_escalated'`, `'chatEscalated'`
  ///      -> ONLY `AppContext.admin` (NEVER shown in Customer, Driver, or Provider apps, even for the platform Owner!).
  ///    - Provider types: `'provider_profile'`, `'providerProfile'` -> ONLY `AppContext.provider`.
  ///    - Customer-only types: `'promotion'`, `'reward'` -> ONLY `AppContext.customer`.
  ///    - Regular user transactional types (`'order'`, `'order_update'`, `'delivery_update'`, `'ride_update'`,
  ///      `'payment'`, `'service'`, `'topup_approved'`, `'topupApproved'`, `'complaint'`, `'complaint_note'`,
  ///      `'complaintNote'`, `'account'`, `'security'`, `'reminder'`):
  ///      -> Visible in `AppContext.customer`, `AppContext.provider`, `AppContext.driver` (when deepLink allows),
  ///         and NOT shown in `AppContext.admin` unless explicitly targeted to `'admin'` or `'/admin...'`!
  ///         This guarantees that when the platform Owner opens the Admin App, they see ONLY operational/admin
  ///         notifications + global broadcasts, and when they open the Customer App, they see ONLY customer
  ///         notifications + global broadcasts!
  ///    - System/general broadcast types (`'system'`, `'info'`, `'warning'`, `'success'`, `'message'`,
  ///      `'chat_reply'`, `'chatReply'`, `'chat_closed'`, `'chatClosed'`, `'emergency'`, `'emergency_resolved'`,
  ///      `'emergencyResolved'`):
  ///      - If `deepLink` is present and starts with `'/admin'`, only `AppContext.admin`.
  ///      - Otherwise visible in the app contexts where the deepLink is allowed (or all contexts if no app-specific deepLink).
  static bool isVisibleInContext({
    String? type,
    String? deepLink,
    Map<String, dynamic>? data,
    String? targetApp,
    required AppContext context,
  }) {
    final rawTarget =
        (targetApp ??
                data?['target_app'] ??
                data?['target_role'] ??
                data?['audience'])
            ?.toString()
            .trim()
            .toLowerCase();

    if (rawTarget == 'all' || rawTarget == 'broadcast') {
      return true;
    }

    if (rawTarget != null && rawTarget.isNotEmpty) {
      if (const {
        'admin',
        'owner',
        'super_admin',
        'operational',
      }.contains(rawTarget)) {
        return context == AppContext.admin;
      }
      if (const {'customer', 'client', 'user'}.contains(rawTarget)) {
        return context == AppContext.customer;
      }
      if (const {'driver', 'delivery', 'courier'}.contains(rawTarget)) {
        return context == AppContext.driver;
      }
      if (const {
        'provider',
        'merchant',
        'vendor',
        'partner',
      }.contains(rawTarget)) {
        return context == AppContext.provider;
      }
    }

    final resolvedLink = (deepLink ?? data?['deep_link']?.toString() ?? '')
        .trim();
    if (resolvedLink.isNotEmpty) {
      if (resolvedLink.startsWith('/admin')) {
        return context == AppContext.admin;
      }
      if (resolvedLink.startsWith('/driver')) {
        return context == AppContext.driver;
      }
      if (resolvedLink.startsWith('/provider')) {
        return context == AppContext.provider;
      }
      if (resolvedLink.startsWith('/pending-verification')) {
        return context == AppContext.provider || context == AppContext.driver;
      }
      if (resolvedLink.startsWith('/delivery/tracking') ||
          resolvedLink.startsWith('/home-services') ||
          resolvedLink.startsWith('/rewards')) {
        return context == AppContext.customer;
      }
    }

    final resolvedType = (type ?? data?['type']?.toString() ?? 'system').trim();

    if (_adminOperationalTypes.contains(resolvedType)) {
      return context == AppContext.admin;
    }

    if (_providerOnlyTypes.contains(resolvedType)) {
      return context == AppContext.provider;
    }

    if (_customerOnlyTypes.contains(resolvedType)) {
      return context == AppContext.customer;
    }

    if (_userTransactionalTypes.contains(resolvedType)) {
      if (context == AppContext.admin) {
        return false;
      }
      if (resolvedLink.isNotEmpty && _matchesAnyChannel(resolvedLink)) {
        return isAllowed(resolvedLink, context: context);
      }
      return true;
    }

    if (resolvedLink.isNotEmpty && _matchesAnyChannel(resolvedLink)) {
      return isAllowed(resolvedLink, context: context);
    }
    return true;
  }

  /// Determines whether a raw database notification [row] belongs to the running [context] app.
  static bool isRowVisibleInContext(
    Map<String, dynamic> row, {
    required AppContext context,
  }) {
    final rawData = row['data'];
    final data = rawData is Map<String, dynamic>
        ? rawData
        : (rawData is Map ? Map<String, dynamic>.from(rawData) : null);
    final targetApp =
        (row['target_app'] ?? row['target_role'] ?? row['audience'])
            ?.toString();
    return isVisibleInContext(
      type: row['type']?.toString(),
      deepLink: row['deep_link']?.toString(),
      data: data,
      targetApp: targetApp,
      context: context,
    );
  }
}
