import 'dart:async';
import 'dart:math';
import 'package:delwaqty/features/commerce/domain/entities/geo_location.dart';
import 'package:delwaqty/services/location/location_service.dart';

/// Mock implementation of [LocationService] for development.
///
/// Returns fake Riyadh coordinates and streams periodic updates
/// centred around the same location with slight jitter.
class LocationServiceImpl implements LocationService {
  /// Default Riyadh centre coordinates used as the fake location.
  static const GeoLocation _defaultRiyadh = GeoLocation(
    latitude: 24.7136,
    longitude: 46.6753,
    address: 'King Fahd Road',
    city: 'Riyadh',
    district: 'Al Olaya',
  );

  final _rng = Random(42);
  final _controller = StreamController<GeoLocation>.broadcast();
  Timer? _timer;

  @override
  Future<GeoLocation> getCurrentLocation() async {
    return _defaultRiyadh;
  }

  @override
  Stream<GeoLocation> streamLocationUpdates() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _controller.add(
        GeoLocation(
          latitude: _defaultRiyadh.latitude + _rng.nextDouble() * 0.001,
          longitude: _defaultRiyadh.longitude + _rng.nextDouble() * 0.001,
          address: _defaultRiyadh.address,
          city: _defaultRiyadh.city,
          district: _defaultRiyadh.district,
        ),
      );
    });
    return _controller.stream;
  }

  @override
  double calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadius = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) *
            sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  @override
  Duration calculateETA(double distance) {
    const averageSpeedKmh = 30.0;
    final distanceKm = distance / 1000.0;
    final hours = distanceKm / averageSpeedKmh;
    return Duration(seconds: (hours * 3600).round());
  }

  @override
  Future<PermissionStatus> checkPermission() async {
    return PermissionStatus.granted;
  }

  @override
  Future<PermissionStatus> requestPermission() async {
    return PermissionStatus.granted;
  }

  double _toRad(double deg) => deg * pi / 180.0;

  /// Releases resources held by this service.
  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
