/// Google Maps configuration.
abstract final class MapsConfig {
  /// Google Maps API key (Android/iOS/web).
  static const String apiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'your-google-maps-api-key',
  );

  /// Default map center (Riyadh, Saudi Arabia).
  static const double defaultLat = 24.7136;
  static const double defaultLng = 46.6753;

  /// Default zoom level.
  static const double defaultZoom = 12.0;

  /// Default map bounds for Saudi Arabia.
  static const double minLat = 16.0;
  static const double maxLat = 32.0;
  static const double minLng = 34.0;
  static const double maxLng = 56.0;
}
