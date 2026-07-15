import 'dart:async';
import 'package:delwaqty/features/commerce/domain/entities/geo_location.dart';

/// Represents a single leg/step in a navigation route.
class RouteStep {
  /// Creates a [RouteStep].
  const RouteStep({
    required this.instruction,
    required this.distanceMetres,
    required this.duration,
    required this.startLocation,
    required this.endLocation,
  });

  /// Human-readable navigation instruction.
  final String instruction;

  /// Distance of this step in metres.
  final double distanceMetres;

  /// Estimated duration to complete this step.
  final Duration duration;

  /// Starting location of this step.
  final GeoLocation startLocation;

  /// Ending location of this step.
  final GeoLocation endLocation;
}

/// A complete route between an origin and a destination.
class Route {
  /// Creates a [Route].
  const Route({
    required this.distanceMetres,
    required this.duration,
    required this.steps,
    required this.polyline,
  });

  /// Total distance of the route in metres.
  final double distanceMetres;

  /// Total estimated travel time.
  final Duration duration;

  /// Ordered list of navigation steps.
  final List<RouteStep> steps;

  /// Encoded polyline string representing the route path on a map.
  final String polyline;
}

/// A place found during a nearby search.
class NearbyPlace {
  /// Creates a [NearbyPlace].
  const NearbyPlace({
    required this.id,
    required this.name,
    required this.location,
    required this.type,
    this.rating,
    this.distanceMetres,
    this.isOpenNow,
  });

  /// Unique identifier of the place.
  final String id;

  /// Display name of the place.
  final String name;

  /// Geographic location of the place.
  final GeoLocation location;

  /// Category/type of the place (e.g. restaurant, pharmacy).
  final String type;

  /// Average user rating, if available.
  final double? rating;

  /// Distance from the search centre in metres.
  final double? distanceMetres;

  /// Whether the place is currently open.
  final bool? isOpenNow;
}

/// Status of a location relative to a geofence.
enum GeofenceStatus {
  /// Location is inside the geofence.
  inside,

  /// Location is outside the geofence.
  outside,

  /// Location is on the boundary of the geofence.
  onBoundary,
}

/// Abstract interface for map and navigation services.
///
/// Provides routing, ETA calculation, nearby place search, static map
/// imagery, navigation launch, and geofence status checks.
abstract interface class MapsService {
  /// Computes a route between [origin] and [destination].
  Future<Route> getRoute(GeoLocation origin, GeoLocation destination);

  /// Returns the estimated travel time from [origin] to [destination].
  Future<Duration> getETA(GeoLocation origin, GeoLocation destination);

  /// Searches for nearby places of the given [type] within [radius] metres
  /// of [location].
  Future<List<NearbyPlace>> searchNearby(
    GeoLocation location,
    String type,
    double radius,
  );

  /// Returns a URL for a static map image centred at [center] with the
  /// given [zoom] level and pixel [size].
  String getStaticMapImage(GeoLocation center, int zoom, String size);

  /// Launches external navigation to [destination] using the device's
  /// default maps application.
  void openNavigation(GeoLocation destination);

  /// Determines whether [location] is inside, outside, or on the boundary
  /// of the specified [geofence] circle.
  GeofenceStatus getGeofenceStatus(
    GeoLocation location, {
    required GeoLocation geofenceCenter,
    required double geofenceRadiusMetres,
  });
}
