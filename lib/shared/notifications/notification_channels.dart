class NotificationChannel {
  const NotificationChannel(this.pattern, {this.adminOnly = false});

  final String pattern;
  final bool adminOnly;

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
}

class NotificationChannels {
  static const List<NotificationChannel> channels = [
    NotificationChannel('/admin/complaints', adminOnly: true),
    NotificationChannel('/admin/live-tracking', adminOnly: true),
    NotificationChannel('/admin/support-chat/room/:roomId', adminOnly: true),
    NotificationChannel('/campaign/:id'),
    NotificationChannel('/my-complaints'),
    NotificationChannel('/notifications'),
    NotificationChannel('/orders'),
    NotificationChannel('/profile'),
    NotificationChannel('/rewards'),
    NotificationChannel('/safety'),
    NotificationChannel('/support/room/:roomId'),
    NotificationChannel('/wallet'),
  ];

  static bool isAllowed(String route, {required bool isAdmin}) {
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
      if (channel.matches(normalized)) {
        return channel.adminOnly ? isAdmin : true;
      }
    }
    return false;
  }
}
