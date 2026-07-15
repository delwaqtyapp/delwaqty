import 'package:logger/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final loggerProvider = Provider<AppLogger>((ref) {
  return AppLogger();
});

class AppLogger {
  AppLogger() : _logger = Logger(printer: PrettyPrinter());

  final Logger _logger;

  void d(String message) => _logger.d(message);
  void i(String message) => _logger.i(message);
  void w(String message) => _logger.w(message);
  void e(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }
}
