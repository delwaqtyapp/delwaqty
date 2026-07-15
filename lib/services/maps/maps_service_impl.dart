import 'dart:async';
import 'package:delwaqty/features/commerce/domain/entities/geo_location.dart';
import 'package:delwaqty/services/maps/maps_service.dart';

/// No-op mock implementation of [MapsService] for development.
///
/// Returns empty or placeholder data for all map and routing operations.
class MapsServiceImpl implements MapsService {
  @override
  Future<Route> getRoute(GeoLocation origin, GeoLocation destination) async {
    return const Route(
      distanceMetres: 5000,
      duration: Duration(minutes: 15),
      steps: [],
      polyline: '',
    );
  }

  @override
  Future<Duration> getETA(GeoLocation origin, GeoLocation destination) async {
    return const Duration(minutes: 15);
  }

  @override
  Future<List<NearbyPlace>> searchNearby(
    GeoLocation location,
    String type,
    double radius,
  ) async {
    return const [];
  }

  @override
  String getStaticMapImage(GeoLocation center, int zoom, String size) {
    return 'https://via.placeholder.com/$size?text=Map';
  }

  @override
  void openNavigation(GeoLocation destination) {}

  @override
  GeofenceStatus getGeofenceStatus(
    GeoLocation location, {
    required GeoLocation geofenceCenter,
    required double geofenceRadiusMetres,
  }) {
    return GeofenceStatus.outside;
  }
}
