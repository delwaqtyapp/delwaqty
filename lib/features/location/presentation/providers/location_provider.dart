import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:delwaqty/config/app_config.dart';
import 'package:delwaqty/core/localization/locale_provider.dart';
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
      final apiKey = AppConfig.mapsApiKey;
      if (apiKey.isEmpty) return '';

      final lang = ref.read(localeProvider).languageCode;
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=$lat,$lng&key=$apiKey&language=$lang',
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>?;
        if (results != null && results.isNotEmpty) {
          final first = results.first as Map<String, dynamic>;
          final formattedAddress =
              first['formatted_address'] as String?;
          if (formattedAddress != null && formattedAddress.isNotEmpty) {
            return formattedAddress;
          }
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
