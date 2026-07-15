import 'dart:async';
import 'package:delwaqty/features/commerce/domain/entities/geo_location.dart';

/// Permission status for location services.
enum PermissionStatus {
  /// Permission has been granted.
  granted,

  /// Permission has been denied by the user.
  denied,

  /// Permission has been denied permanently; cannot request again.
  deniedForever,

  /// Permission status is currently unknown.
  unknown,
}

/// Abstract interface for location-based services.
///
/// Provides methods to obtain the device's current location, stream
/// continuous location updates, and compute distance/ETA helpers.
abstract interface class LocationService {
  /// Returns the device's current geographic location.
  Future<GeoLocation> getCurrentLocation();

  /// Emits a continuous stream of location updates as they become available.
  Stream<GeoLocation> streamLocationUpdates();

  /// Calculates the great-circle distance in metres between two coordinates
  /// using the Haversine formula.
  double calculateDistance(double lat1, double lng1, double lat2, double lng2);

  /// Estimates the travel time for the given [distance] in metres assuming
  /// average urban driving speed.
  Duration calculateETA(double distance);

  /// Returns the current location permission status without prompting the user.
  Future<PermissionStatus> checkPermission();

  /// Requests location permission from the user and returns the resulting status.
  Future<PermissionStatus> requestPermission();
}
