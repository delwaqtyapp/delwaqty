import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/services/logger/app_logger.dart';

class RetryUtil {
  RetryUtil(this._logger);

  final AppLogger _logger;

  Future<T> withRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    Duration maxDelay = const Duration(seconds: 30),
    bool Function(Object error)? retryWhen,
  }) async {
    var attempt = 0;
    var delay = initialDelay;

    while (true) {
      try {
        return await operation();
      } catch (e) {
        attempt++;

        final shouldRetry =
            (retryWhen?.call(e) ?? _isRetryable(e)) && attempt < maxRetries;

        if (!shouldRetry) {
          _logger.e('Operation failed after $attempt attempts', e);
          rethrow;
        }

        _logger.w(
          'Attempt $attempt/$maxRetries failed, retrying in ${delay.inMilliseconds}ms',
        );
        await Future<void>.delayed(delay);
        delay = Duration(
          milliseconds: (delay.inMilliseconds * 2).clamp(
            0,
            maxDelay.inMilliseconds,
          ),
        );
      }
    }
  }

  bool _isRetryable(Object error) {
    if (error is RateLimitException) return true;
    if (error is TimeoutException) return true;
    if (error is NetworkException) return true;
    if (error is ServerException) {
      final code = error.statusCode;
      if (code == null) return false;
      return code == 429 || code >= 500;
    }
    final message = error.toString().toLowerCase();
    return message.contains('timeout') ||
        message.contains('network') ||
        message.contains('connection') ||
        message.contains('socket');
  }
}

final retryUtilProvider = Provider<RetryUtil>((ref) {
  return RetryUtil(ref.watch(loggerProvider));
});
