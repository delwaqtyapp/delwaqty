/// A geographic coordinate point.
class GeoPoint {
  /// Creates a [GeoPoint] instance.
  const GeoPoint({
    required this.latitude,
    required this.longitude,
  });

  /// Latitude in decimal degrees.
  final double latitude;

  /// Longitude in decimal degrees.
  final double longitude;
}

/// A polygon defined by geographic coordinates.
class GeoPolygon {
  /// Creates a [GeoPolygon] instance.
  const GeoPolygon({
    required this.points,
  });

  /// Ordered list of coordinates defining the polygon boundary.
  final List<GeoPoint> points;
}

/// A dynamic pricing zone with a specific price multiplier.
class PricingZone {
  /// Creates a [PricingZone] instance.
  const PricingZone({
    required this.id,
    required this.name,
    required this.polygon,
    required this.multiplier,
    this.isActive = true,
    this.metadata = const {},
  });

  /// Unique identifier for this pricing zone.
  final String id;

  /// Human-readable name for this zone.
  final String name;

  /// Polygon defining the zone boundary.
  final GeoPolygon polygon;

  /// Price multiplier applied within this zone.
  final double multiplier;

  /// Whether this zone is currently active.
  final bool isActive;

  /// Additional metadata for the zone.
  final Map<String, dynamic> metadata;
}

/// Dynamic pricing zones abstraction.
///
/// Manages geographic zones with custom price multipliers to enable
/// location-based dynamic pricing.
abstract interface class DynamicPricingZoneService {
  /// Creates a new pricing zone.
  ///
  /// [name] is a human-readable label. [polygon] defines the zone
  /// boundary. [multiplier] is the price factor applied within the zone.
  Future<PricingZone> createZone(
    String name,
    GeoPolygon polygon,
    double multiplier,
  );

  /// Removes the pricing zone identified by [id].
  Future<void> removeZone(String id);

  /// Returns all currently active pricing zones.
  Future<List<PricingZone>> getActiveZones();

  /// Returns the price multiplier at the given [location].
  ///
  /// If the location falls within one or more active zones, returns
  /// the highest multiplier. Returns 1.0 if the location is outside
  /// all zones.
  Future<double> getMultiplierAt(GeoPoint location);

  /// Checks whether the given [location] falls inside any active
  /// pricing zone.
  Future<bool> isInPricingZone(GeoPoint location);
}
