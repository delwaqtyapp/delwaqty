import 'package:delwaqty/core/errors/failures.dart';
import 'package:delwaqty/core/errors/exceptions.dart';

Failure handleException(Object error) {
  if (error is AppException) {
    return switch (error) {
      ServerException(:final message) => Failure.server(message: message),
      CacheException(:final message) => Failure.cache(message: message),
      NetworkException(:final message) => Failure.network(message: message),
      AuthException(:final message) => Failure.auth(message: message),
      UnexpectedException(:final message) =>
        Failure.unexpected(message: message),
    };
  }

  return Failure.unexpected(message: error.toString());
}
