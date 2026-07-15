import 'package:delwaqty/services/logging/logging_service.dart';

/// Console-mocking implementation of [LoggingService] for development.
///
/// Prints all log entries to the debug console and retains them in memory
/// so they can be retrieved via [getLogs].
class LoggingServiceImpl implements LoggingService {
  LogLevel _currentLevel = LogLevel.debug;
  final List<LogEntry> _entries = [];

  @override
  void v(String tag, String message) {
    _log(LogLevel.verbose, tag, message);
  }

  @override
  void d(String tag, String message) {
    _log(LogLevel.debug, tag, message);
  }

  @override
  void i(String tag, String message) {
    _log(LogLevel.info, tag, message);
  }

  @override
  void w(String tag, String message) {
    _log(LogLevel.warning, tag, message);
  }

  @override
  void e(String tag, String message, {Object? error, StackTrace? stackTrace}) {
    final entry = LogEntry(
      level: LogLevel.error,
      tag: tag,
      message: message,
      timestamp: DateTime.now(),
      error: error,
      stackTrace: stackTrace,
    );
    _entries.add(entry);
    // ignore: avoid_print
    print('[ERROR][$tag] $message');
    if (error != null) {
      // ignore: avoid_print
      print('  error: $error');
    }
  }

  @override
  void setLevel(LogLevel level) {
    _currentLevel = level;
  }

  @override
  List<LogEntry> getLogs({LogLevel? level, DateTime? since}) {
    return _entries.where((entry) {
      if (level != null && entry.level.index < level.index) return false;
      if (since != null && entry.timestamp.isBefore(since)) return false;
      return true;
    }).toList();
  }

  void _log(LogLevel level, String tag, String message) {
    if (level.index < _currentLevel.index) return;
    final entry = LogEntry(
      level: level,
      tag: tag,
      message: message,
      timestamp: DateTime.now(),
    );
    _entries.add(entry);
    // ignore: avoid_print
    print('[${level.name.toUpperCase()}][$tag] $message');
  }
}
