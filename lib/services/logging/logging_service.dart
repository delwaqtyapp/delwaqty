/// Severity level for log entries.
enum LogLevel {
  /// Verbose: finest-grained diagnostic information.
  verbose,

  /// Debug: debug-level messages.
  debug,

  /// Info: informational messages.
  info,

  /// Warning: potentially harmful situations.
  warning,

  /// Error: error events that might still allow the application to continue.
  error,
}

/// A single log entry with metadata.
class LogEntry {
  /// Creates a [LogEntry].
  const LogEntry({
    required this.level,
    required this.tag,
    required this.message,
    required this.timestamp,
    this.error,
    this.stackTrace,
  });

  /// Severity level of this entry.
  final LogLevel level;

  /// Tag identifying the source component.
  final String tag;

  /// Log message text.
  final String message;

  /// Timestamp when the entry was created.
  final DateTime timestamp;

  /// Associated error object, if any.
  final Object? error;

  /// Associated stack trace, if any.
  final StackTrace? stackTrace;
}

/// Abstract interface for application logging services.
///
/// Supports tagged, leveled logging with the ability to retrieve past
/// entries filtered by level and time range.
abstract interface class LoggingService {
  /// Logs a verbose [message] under the given [tag].
  void v(String tag, String message);

  /// Logs a debug [message] under the given [tag].
  void d(String tag, String message);

  /// Logs an info [message] under the given [tag].
  void i(String tag, String message);

  /// Logs a warning [message] under the given [tag].
  void w(String tag, String message);

  /// Logs an error [message] under the given [tag] with an optional [error]
  /// and [stackTrace].
  void e(String tag, String message, {Object? error, StackTrace? stackTrace});

  /// Sets the minimum [level] of log entries to capture.
  void setLevel(LogLevel level);

  /// Returns all log entries at or above [level] created since [since].
  List<LogEntry> getLogs({LogLevel? level, DateTime? since});
}
