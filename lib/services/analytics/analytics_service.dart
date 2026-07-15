/// Abstract interface for analytics and event tracking services.
///
/// Provides methods for logging screen views, user actions, purchases,
/// errors, and timing information to an analytics backend.
abstract interface class AnalyticsService {
  /// Logs a custom analytics [event] with optional [parameters].
  void logEvent(String event, {Map<String, dynamic>? parameters});

  /// Logs a screen view for the given [screenName].
  void logScreenView(String screenName);

  /// Logs a purchase event with the given [amount], [currency], and [items].
  void logPurchase({
    required double amount,
    required String currency,
    required List<Map<String, dynamic>> items,
  });

  /// Sets the user identifier for subsequent analytics events.
  void setUserId(String userId);

  /// Sets a user [property] with the given [name] and [value].
  void setUserProperty(String name, String value);

  /// Logs an [error] with an optional [stackTrace] for crash analytics.
  void logError(Object error, {StackTrace? stackTrace});

  /// Logs a timing measurement under the given [category] and [variable].
  void logTiming({
    required String category,
    required String variable,
    required Duration time,
  });
}
