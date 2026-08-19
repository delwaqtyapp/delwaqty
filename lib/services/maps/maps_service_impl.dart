import 'dart:async';
import 'dart:convert';
import 'package:delwaqty/features/commerce/domain/entities/geo_location.dart';
import 'package:delwaqty/services/maps/maps_service.dart';
import 'package:http/http.dart' as http;

const _googleMapsApiKey = 'AIzaSyA9v-pk50aB3G45zIb_RQKxD5qo_CVX8GY';
const _directionsApiUrl = 'https://maps.googleapis.com/maps/api/directions/json';
const _placesApiUrl = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json';
const _geocodingApiUrl = 'https://maps.googleapis.com/maps/api/geocode/json';
const _staticMapBaseUrl = 'https://maps.googleapis.com/maps/api/staticmap';

class MapsServiceImpl implements MapsService {
  late final http.Client _client;

  MapsServiceImpl() {
    _client = http.Client();
  }

  @override
  Future<Route> getRoute(GeoLocation origin, GeoLocation destination) async {
    final response = await _client.get(
      Uri.parse(_directionsApiUrl)
          .replace(queryParameters: {
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'key': _googleMapsApiKey,
        'mode': 'driving',
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch route: ${response.body}');
    }

    final data = json.decode(response.body);
    if (data['status'] != 'OK' || data['routes'].isEmpty) {
      throw Exception('No route found: ${data['status']}');
    }

    final route = data['routes'][0];
    final polyline = route['overview_polyline']['points'];
    final totalDuration = Duration(
      minutes: _parseInt(data['routes'][0]['legs'][0]['duration']['value'] ?? 0),
    );
    final totalDistance = _parseDouble(data['routes'][0]['legs'][0]['distance']['value'] ?? 0);

    final steps = <RouteStep>[];
    for (final step in route['legs'][0]['steps']) {
      steps.add(RouteStep(
        instruction: step['html_instructions'].replaceAll('<[^>]+>', ''),
        distanceMetres: _parseDouble(step['distance']['value']),
        duration: Duration(
          minutes: _parseInt(step['duration']['value']),
        ),
        startLocation: GeoLocation(
          latitude: _parseDouble(step['start_location']['lat']),
          longitude: _parseDouble(step['start_location']['lng']),
        ),
        endLocation: GeoLocation(
          latitude: _parseDouble(step['end_location']['lat']),
          longitude: _parseDouble(step['end_location']['lng']),
        ),
      ));
    }

    return Route(
      distanceMetres: totalDistance,
      duration: totalDuration,
      steps: steps,
      polyline: polyline,
    );
  }

  @override
  Future<Duration> getETA(GeoLocation origin, GeoLocation destination) async {
    final response = await _client.get(
      Uri.parse(_directionsApiUrl)
          .replace(queryParameters: {
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'key': _googleMapsApiKey,
        'mode': 'driving',
        'alternatives': 'false',
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch ETA: ${response.body}');
    }

    final data = json.decode(response.body);
    if (data['status'] != 'OK' || data['routes'].isEmpty) {
      throw Exception('No route found for ETA: ${data['status']}');
    }

    return Duration(
      minutes: _parseInt(data['routes'][0]['legs'][0]['duration']['value'] ?? 0),
    );
  }

  @override
  Future<List<NearbyPlace>> searchNearby(
    GeoLocation location,
    String type,
    double radius,
  ) async {
    final response = await _client.get(
      Uri.parse(_placesApiUrl)
          .replace(queryParameters: {
        'location': '${location.latitude},${location.longitude}',
        'radius': radius.toString(),
        'type': type,
        'key': _googleMapsApiKey,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to search nearby: ${response.body}');
    }

    final data = json.decode(response.body);
    if (data['status'] != 'OK') {
      return [];
    }

    final places = <NearbyPlace>[];
    for (final result in data['results']) {
      final geometry = result['geometry']['location'];
      places.add(NearbyPlace(
        id: result['place_id'],
        name: result['name'],
        location: GeoLocation(
          latitude: geometry['lat'],
          longitude: geometry['lng'],
        ),
        type: result['types'].firstWhere(
              (t) => t != 'establishment',
              orElse: () => result['types'].firstOrNull ?? '',
            ) ||
            '',
        rating: _parseDouble(result['rating']),
        distanceMetres: _parseDouble(result['icon']),
        isOpenNow: result['opening_hours']?.get('open_now') ?? false,
      ));
    }

    return places;
  }

  @override
  String getStaticMapImage(GeoLocation center, int zoom, String size) {
    return '$_staticMapBaseUrl'
        '?center=${center.latitude},${center.longitude}'
        '&zoom=$zoom'
        '&size=$size'
        '&maptype=roadmap'
        '&key=$_googleMapsApiKey';
  }

  @override
  void openNavigation(GeoLocation destination) {
    final url = 'https://www.google.com/maps/dir/?api=1'
        '&destination=${destination.latitude},${destination.longitude}';
    // In a real app, use url_launcher to open this URL
    // For now, we log it
    debugPrint('Opening navigation: $url');
  }

  @override
  GeofenceStatus getGeofenceStatus(
    GeoLocation location, {
    required GeoLocation geofenceCenter,
    required double geofenceRadiusMetres,
  }) {
    final distance = _calculateDistance(
      location.latitude,
      location.longitude,
      geofenceCenter.latitude,
      geofenceCenter.longitude,
    );

    if (distance <= geofenceRadiusMetres) {
      return GeofenceStatus.inside;
    } else if (distance >= geofenceRadiusMetres * 1.2) {
      return GeofenceStatus.outside;
    }
    return GeofenceStatus.onBoundary;
  }

  double _calculateDistance(
      lat1, lon1, lat2, lon2) {
    // Haversine formula
    const r = 6371e3; // Earth radius in metres
    final dLat = (lat2 - lat1) * 3.14159 / 180;
    final dLon = (lon2 - lon1) * 3.14159 / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * 3.14159 / 180) * cos(lat2 * 3.14159 / 180) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * asin(sqrt(a));
    return r * c;
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.parse(value.toString());
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    return double.parse(value.toString());
  }

  @mustBeOverridden
  @override
  void dispose() {
    _client.dispose();
  }
}