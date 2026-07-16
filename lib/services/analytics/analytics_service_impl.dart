import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/analytics/analytics_service.dart';

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsServiceImpl(FirebaseAnalytics.instance);
});

class AnalyticsServiceImpl implements AnalyticsService {
  AnalyticsServiceImpl(this._analytics);

  final FirebaseAnalytics _analytics;

  @override
  void logEvent(String event, {Map<String, dynamic>? parameters}) {
    final params = parameters?.map(
      (key, value) => MapEntry(key, value.toString()),
    );
    _analytics.logEvent(name: event, parameters: params);
  }

  @override
  void logScreenView(String screenName) {
    _analytics.logScreenView(screenName: screenName);
  }

  @override
  void logPurchase({
    required double amount,
    required String currency,
    required List<Map<String, dynamic>> items,
  }) {
    _analytics.logPurchase(
      currency: currency,
      value: amount,
      items: items
          .map((item) => AnalyticsEventItem(
                itemId: item['id'] as String?,
                itemName: item['name'] as String?,
                itemCategory: item['category'] as String?,
              ))
          .toList(),
    );
  }

  @override
  void setUserId(String userId) {
    _analytics.setUserId(id: userId);
  }

  @override
  void setUserProperty(String name, String value) {
    _analytics.setUserProperty(name: name, value: value);
  }

  @override
  void logError(Object error, {StackTrace? stackTrace}) {
    _analytics.logEvent(
      name: 'app_error',
      parameters: {
        'error_type': error.runtimeType.toString(),
        'error_message': error.toString(),
        if (stackTrace != null) 'stack_trace': stackTrace.toString(),
      },
    );
  }

  @override
  void logTiming({
    required String category,
    required String variable,
    required Duration time,
  }) {
    _analytics.logEvent(
      name: 'timing',
      parameters: {
        'category': category,
        'variable': variable,
        'time_ms': time.inMilliseconds,
      },
    );
  }
}
