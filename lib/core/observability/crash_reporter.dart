/// Crash reporting abstraction for the Delwaqty platform.
///
/// Provides a uniform API for capturing exceptions, managing breadcrumbs,
/// and tagging user context so implementations can target Sentry, Crashlytics,
/// or any other crash-reporting backend.
library;

/// Severity level for reported exceptions.
enum CrashSeverity {
  /// Debug-level severity.
  debug,

  /// Informational severity.
  info,

  /// Warning-level severity.
  warning,

  /// Error-level severity.
  error,

  /// Fatal severity.
  fatal,
}

/// Abstract interface for crash reporting.
abstract class CrashReporter {
  /// Initializes the reporter with the given [dsn].
  Future<void> initialize(String dsn);

  /// Captures an exception and returns a unique event ID.
  String captureException(
    Object error,
    StackTrace stackTrace, {
    CrashSeverity severity = CrashSeverity.error,
    Map<String, dynamic>? context,
  });

  /// Adds a breadcrumb to the current session.
  void addBreadcrumb(String message, {String? category, Map<String, dynamic>? data});

  /// Sets the current user context.
  void setUser(String userId, {String? email, String? name});

  /// Tags the current scope with a key-value pair.
  void setTag(String key, String value);

  /// Logs a plain message as an event.
  void log(String message);

  /// Flushes any pending reports to the server.
  Future<void> flush();
}

/// In-memory crash reporter for testing.
///
/// Stores captured exceptions and breadcrumbs for later inspection.
class DebugCrashReporter extends CrashReporter {
  final List<CapturedException> _exceptions = [];
  final List<Breadcrumb> _breadcrumbs = [];
  String? _dsn;

  /// Whether [initialize] has been called.
  bool get isInitialized => _dsn != null;

  /// All captured exceptions.
  List<CapturedException> get exceptions => List.unmodifiable(_exceptions);

  /// All breadcrumbs.
  List<Breadcrumb> get breadcrumbs => List.unmodifiable(_breadcrumbs);

  @override
  Future<void> initialize(String dsn) async {
    _dsn = dsn;
  }

  @override
  String captureException(
    Object error,
    StackTrace stackTrace, {
    CrashSeverity severity = CrashSeverity.error,
    Map<String, dynamic>? context,
  }) {
    final eventId = _generateEventId();
    _exceptions.add(CapturedException(
      eventId: eventId,
      error: error,
      stackTrace: stackTrace,
      severity: severity,
      context: context,
      timestamp: DateTime.now(),
    ));
    return eventId;
  }

  @override
  void addBreadcrumb(String message, {String? category, Map<String, dynamic>? data}) {
    _breadcrumbs.add(Breadcrumb(
      message: message,
      category: category,
      data: data,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void setUser(String userId, {String? email, String? name}) {
    _breadcrumbs.add(Breadcrumb(
      message: 'setUser: $userId',
      category: 'user',
      data: {'userId': userId, if (email != null) 'email': email, if (name != null) 'name': name},
      timestamp: DateTime.now(),
    ));
  }

  @override
  void setTag(String key, String value) {
    _breadcrumbs.add(Breadcrumb(
      message: 'setTag: $key=$value',
      category: 'tag',
      data: {key: value},
      timestamp: DateTime.now(),
    ));
  }

  @override
  void log(String message) {
    _breadcrumbs.add(Breadcrumb(
      message: message,
      timestamp: DateTime.now(),
    ));
  }

  @override
  Future<void> flush() async {
    // No-op in debug implementation.
  }

  static int _counter = 0;
  String _generateEventId() => 'evt-${++_counter}';
}

/// A captured exception record.
class CapturedException {
  /// Creates a [CapturedException].
  const CapturedException({
    required this.eventId,
    required this.error,
    required this.stackTrace,
    required this.severity,
    this.context,
    required this.timestamp,
  });

  /// Unique event identifier.
  final String eventId;

  /// The captured error.
  final Object error;

  /// The associated stack trace.
  final StackTrace stackTrace;

  /// Severity level.
  final CrashSeverity severity;

  /// Optional context metadata.
  final Map<String, dynamic>? context;

  /// When the exception was captured.
  final DateTime timestamp;
}

/// A navigation / interaction breadcrumb.
class Breadcrumb {
  /// Creates a [Breadcrumb].
  const Breadcrumb({
    required this.message,
    this.category,
    this.data,
    required this.timestamp,
  });

  /// Human-readable description.
  final String message;

  /// Category (e.g., navigation, user, http).
  final String? category;

  /// Arbitrary key-value data.
  final Map<String, dynamic>? data;

  /// When this breadcrumb was recorded.
  final DateTime timestamp;
}

/// No-op crash reporter for tests.
class NoOpCrashReporter extends CrashReporter {
  @override
  Future<void> initialize(String dsn) async {}

  @override
  String captureException(
    Object error,
    StackTrace stackTrace, {
    CrashSeverity severity = CrashSeverity.error,
    Map<String, dynamic>? context,
  }) =>
      '';

  @override
  void addBreadcrumb(String message, {String? category, Map<String, dynamic>? data}) {}

  @override
  void setUser(String userId, {String? email, String? name}) {}

  @override
  void setTag(String key, String value) {}

  @override
  void log(String message) {}

  @override
  Future<void> flush() async {}
}

/// Firebase Crashlytics implementation of [CrashReporter].
class FirebaseCrashReporter extends CrashReporter {
  FirebaseCrashReporter(this._crashlytics);

  final dynamic _crashlytics;

  @override
  Future<void> initialize(String dsn) async {
    await _crashlytics.setCrashlyticsCollectionEnabled(true);
  }

  @override
  String captureException(
    Object error,
    StackTrace stackTrace, {
    CrashSeverity severity = CrashSeverity.error,
    Map<String, dynamic>? context,
  }) {
    _crashlytics.recordError(
      error,
      stackTrace,
      reason: context?['reason'] as String?,
      printDetails: false,
    );
    return 'crashlytics-${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  void addBreadcrumb(String message, {String? category, Map<String, dynamic>? data}) {
    _crashlytics.log(message);
  }

  @override
  void setUser(String userId, {String? email, String? name}) {
    _crashlytics.setUserIdentifier(userId);
    if (email != null) _crashlytics.setCustomKey('email', email);
    if (name != null) _crashlytics.setCustomKey('name', name);
  }

  @override
  void setTag(String key, String value) {
    _crashlytics.setCustomKey(key, value);
  }

  @override
  void log(String message) {
    _crashlytics.log(message);
  }

  @override
  Future<void> flush() async {}
}
