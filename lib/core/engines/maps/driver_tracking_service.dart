/// A geographic coordinate point.
class GeoPoint {
  /// Creates a [GeoPoint] instance.
  const GeoPoint({required this.latitude, required this.longitude});

  /// Latitude in decimal degrees.
  final double latitude;

  /// Longitude in decimal degrees.
  final double longitude;
}

/// A driver's current location with metadata.
class DriverLocation {
  /// Creates a [DriverLocation] instance.
  const DriverLocation({
    required this.driverId,
    required this.coordinate,
    required this.timestamp,
    this.heading,
    this.speed,
    this.serviceType,
    this.isOnline = true,
  });

  /// Identifier of the driver.
  final String driverId;

  /// Current geographic coordinate.
  final GeoPoint coordinate;

  /// Timestamp of the location update.
  final DateTime timestamp;

  /// Heading in degrees (0-360), where 0 is north.
  final double? heading;

  /// Current speed in meters per second.
  final double? speed;

  /// Type of service the driver provides.
  final String? serviceType;

  /// Whether the driver is currently online and accepting orders.
  final bool isOnline;
}

/// Heatmap data point for visualization.
class HeatmapDataPoint {
  /// Creates a [HeatmapDataPoint] instance.
  const HeatmapDataPoint({required this.coordinate, required this.intensity});

  /// Geographic coordinate of the data point.
  final GeoPoint coordinate;

  /// Intensity value (0.0 - 1.0) for the heatmap.
  final double intensity;
}

/// Aggregated heatmap data for driver density visualization.
class HeatmapData {
  /// Creates a [HeatmapData] instance.
  const HeatmapData({required this.points, this.boundingBox, this.timestamp});

  /// List of weighted data points.
  final List<HeatmapDataPoint> points;

  /// Bounding box containing all data points.
  final HeatmapBoundingBox? boundingBox;

  /// Timestamp when the data was collected.
  final DateTime? timestamp;
}

/// Bounding box for heatmap data.
class HeatmapBoundingBox {
  /// Creates a [HeatmapBoundingBox] instance.
  const HeatmapBoundingBox({required this.northEast, required this.southWest});

  /// North-east corner of the bounding box.
  final GeoPoint northEast;

  /// South-west corner of the bounding box.
  final GeoPoint southWest;
}

/// Driver live tracking abstraction.
///
/// Provides real-time location tracking for drivers, including
/// individual tracking, bulk location queries, and heatmap generation.
abstract interface class DriverTrackingService {
  /// Starts live location tracking for the driver identified by [driverId].
  Future<void> startTracking(String driverId);

  /// Stops live location tracking for the driver identified by [driverId].
  Future<void> stopTracking(String driverId);

  /// Returns the last known location of the driver, or null if unknown.
  Future<GeoPoint?> getDriverLocation(String driverId);

  /// Returns locations of all drivers providing the given [serviceType].
  ///
  /// If [serviceType] is null, returns drivers of all service types.
  Future<List<DriverLocation>> getAllDriverLocations(String? serviceType);

  /// A stream of location updates for the specified [driverId].
  Stream<GeoPoint> onDriverLocationChanged(String driverId);

  /// Returns the count of active (online and tracked) drivers
  /// for the given [serviceType].
  Future<int> getActiveDriversCount(String? serviceType);

  /// Generates heatmap data for driver density visualization
  /// for the given [serviceType].
  Future<HeatmapData> getHeatmapData(String? serviceType);
}
