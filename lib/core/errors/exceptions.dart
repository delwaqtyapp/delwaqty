sealed class AppException implements Exception {
  const AppException({required this.message, this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ServerException extends AppException {
  const ServerException({required super.message, super.statusCode});
}

class CacheException extends AppException {
  const CacheException({required super.message});
}

class NetworkException extends AppException {
  const NetworkException({required super.message});
}

class AuthException extends AppException {
  const AuthException({required super.message, super.statusCode});
}

class TimeoutException extends AppException {
  const TimeoutException({required super.message});
}

class RateLimitException extends AppException {
  const RateLimitException({required super.message, this.retryAfter});

  final Duration? retryAfter;
}

class UnexpectedException extends AppException {
  const UnexpectedException({required super.message});
}
