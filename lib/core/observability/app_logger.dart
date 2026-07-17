/// Central logging facade for the Delwaqty platform.
///
/// Provides a singleton-based structured logging system with configurable
/// log levels, crash report buffering, and consistent tagging across the app.
library;

import 'dart:collection';

/// Represents the severity level of a log message.
enum LogLevel {
  /// Verbose level - most detailed.
  verbose,

  /// Debug level - for development.
  debug,

  /// Info level - general information.
  info,

  /// Warning level - potential issues.
  warning,

  /// Error level - recoverable errors.
  error,

  /// Fatal level - unrecoverable errors.
  fatal,
}

/// A single log entry stored in the buffer.
class LogEntry {
  /// Creates a [LogEntry].
  const LogEntry({
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
    this.parameters,
    required this.timestamp,
  });

  /// The severity level of this entry.
  final LogLevel level;

  /// A tag to identify the source of the log.
  final String tag;

  /// The log message.
  final String message;

  /// An optional error associated with this log.
  final Object? error;

  /// An optional stack trace associated with this log.
  final StackTrace? stackTrace;

  /// Optional structured parameters.
  final Map<String, dynamic>? parameters;

  /// When this entry was created.
  final DateTime timestamp;

  @override
  String toString() => '[${level.name.toUpperCase()}] $tag: $message';
}

/// Abstract interface for logging.
///
/// Implementations may route logs to console, remote services, or file.
abstract class AppLogger {
  static AppLogger? _instance;

  /// The global singleton instance.
  static AppLogger get instance {
    assert(_instance != null, 'AppLogger has not been initialized.');
    return _instance!;
  }

  /// Sets the global singleton instance.
  static set instance(AppLogger logger) {
    _instance = logger;
  }

  /// Current minimum log level. Messages below this level are ignored.
  LogLevel get currentLevel;

  /// Sets the minimum log level.
  set currentLevel(LogLevel level);

  /// Maximum number of log entries kept in the crash-report buffer.
  int get bufferSize;

  /// Returns a read-only snapshot of the current log buffer.
  List<LogEntry> get buffer;

  /// Logs a verbose message.
  void verbose(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? parameters,
  });

  /// Logs a debug message.
  void debug(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? parameters,
  });

  /// Logs an informational message.
  void info(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? parameters,
  });

  /// Logs a warning message.
  void warning(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? parameters,
  });

  /// Logs an error message.
  void error(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? parameters,
  });

  /// Logs a fatal message.
  void fatal(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? parameters,
  });

  /// Clears the log buffer.
  void clearBuffer();
}

/// Default in-memory implementation of [AppLogger].
///
/// Stores log entries in a bounded circular buffer suitable for crash reports.
class DefaultAppLogger extends AppLogger {
  /// Creates a [DefaultAppLogger] with the given [initialLevel] and [maxBuffer].
  DefaultAppLogger({
    LogLevel initialLevel = LogLevel.debug,
    int maxBuffer = 500,
  }) : _currentLevel = initialLevel,
       _maxBuffer = maxBuffer;

  final Queue<LogEntry> _buffer = Queue<LogEntry>();
  LogLevel _currentLevel;
  final int _maxBuffer;

  @override
  LogLevel get currentLevel => _currentLevel;

  @override
  set currentLevel(LogLevel level) {
    _currentLevel = level;
  }

  @override
  int get bufferSize => _maxBuffer;

  @override
  List<LogEntry> get buffer => List.unmodifiable(_buffer);

  @override
  void verbose(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? parameters,
  }) {
    _log(
      LogLevel.verbose,
      tag,
      message,
      error: error,
      stackTrace: stackTrace,
      parameters: parameters,
    );
  }

  @override
  void debug(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? parameters,
  }) {
    _log(
      LogLevel.debug,
      tag,
      message,
      error: error,
      stackTrace: stackTrace,
      parameters: parameters,
    );
  }

  @override
  void info(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? parameters,
  }) {
    _log(
      LogLevel.info,
      tag,
      message,
      error: error,
      stackTrace: stackTrace,
      parameters: parameters,
    );
  }

  @override
  void warning(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? parameters,
  }) {
    _log(
      LogLevel.warning,
      tag,
      message,
      error: error,
      stackTrace: stackTrace,
      parameters: parameters,
    );
  }

  @override
  void error(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? parameters,
  }) {
    _log(
      LogLevel.error,
      tag,
      message,
      error: error,
      stackTrace: stackTrace,
      parameters: parameters,
    );
  }

  @override
  void fatal(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? parameters,
  }) {
    _log(
      LogLevel.fatal,
      tag,
      message,
      error: error,
      stackTrace: stackTrace,
      parameters: parameters,
    );
  }

  @override
  void clearBuffer() {
    _buffer.clear();
  }

  void _log(
    LogLevel level,
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? parameters,
  }) {
    if (level.index < _currentLevel.index) return;

    final entry = LogEntry(
      level: level,
      tag: tag,
      message: message,
      error: error,
      stackTrace: stackTrace,
      parameters: parameters,
      timestamp: DateTime.now(),
    );

    // Print to console (strip in release via tree-shaking if desired).
    // ignore: avoid_print
    print(entry);

    _buffer.add(entry);
    while (_buffer.length > _maxBuffer) {
      (_buffer as Queue).removeFirst();
    }
  }
}

/// No-op logger used in tests.
class NoOpAppLogger extends AppLogger {
  @override
  LogLevel get currentLevel => LogLevel.fatal;

  @override
  set currentLevel(LogLevel level) {}

  @override
  int get bufferSize => 0;

  @override
  List<LogEntry> get buffer => [];

  @override
  void verbose(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? parameters,
  }) {}

  @override
  void debug(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? parameters,
  }) {}

  @override
  void info(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? parameters,
  }) {}

  @override
  void warning(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? parameters,
  }) {}

  @override
  void error(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? parameters,
  }) {}

  @override
  void fatal(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? parameters,
  }) {}

  @override
  void clearBuffer() {}
}
