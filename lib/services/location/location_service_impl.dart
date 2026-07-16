import 'dart:async';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:delwaqty/features/commerce/domain/entities/geo_location.dart';
import 'package:delwaqty/services/location/location_service.dart';

class LocationServiceImpl implements LocationService {
  final _controller = StreamController<GeoLocation>.broadcast();
  StreamSubscription<geo.Position>? _positionSubscription;

  @override
  Future<GeoLocation> getCurrentLocation() async {
    final position = await geo.Geolocator.getCurrentPosition(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
    return GeoLocation(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  @override
  Stream<GeoLocation> streamLocationUpdates() {
    _positionSubscription?.cancel();
    _positionSubscription = geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      (position) {
        _controller.add(
          GeoLocation(
            latitude: position.latitude,
            longitude: position.longitude,
          ),
        );
      },
      onError: (e) {
        _controller.addError(e);
      },
    );
    return _controller.stream;
  }

  @override
  double calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    return geo.Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
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
    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    return _mapPermission(permission);
  }

  @override
  Future<PermissionStatus> requestPermission() async {
    geo.LocationPermission permission = await geo.Geolocator.requestPermission();
    return _mapPermission(permission);
  }

  PermissionStatus _mapPermission(geo.LocationPermission permission) {
    return switch (permission) {
      geo.LocationPermission.always ||
      geo.LocationPermission.whileInUse =>
        PermissionStatus.granted,
      geo.LocationPermission.denied => PermissionStatus.denied,
      geo.LocationPermission.deniedForever => PermissionStatus.deniedForever,
      geo.LocationPermission.unableToDetermine => PermissionStatus.unknown,
    };
  }

  Future<bool> isLocationServiceEnabled() {
    return geo.Geolocator.isLocationServiceEnabled();
  }

  void dispose() {
    _positionSubscription?.cancel();
    _controller.close();
  }
}
