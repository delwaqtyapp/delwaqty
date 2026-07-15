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

/// A circular geofence definition.
class Geofence {
  /// Creates a [Geofence] instance.
  const Geofence({
    required this.id,
    required this.center,
    required this.radius,
    required this.name,
    this.metadata = const {},
    this.isActive = true,
  });

  /// Unique identifier for this geofence.
  final String id;

  /// Center point of the geofence.
  final GeoPoint center;

  /// Radius in meters.
  final double radius;

  /// Human-readable name for this geofence.
  final String name;

  /// Additional metadata associated with the geofence.
  final Map<String, dynamic> metadata;

  /// Whether this geofence is currently active.
  final bool isActive;
}

/// Status of a location relative to a geofence.
enum GeofenceStatus {
  /// Location is outside the geofence.
  outside,

  /// Location is inside the geofence.
  inside,

  /// Location is on the boundary of the geofence.
  boundary,

  /// Geofence status could not be determined.
  unknown,
}

/// An event emitted when a geofence boundary is crossed.
class GeofenceEvent {
  /// Creates a [GeofenceEvent] instance.
  const GeofenceEvent({
    required this.geofenceId,
    required this.geofenceName,
    required this.eventType,
    required this.location,
    required this.timestamp,
  });

  /// Identifier of the triggered geofence.
  final String geofenceId;

  /// Name of the triggered geofence.
  final String geofenceName;

  /// Type of geofence event.
  final GeofenceEventType eventType;

  /// Location that triggered the event.
  final GeoPoint location;

  /// When the event occurred.
  final DateTime timestamp;
}

/// Types of geofence events.
enum GeofenceEventType {
  /// Location entered the geofence area.
  enter,

  /// Location exited the geofence area.
  exit,

  /// Location dwell time threshold was reached inside the geofence.
  dwell,
}

/// Geofence abstraction.
///
/// Manages creation, removal, status checking, and event streaming
/// for geographic boundary monitoring.
abstract interface class GeofencingService {
  /// Creates a new geofence with the given parameters.
  ///
  /// [id] must be unique. [center] defines the center point. [radius]
  /// is in meters. [name] is a human-readable label.
  Future<Geofence> createGeofence(
    String id,
    GeoPoint center,
    double radius,
    String name,
  );

  /// Removes the geofence identified by [id].
  Future<void> removeGeofence(String id);

  /// Returns all currently active geofences.
  Future<List<Geofence>> getActiveGeofences();

  /// Checks whether [location] is inside, outside, or on the boundary
  /// of the geofence identified by [geofenceId].
  Future<GeofenceStatus> checkStatus(GeoPoint location, String geofenceId);

  /// A stream of geofence events (enter, exit, dwell).
  Stream<GeofenceEvent> onGeofenceEvent();

  /// Updates an existing geofence identified by [id].
  ///
  /// Only provided parameters are updated.
  Future<void> updateGeofence(
    String id, {
    GeoPoint? center,
    double? radius,
    String? name,
  });
}
