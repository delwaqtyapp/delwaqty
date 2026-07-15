/// A geographic coordinate point.
class GeoCoordinate {
  /// Creates a [GeoCoordinate] instance.
  const GeoCoordinate({
    required this.latitude,
    required this.longitude,
    this.altitude,
  });

  /// Latitude in decimal degrees.
  final double latitude;

  /// Longitude in decimal degrees.
  final double longitude;

  /// Optional altitude in meters above sea level.
  final double? altitude;

  /// Returns a string representation suitable for API calls.
  String get toQuery => '$latitude,$longitude';
}

/// A geographic address.
class Address {
  /// Creates an [Address] instance.
  const Address({
    this.formattedAddress,
    this.street,
    this.city,
    this.district,
    this.state,
    this.country,
    this.postalCode,
    this.coordinate,
    this.components = const {},
  });

  /// Full formatted address string.
  final String? formattedAddress;

  /// Street name and number.
  final String? street;

  /// City name.
  final String? city;

  /// District or neighborhood.
  final String? district;

  /// State or province.
  final String? state;

  /// Country name.
  final String? country;

  /// Postal or ZIP code.
  final String? postalCode;

  /// Geographic coordinate of this address.
  final GeoCoordinate? coordinate;

  /// Individual address components as key-value pairs.
  final Map<String, String> components;
}

/// Route result containing path and metadata.
class RouteResult {
  /// Creates a [RouteResult] instance.
  const RouteResult({
    required this.distance,
    required this.duration,
    required this.polyline,
    this.steps = const [],
    this.warnings = const [],
  });

  /// Total distance in meters.
  final double distance;

  /// Total duration of the route.
  final Duration duration;

  /// Encoded polyline for rendering on a map.
  final String polyline;

  /// Turn-by-turn navigation steps.
  final List<RouteStep> steps;

  /// Any warnings about the route.
  final List<String> warnings;
}

/// A single step in a navigation route.
class RouteStep {
  /// Creates a [RouteStep] instance.
  const RouteStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    this.startCoordinate,
    this.endCoordinate,
  });

  /// Human-readable navigation instruction.
  final String instruction;

  /// Distance for this step in meters.
  final double distance;

  /// Duration for this step.
  final Duration duration;

  /// Starting coordinate of this step.
  final GeoCoordinate? startCoordinate;

  /// Ending coordinate of this step.
  final GeoCoordinate? endCoordinate;
}

/// Mode of transportation for ETA calculation.
enum MapTravelMode {
  /// Driving by car.
  driving,

  /// Walking on foot.
  walking,

  /// Cycling.
  cycling,

  /// Public transit.
  transit,
}

/// A nearby search result.
class NearbyResult {
  /// Creates a [NearbyResult] instance.
  const NearbyResult({
    required this.id,
    required this.name,
    required this.coordinate,
    this.address,
    this.distance,
    this.rating,
    this.types = const [],
  });

  /// Unique identifier of the nearby place.
  final String id;

  /// Display name of the place.
  final String name;

  /// Geographic coordinate of the place.
  final GeoCoordinate coordinate;

  /// Human-readable address.
  final String? address;

  /// Distance from the search center in meters.
  final double? distance;

  /// User rating, if available.
  final double? rating;

  /// Place types or categories.
  final List<String> types;
}

/// Configuration for static map image generation.
class StaticMapOptions {
  /// Creates a [StaticMapOptions] instance.
  const StaticMapOptions({
    required this.center,
    required this.zoom,
    this.width = 600,
    this.height = 400,
    this.markers = const [],
    this.path,
    this.style,
  });

  /// Center coordinate of the map.
  final GeoCoordinate center;

  /// Map zoom level (0-21).
  final int zoom;

  /// Image width in pixels.
  final int width;

  /// Image height in pixels.
  final int height;

  /// Markers to display on the map.
  final List<StaticMapMarker> markers;

  /// Encoded polyline path to draw.
  final String? path;

  /// Map style identifier.
  final String? style;
}

/// A marker on a static map.
class StaticMapMarker {
  /// Creates a [StaticMapMarker] instance.
  const StaticMapMarker({
    required this.coordinate,
    this.label,
    this.color,
  });

  /// Position of the marker.
  final GeoCoordinate coordinate;

  /// Optional label for the marker.
  final String? label;

  /// Optional color for the marker.
  final String? color;
}

/// A polygon defined by geographic coordinates.
class GeoPolygon {
  /// Creates a [GeoPolygon] instance.
  const GeoPolygon({
    required this.points,
    this.name,
  });

  /// Ordered list of coordinates defining the polygon boundary.
  final List<GeoCoordinate> points;

  /// Optional name for the polygon.
  final String? name;
}

/// Unified map abstraction.
///
/// Provides route calculation, ETA estimation, nearby search, geocoding,
/// and map rendering across multiple map providers.
abstract interface class MapEngine {
  /// Initializes the map engine with the given [apiKey].
  ///
  /// Must be called before any other method.
  Future<void> initialize(String apiKey);

  /// Calculates a route from [origin] to [destination].
  ///
  /// Set [alternatives] to true to receive multiple route options.
  /// Set [avoidTolls] to avoid toll roads.
  Future<RouteResult> getRoute(
    GeoCoordinate origin,
    GeoCoordinate destination, {
    bool? alternatives,
    bool? avoidTolls,
  });

  /// Estimates the travel time from [origin] to [destination].
  ///
  /// [mode] specifies the transportation mode.
  Future<Duration> getETA(
    GeoCoordinate origin,
    GeoCoordinate destination, {
    MapTravelMode? mode,
  });

  /// Searches for nearby places matching [query] within [radius] meters
  /// of [location].
  Future<List<NearbyResult>> searchNearby(
    GeoCoordinate location,
    String query,
    double radius,
  );

  /// Generates a static map image URL for the given [options].
  String getStaticMap(StaticMapOptions options);

  /// Calculates the straight-line distance between two coordinates
  /// in meters.
  double calculateDistance(GeoCoordinate origin, GeoCoordinate destination);

  /// Converts a street [address] into geographic coordinates.
  Future<GeoCoordinate> geocode(String address);

  /// Converts geographic [coordinate] into a human-readable address.
  Future<Address> reverseGeocode(GeoCoordinate coordinate);

  /// Checks whether [point] is contained within the given [polygon].
  bool getPolygonContains(GeoCoordinate point, GeoPolygon polygon);
}
