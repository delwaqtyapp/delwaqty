import 'package:delwaqty/core/errors/failures.dart';
import 'package:delwaqty/core/errors/exceptions.dart';

Failure handleException(Object error) {
  if (error is AppException) {
    return switch (error) {
      ServerException(:final message, :final statusCode) =>
        Failure.server(message: _friendlyMessage(message, statusCode)),
      CacheException(:final message) => Failure.cache(message: message),
      NetworkException(:final message) => Failure.network(message: message),
      AuthException(:final message) => Failure.auth(message: message),
      TimeoutException(:final message) => Failure.network(message: message),
      RateLimitException(:final message, :final retryAfter) =>
        Failure.server(
          message: retryAfter != null
              ? 'Too many requests. Please wait ${retryAfter.inSeconds}s.'
              : message,
        ),
      UnexpectedException(:final message) =>
        Failure.unexpected(message: message),
    };
  }

  final message = error.toString();
  if (message.contains('SocketException') ||
      message.contains('Connection refused') ||
      message.contains('Network is unreachable')) {
    return Failure.network(
      message: 'No internet connection. Please check your network.',
    );
  }
  if (message.contains('TimeoutException') ||
      message.contains('Timed out')) {
    return Failure.network(
      message: 'Request timed out. Please try again.',
    );
  }

  return Failure.unexpected(message: 'An unexpected error occurred.');
}

String _friendlyMessage(String message, int? statusCode) {
  if (statusCode == 401) return 'Session expired. Please sign in again.';
  if (statusCode == 403) return 'You don\'t have permission for this action.';
  if (statusCode == 404) return 'Resource not found.';
  if (statusCode == 429) return 'Too many requests. Please wait a moment.';
  if (statusCode != null && statusCode >= 500) {
    return 'Server error. Please try again later.';
  }
  return message;
}
