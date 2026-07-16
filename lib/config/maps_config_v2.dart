/// Google Maps platform configuration.
///
/// Supports: Maps, Places, Directions, Distance Matrix, Geocoding, Nearby Search.
/// API key is injected via --dart-define.
abstract final class MapsConfig {
  // ─── API Keys ─────────────────────────────────────────────
  
  static const String apiKey = 'AIzaSyA9v-pk50aB3G45zIb_RQKxD5qo_CVX8GY';
  
  static const String androidApiKey = 'AIzaSyA9v-pk50aB3G45zIb_RQKxD5qo_CVX8GY';
  
  static const String iosApiKey = '';
  
  static const String webApiKey = '';

  // ─── API Endpoints ────────────────────────────────────────
  
  static const String directionsUrl = 'https://maps.googleapis.com/maps/api/directions/json';
  static const String placesUrl = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json';
  static const String geocodingUrl = 'https://maps.googleapis.com/maps/api/geocode/json';
  static const String distanceMatrixUrl = 'https://maps.googleapis.com/maps/api/distancematrix/json';
  static const String staticMapUrl = 'https://maps.googleapis.com/maps/api/staticmap';

  // ─── Default Location (Riyadh, Saudi Arabia) ──────────────
  
  static const double defaultLat = 24.7136;
  static const double defaultLng = 46.6753;
  static const double defaultZoom = 12.0;
  static const double minZoom = 3.0;
  static const double maxZoom = 20.0;

  // ─── Saudi Arabia Bounds ──────────────────────────────────
  
  static const double saMinLat = 16.0;
  static const double saMaxLat = 32.0;
  static const double saMinLng = 34.0;
  static const double saMaxLng = 56.0;

  // ─── Tracking Settings ────────────────────────────────────
  
  static const int trackingIntervalSeconds = 10;
  static const double geofenceBufferMetres = 50.0;
  static const int maxTrackingHistoryHours = 24;

  // ─── Validation ───────────────────────────────────────────
  
  static bool get isConfigured => apiKey.isNotEmpty;
  
  static String get platformKey {
    // Platform detection would go here in production
    return apiKey;
  }
}
