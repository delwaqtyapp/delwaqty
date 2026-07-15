sealed class AppException implements Exception {
  const AppException({required this.message});
  final String message;

  @override
  String toString() => message;
}

class ServerException extends AppException {
  const ServerException({required super.message});
}

class CacheException extends AppException {
  const CacheException({required super.message});
}

class NetworkException extends AppException {
  const NetworkException({required super.message});
}

class AuthException extends AppException {
  const AuthException({required super.message});
}

class UnexpectedException extends AppException {
  const UnexpectedException({required super.message});
}
