/// A geographic coordinate.
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

/// Constraints applied to route optimization.
class RouteConstraints {
  /// Creates a [RouteConstraints] instance.
  const RouteConstraints({
    this.avoidTolls = false,
    this.avoidHighways = false,
    this.avoidFerries = false,
    this.maxWalkingDistance,
    this.departureTime,
    this.arriveBy,
    this.vehicleType,
  });

  /// Whether to avoid toll roads.
  final bool avoidTolls;

  /// Whether to avoid highways.
  final bool avoidHighways;

  /// Whether to avoid ferries.
  final bool avoidFerries;

  /// Maximum walking distance in meters.
  final double? maxWalkingDistance;

  /// Preferred departure time.
  final DateTime? departureTime;

  /// Preferred arrival time (for arrive-by routing).
  final DateTime? arriveBy;

  /// Type of vehicle for routing (e.g., "car", "bike", "truck").
  final String? vehicleType;
}

/// An optimized route from origin through destinations.
class OptimizedRoute {
  /// Creates an [OptimizedRoute] instance.
  const OptimizedRoute({
    required this.waypoints,
    required this.totalDistance,
    required this.totalDuration,
    this.segments = const [],
    this.polyline,
    this.tollCost,
    this.fuelCost,
  });

  /// Ordered list of waypoints in the optimized route.
  final List<GeoPoint> waypoints;

  /// Total distance in meters.
  final double totalDistance;

  /// Total estimated duration.
  final Duration totalDuration;

  /// Individual route segments between consecutive waypoints.
  final List<RouteSegment> segments;

  /// Encoded polyline for map rendering.
  final String? polyline;

  /// Estimated toll cost, if applicable.
  final double? tollCost;

  /// Estimated fuel cost, if applicable.
  final double? fuelCost;
}

/// A segment of a route between two waypoints.
class RouteSegment {
  /// Creates a [RouteSegment] instance.
  const RouteSegment({
    required this.from,
    required this.to,
    required this.distance,
    required this.duration,
    this.instructions = const [],
  });

  /// Starting point of this segment.
  final GeoPoint from;

  /// Ending point of this segment.
  final GeoPoint to;

  /// Distance of this segment in meters.
  final double distance;

  /// Estimated duration of this segment.
  final Duration duration;

  /// Turn-by-turn navigation instructions.
  final List<String> instructions;
}

/// Mode of transportation.
enum TransportMode {
  /// Driving by car.
  driving,

  /// Walking on foot.
  walking,

  /// Cycling.
  cycling,

  /// Public transit.
  transit,

  /// Ride-hailing service.
  rideshare,
}

/// Estimated time of arrival result.
class ETAResult {
  /// Creates an [ETAResult] instance.
  const ETAResult({
    required this.duration,
    required this.distance,
    this.trafficDelay,
    this.departureTime,
    this.arrivalTime,
  });

  /// Estimated travel duration.
  final Duration duration;

  /// Distance in meters.
  final double distance;

  /// Additional delay due to traffic conditions.
  final Duration? trafficDelay;

  /// Suggested departure time.
  final DateTime? departureTime;

  /// Expected arrival time.
  final DateTime? arrivalTime;
}

/// An order to be assigned to a driver.
class RoutingOrder {
  /// Creates a [RoutingOrder] instance.
  const RoutingOrder({
    required this.id,
    required this.pickup,
    required this.dropoff,
    this.estimatedDuration,
    this.priority = 0,
  });

  /// Unique order identifier.
  final String id;

  /// Pickup location.
  final GeoPoint pickup;

  /// Dropoff location.
  final GeoPoint dropoff;

  /// Estimated service duration at the pickup.
  final Duration? estimatedDuration;

  /// Priority level (higher = more urgent).
  final int priority;
}

/// A driver available for assignment.
class DriverCandidate {
  /// Creates a [DriverCandidate] instance.
  const DriverCandidate({
    required this.id,
    required this.currentLocation,
    required this.serviceType,
    this.rating = 5.0,
    this.currentLoad = 0,
    this.maxLoad = 1,
  });

  /// Unique driver identifier.
  final String id;

  /// Driver's current location.
  final GeoPoint currentLocation;

  /// Type of service the driver provides.
  final String serviceType;

  /// Driver's average rating.
  final double rating;

  /// Number of currently assigned orders.
  final int currentLoad;

  /// Maximum number of orders the driver can handle.
  final int maxLoad;
}

/// Result of matching an order to the best driver.
class DriverMatch {
  /// Creates a [DriverMatch] instance.
  const DriverMatch({
    required this.driverId,
    required this.score,
    required this.estimatedPickupTime,
    required this.distance,
    this.reason,
  });

  /// Identifier of the matched driver.
  final String driverId;

  /// Match quality score (higher = better match).
  final double score;

  /// Estimated time until the driver reaches the pickup.
  final Duration estimatedPickupTime;

  /// Distance from driver to pickup in meters.
  final double distance;

  /// Human-readable explanation of the match score.
  final String? reason;
}

/// Result of load balancing across drivers.
class LoadBalancingResult {
  /// Creates a [LoadBalancingResult] instance.
  const LoadBalancingResult({
    required this.assignments,
    required this.unassignedOrders,
    this.balanceScore,
  });

  /// Map of driver ID to assigned order IDs.
  final Map<String, List<String>> assignments;

  /// Order IDs that could not be assigned.
  final List<String> unassignedOrders;

  /// Overall balance score (1.0 = perfectly balanced).
  final double? balanceScore;
}

/// Current traffic condition between two points.
class TrafficCondition {
  /// Creates a [TrafficCondition] instance.
  const TrafficCondition({
    required this.level,
    required this.delayFactor,
    this.incidents = const [],
  });

  /// Traffic congestion level.
  final TrafficLevel level;

  /// Delay factor multiplier (1.0 = free flow).
  final double delayFactor;

  /// Active incidents affecting the route.
  final List<TrafficIncident> incidents;
}

/// Traffic congestion level.
enum TrafficLevel {
  /// Free-flowing traffic.
  freeFlow,

  /// Light congestion.
  light,

  /// Moderate congestion.
  moderate,

  /// Heavy congestion.
  heavy,

  /// Standstill / gridlock.
  standstill,
}

/// A traffic incident on the route.
class TrafficIncident {
  /// Creates a [TrafficIncident] instance.
  const TrafficIncident({
    required this.type,
    required this.description,
    this.location,
  });

  /// Type of incident (e.g., "accident", "construction", "closure").
  final String type;

  /// Human-readable description.
  final String description;

  /// Location of the incident, if known.
  final GeoPoint? location;
}

/// Smart routing abstraction.
///
/// Optimizes routes, predicts arrival times, matches orders to drivers,
/// balances workloads, and provides real-time traffic conditions.
abstract interface class SmartRoutingService {
  /// Optimizes a route from [origin] through all [destinations].
  Future<OptimizedRoute> optimizeRoute(
    GeoPoint origin,
    List<GeoPoint> destinations, {
    RouteConstraints? constraints,
  });

  /// Predicts the travel duration from [origin] to [destination].
  Future<ETAResult> predictArrivalTime(
    GeoPoint origin,
    GeoPoint destination, {
    TransportMode mode = TransportMode.driving,
  });

  /// Finds the best driver from [candidates] to fulfill the given [order].
  Future<DriverMatch> findOptimalDriver(
    RoutingOrder order,
    List<DriverCandidate> candidates,
  );

  /// Balances the load of [orders] across available [drivers].
  Future<LoadBalancingResult> balanceLoad(
    List<RoutingOrder> orders,
    List<DriverCandidate> drivers,
  );

  /// Returns the current traffic condition from [origin] to [destination].
  Future<TrafficCondition> getTrafficCondition(
    GeoPoint origin,
    GeoPoint destination,
  );
}

/// Debug implementation of [SmartRoutingService].
class DebugSmartRoutingService implements SmartRoutingService {
  @override
  Future<OptimizedRoute> optimizeRoute(
    GeoPoint origin,
    List<GeoPoint> destinations, {
    RouteConstraints? constraints,
  }) async =>
      OptimizedRoute(
        waypoints: [origin, ...destinations],
        totalDistance: 0,
        totalDuration: Duration.zero,
      );

  @override
  Future<ETAResult> predictArrivalTime(
    GeoPoint origin,
    GeoPoint destination, {
    TransportMode mode = TransportMode.driving,
  }) async =>
      ETAResult(duration: const Duration(minutes: 15), distance: 5.0);

  @override
  Future<DriverMatch> findOptimalDriver(
    RoutingOrder order,
    List<DriverCandidate> candidates,
  ) async =>
      DriverMatch(
        driverId: candidates.firstOrNull?.id ?? '',
        score: 0.5,
        estimatedPickupTime: const Duration(minutes: 5),
        distance: 2.0,
      );

  @override
  Future<LoadBalancingResult> balanceLoad(
    List<RoutingOrder> orders,
    List<DriverCandidate> drivers,
  ) async =>
      LoadBalancingResult(assignments: {}, unassignedOrders: []);

  @override
  Future<TrafficCondition> getTrafficCondition(
    GeoPoint origin,
    GeoPoint destination,
  ) async =>
      TrafficCondition(level: TrafficLevel.freeFlow, delayFactor: 1.0);
}
