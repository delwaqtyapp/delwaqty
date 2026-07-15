import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:delwaqty/config/maps_config.dart';
import 'package:delwaqty/features/commerce/domain/entities/geo_location.dart';
import 'package:delwaqty/services/maps/maps_service.dart';

/// Google Maps implementation of [MapsService].
///
/// Uses the Google Maps Directions, Places, and Geocoding HTTP APIs.
///
/// Requires `GOOGLE_MAPS_API_KEY` environment variable to be set.
class GoogleMapsServiceImpl implements MapsService {
  GoogleMapsServiceImpl({String? apiKey, http.Client? httpClient})
      : _apiKey = apiKey ?? MapsConfig.apiKey,
        _httpClient = httpClient ?? http.Client();

  final String _apiKey;
  final http.Client _httpClient;

  static const _directionsBaseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';
  static const _placesBaseUrl =
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json';

  GoogleMapsServiceImpl._({
    required String apiKey,
    required http.Client httpClient,
  })  : _apiKey = apiKey,
        _httpClient = httpClient;

  /// Creates an instance with a custom HTTP client (useful for testing).
  factory GoogleMapsServiceImpl.withClient(
    http.Client httpClient, {
    String? apiKey,
  }) {
    return GoogleMapsServiceImpl._(
      apiKey: apiKey ?? MapsConfig.apiKey,
      httpClient: httpClient,
    );
  }

  @override
  Future<Route> getRoute(GeoLocation origin, GeoLocation destination) async {
    final uri = Uri.parse(_directionsBaseUrl).replace(queryParameters: {
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'key': _apiKey,
      'mode': 'driving',
      'language': 'ar',
    });

    final response = await _httpClient.get(uri);
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (data['status'] != 'OK') {
      throw MapsServiceException(
        'Directions API error: ${data['status']}',
      );
    }

    final routes = data['routes'] as List<dynamic>;
    if (routes.isEmpty) {
      throw const MapsServiceException('No route found');
    }

    final route = routes.first as Map<String, dynamic>;
    final legs = route['legs'] as List<dynamic>;
    final leg = legs.first as Map<String, dynamic>;

    final distance = (leg['distance'] as Map<String, dynamic>)['value'] as int;
    final duration = (leg['duration'] as Map<String, dynamic>)['value'] as int;
    final polyline =
        (route['overview_polyline'] as Map<String, dynamic>)['points'] as String;

    final steps = (leg['steps'] as List<dynamic>).map((step) {
      final s = step as Map<String, dynamic>;
      return RouteStep(
        instruction: _stripHtml(s['html_instructions'] as String),
        distanceMetres: ((s['distance'] as Map<String, dynamic>)['value'] as int).toDouble(),
        duration: Duration(seconds: (s['duration'] as Map<String, dynamic>)['value'] as int),
        startLocation: GeoLocation(
          latitude: (s['start_location'] as Map<String, dynamic>)['lat'] as double,
          longitude: (s['start_location'] as Map<String, dynamic>)['lng'] as double,
        ),
        endLocation: GeoLocation(
          latitude: (s['end_location'] as Map<String, dynamic>)['lat'] as double,
          longitude: (s['end_location'] as Map<String, dynamic>)['lng'] as double,
        ),
      );
    }).toList();

    return Route(
      distanceMetres: distance.toDouble(),
      duration: Duration(seconds: duration),
      steps: steps,
      polyline: polyline,
    );
  }

  @override
  Future<Duration> getETA(GeoLocation origin, GeoLocation destination) async {
    final uri = Uri.parse(_directionsBaseUrl).replace(queryParameters: {
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'key': _apiKey,
      'mode': 'driving',
    });

    final response = await _httpClient.get(uri);
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (data['status'] != 'OK') {
      throw MapsServiceException('Directions API error: ${data['status']}');
    }

    final routes = data['routes'] as List<dynamic>;
    if (routes.isEmpty) throw const MapsServiceException('No route found');

    final legs = (routes.first as Map<String, dynamic>)['legs'] as List<dynamic>;
    final durationValue =
        ((legs.first as Map<String, dynamic>)['duration'] as Map<String, dynamic>)['value'] as int;

    return Duration(seconds: durationValue);
  }

  @override
  Future<List<NearbyPlace>> searchNearby(
    GeoLocation location,
    String type,
    double radius,
  ) async {
    final uri = Uri.parse(_placesBaseUrl).replace(queryParameters: {
      'location': '${location.latitude},${location.longitude}',
      'radius': radius.toInt().toString(),
      'type': type,
      'key': _apiKey,
      'language': 'ar',
    });

    final response = await _httpClient.get(uri);
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') {
      throw MapsServiceException('Places API error: ${data['status']}');
    }

    final results = data['results'] as List<dynamic>? ?? [];
    return results.map((result) {
      final r = result as Map<String, dynamic>;
      final geo = (r['geometry'] as Map<String, dynamic>)['location']
          as Map<String, dynamic>;
      return NearbyPlace(
        id: r['place_id'] as String,
        name: r['name'] as String,
        location: GeoLocation(
          latitude: geo['lat'] as double,
          longitude: geo['lng'] as double,
        ),
        type: type,
        rating: r['rating'] as double?,
        isOpenNow: (r['opening_hours'] as Map<String, dynamic>?)?['open_now'] as bool?,
      );
    }).toList();
  }

  @override
  String getStaticMapImage(GeoLocation center, int zoom, String size) {
    final markers = 'color:red|${center.latitude},${center.longitude}';
    return 'https://maps.googleapis.com/maps/api/staticmap'
        '?center=${center.latitude},${center.longitude}'
        '&zoom=$zoom'
        '&size=$size'
        '&markers=$markers'
        '&key=$_apiKey';
  }

  @override
  void openNavigation(GeoLocation destination) {
    // Launches Google Maps navigation via URL scheme.
    // In production, use url_launcher package.
  }

  @override
  GeofenceStatus getGeofenceStatus(
    GeoLocation location, {
    required GeoLocation geofenceCenter,
    required double geofenceRadiusMetres,
  }) {
    final distance = _haversineDistance(
      location.latitude,
      location.longitude,
      geofenceCenter.latitude,
      geofenceCenter.longitude,
    );

    const buffer = 10.0;
    if (distance < geofenceRadiusMetres - buffer) {
      return GeofenceStatus.inside;
    } else if (distance > geofenceRadiusMetres + buffer) {
      return GeofenceStatus.outside;
    }
    return GeofenceStatus.onBoundary;
  }

  double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }
}

/// Exception thrown by [GoogleMapsServiceImpl].
class MapsServiceException implements Exception {
  /// Creates a [MapsServiceException].
  const MapsServiceException(this.message);

  /// The error message.
  final String message;

  @override
  String toString() => 'MapsServiceException: $message';
}
