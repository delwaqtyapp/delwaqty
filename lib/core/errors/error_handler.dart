import 'package:delwaqty/core/errors/failures.dart';
import 'package:delwaqty/core/errors/exceptions.dart';

Failure handleException(Object error) {
  if (error is AppException) {
    return switch (error) {
      ServerException(:final message, :final statusCode) => Failure.server(
        message: _friendlyMessage(message, statusCode),
      ),
      CacheException(:final message) => Failure.cache(message: message),
      NetworkException(:final message) => Failure.network(message: message),
      AuthException(:final message) => Failure.auth(message: message),
      TimeoutException(:final message) => Failure.network(message: message),
      RateLimitException(:final message, :final retryAfter) => Failure.server(
        message: retryAfter != null
            ? 'طلبات كثيرة جداً. يرجى الانتظار ${retryAfter.inSeconds} ثانية.'
            : message,
      ),
      UnexpectedException(:final message) => Failure.unexpected(
        message: message,
      ),
    };
  }

  final message = error.toString();
  if (message.contains('SocketException') ||
      message.contains('Connection refused') ||
      message.contains('Network is unreachable')) {
    return Failure.network(
      message: 'لا يوجد اتصال بالإنترنت. يرجى التحقق من الشبكة.',
    );
  }
  if (message.contains('TimeoutException') || message.contains('Timed out')) {
    return Failure.network(message: 'انتهت مهلة الطلب. يرجى المحاولة مرة أخرى.');
  }

  return Failure.unexpected(message: 'حدث خطأ غير متوقع.');
}

String _friendlyMessage(String message, int? statusCode) {
  if (statusCode == 401) return 'انتهت الجلسة. يرجى تسجيل الدخول مرة أخرى.';
  if (statusCode == 403) return 'ليس لديك صلاحية لتنفيذ هذا الإجراء.';
  if (statusCode == 404) return 'المورد غير موجود.';
  if (statusCode == 429) return 'طلبات كثيرة جداً. يرجى الانتظار قليلاً.';
  if (statusCode != null && statusCode >= 500) {
    return 'خطأ في الخادم. يرجى المحاولة لاحقاً.';
  }
  return message;
}
