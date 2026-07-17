import 'package:delwaqty/config/app_config.dart';

/// Google Maps configuration — delegates to [AppConfig].
abstract final class MapsConfig {
  static String get apiKey => AppConfig.mapsApiKey;

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
