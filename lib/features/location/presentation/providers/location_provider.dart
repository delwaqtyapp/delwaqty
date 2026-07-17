import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:delwaqty/services/logger/app_logger.dart';

class UserLocation {
  const UserLocation({
    required this.latitude,
    required this.longitude,
    required this.detailedAddress,
  });

  final double latitude;
  final double longitude;
  final String detailedAddress;
}

final userLocationProvider =
    AsyncNotifierProvider<UserLocationNotifier, UserLocation?>(
  UserLocationNotifier.new,
);

class UserLocationNotifier extends AsyncNotifier<UserLocation?> {
  @override
  Future<UserLocation?> build() async {
    return _determinePosition();
  }

  Future<UserLocation?> _determinePosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final detailedAddress = await _reverseGeocode(
        position.latitude,
        position.longitude,
      );

      return UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        detailedAddress: detailedAddress,
      );
    } catch (e) {
      ref.read(loggerProvider).e('Failed to get location', e);
      return null;
    }
  }

  Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'Delwaqty/1.0'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          final parts = <String>[];
          final neighbourhood = address['neighbourhood'] as String? ??
              address['suburb'] as String? ??
              address['residential'] as String? ??
              address['quarter'] as String?;
          final city = address['city'] as String? ??
              address['town'] as String? ??
              address['village'] as String? ??
              address['state'] as String?;
          if (neighbourhood != null) parts.add(neighbourhood);
          if (city != null && city != neighbourhood) parts.add(city);
          if (parts.isNotEmpty) return parts.join(', ');
          return address['country'] as String? ?? '';
        }
      }
    } catch (_) {}
    return '';
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_determinePosition);
  }
}
