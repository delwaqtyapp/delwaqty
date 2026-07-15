/// Analytics abstraction for the Delwaqty platform.
///
/// Defines the contract for logging user interactions, screen views,
/// e-commerce events, and user properties to any analytics backend.
library;

/// Abstract interface for analytics.
///
/// Implementations may route events to Firebase Analytics, Amplitude,
/// Mixpanel, or any other provider.
abstract class AppAnalytics {
  static AppAnalytics? _instance;

  /// The global singleton instance.
  static AppAnalytics get instance {
    assert(_instance != null, 'AppAnalytics has not been initialized.');
    return _instance!;
  }

  /// Sets the global singleton instance.
  static set instance(AppAnalytics analytics) {
    _instance = analytics;
  }

  /// Logs a generic named event with optional parameters.
  void logEvent(String name, {Map<String, dynamic>? parameters});

  /// Logs a screen view event.
  void logScreenView(String screenName, {String? className});

  /// Logs a purchase transaction.
  ///
  /// [value] should be in the smallest currency unit (e.g., cents).
  void logPurchase({
    required double value,
    required String currency,
    required List<Map<String, dynamic>> items,
  });

  /// Logs an add-to-cart action.
  void logAddToCart({
    required String itemId,
    required String itemName,
    required double value,
  });

  /// Logs a share action.
  void logShare({
    required String contentType,
    required String itemId,
    required String method,
  });

  /// Logs a search action.
  void logSearch({
    required String searchTerm,
    String? contentType,
  });

  /// Sets the current user ID for all future events.
  void setUserId(String userId);

  /// Sets a user property value.
  void setUserProperty({required String name, required String value});
}

/// In-memory analytics that stores events for inspection.
///
/// Useful for debugging and testing.
class DebugAnalytics extends AppAnalytics {
  final List<AnalyticsEvent> _events = [];

  /// All events recorded since creation.
  List<AnalyticsEvent> get events => List.unmodifiable(_events);

  @override
  void logEvent(String name, {Map<String, dynamic>? parameters}) {
    _events.add(AnalyticsEvent(
      type: AnalyticsEventType.event,
      name: name,
      parameters: parameters,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void logScreenView(String screenName, {String? className}) {
    _events.add(AnalyticsEvent(
      type: AnalyticsEventType.screenView,
      name: screenName,
      parameters: className != null ? {'class_name': className} : null,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void logPurchase({
    required double value,
    required String currency,
    required List<Map<String, dynamic>> items,
  }) {
    _events.add(AnalyticsEvent(
      type: AnalyticsEventType.purchase,
      name: 'purchase',
      parameters: {
        'value': value,
        'currency': currency,
        'items': items,
      },
      timestamp: DateTime.now(),
    ));
  }

  @override
  void logAddToCart({
    required String itemId,
    required String itemName,
    required double value,
  }) {
    _events.add(AnalyticsEvent(
      type: AnalyticsEventType.addToCart,
      name: 'add_to_cart',
      parameters: {
        'item_id': itemId,
        'item_name': itemName,
        'value': value,
      },
      timestamp: DateTime.now(),
    ));
  }

  @override
  void logShare({
    required String contentType,
    required String itemId,
    required String method,
  }) {
    _events.add(AnalyticsEvent(
      type: AnalyticsEventType.share,
      name: 'share',
      parameters: {
        'content_type': contentType,
        'item_id': itemId,
        'method': method,
      },
      timestamp: DateTime.now(),
    ));
  }

  @override
  void logSearch({
    required String searchTerm,
    String? contentType,
  }) {
    _events.add(AnalyticsEvent(
      type: AnalyticsEventType.search,
      name: 'search',
      parameters: {
        'search_term': searchTerm,
        if (contentType != null) 'content_type': contentType,
      },
      timestamp: DateTime.now(),
    ));
  }

  @override
  void setUserId(String userId) {
    _events.add(AnalyticsEvent(
      type: AnalyticsEventType.setUserId,
      name: 'set_user_id',
      parameters: {'user_id': userId},
      timestamp: DateTime.now(),
    ));
  }

  @override
  void setUserProperty({required String name, required String value}) {
    _events.add(AnalyticsEvent(
      type: AnalyticsEventType.setUserProperty,
      name: 'set_user_property',
      parameters: {'property_name': name, 'property_value': value},
      timestamp: DateTime.now(),
    ));
  }
}

/// Categories of analytics events.
enum AnalyticsEventType {
  /// Generic event.
  event,

  /// Screen view.
  screenView,

  /// Purchase.
  purchase,

  /// Add to cart.
  addToCart,

  /// Share.
  share,

  /// Search.
  search,

  /// Set user ID.
  setUserId,

  /// Set user property.
  setUserProperty,
}

/// Represents a single recorded analytics event.
class AnalyticsEvent {
  /// Creates an [AnalyticsEvent].
  const AnalyticsEvent({
    required this.type,
    required this.name,
    this.parameters,
    required this.timestamp,
  });

  /// The type of event.
  final AnalyticsEventType type;

  /// The event name.
  final String name;

  /// Optional parameters.
  final Map<String, dynamic>? parameters;

  /// When this event was recorded.
  final DateTime timestamp;

  @override
  String toString() => '[${type.name}] $name ${parameters ?? ''}';
}

/// No-op analytics used in tests.
class NoOpAnalytics extends AppAnalytics {
  @override
  void logEvent(String name, {Map<String, dynamic>? parameters}) {}

  @override
  void logScreenView(String screenName, {String? className}) {}

  @override
  void logPurchase({
    required double value,
    required String currency,
    required List<Map<String, dynamic>> items,
  }) {}

  @override
  void logAddToCart({
    required String itemId,
    required String itemName,
    required double value,
  }) {}

  @override
  void logShare({
    required String contentType,
    required String itemId,
    required String method,
  }) {}

  @override
  void logSearch({required String searchTerm, String? contentType}) {}

  @override
  void setUserId(String userId) {}

  @override
  void setUserProperty({required String name, required String value}) {}
}
