import 'dart:convert';
import 'package:delwaqty/services/analytics/analytics_service.dart';

/// Console-logging mock implementation of [AnalyticsService] for development.
///
/// Prints all analytics events to the debug console. Useful during local
/// development to verify that events are being fired correctly.
class AnalyticsServiceImpl implements AnalyticsService {
  @override
  void logEvent(String event, {Map<String, dynamic>? parameters}) {
    final buffer = StringBuffer('[Analytics] event: $event');
    if (parameters != null && parameters.isNotEmpty) {
      buffer.write(' params: ${jsonEncode(parameters)}');
    }
    // ignore: avoid_print
    print(buffer.toString());
  }

  @override
  void logScreenView(String screenName) {
    // ignore: avoid_print
    print('[Analytics] screen_view: $screenName');
  }

  @override
  void logPurchase({
    required double amount,
    required String currency,
    required List<Map<String, dynamic>> items,
  }) {
    // ignore: avoid_print
    print(
      '[Analytics] purchase: $amount $currency, items: ${items.length}',
    );
  }

  @override
  void setUserId(String userId) {
    // ignore: avoid_print
    print('[Analytics] setUserId: $userId');
  }

  @override
  void setUserProperty(String name, String value) {
    // ignore: avoid_print
    print('[Analytics] setUserProperty: $name = $value');
  }

  @override
  void logError(Object error, {StackTrace? stackTrace}) {
    // ignore: avoid_print
    print('[Analytics] error: $error');
    if (stackTrace != null) {
      // ignore: avoid_print
      print('[Analytics] stackTrace: $stackTrace');
    }
  }

  @override
  void logTiming({
    required String category,
    required String variable,
    required Duration time,
  }) {
    // ignore: avoid_print
    print(
      '[Analytics] timing: $category/$variable = ${time.inMilliseconds}ms',
    );
  }
}
