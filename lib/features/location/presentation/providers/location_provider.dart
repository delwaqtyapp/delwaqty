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
    final lang = ref.read(localeProvider).languageCode;
    final logger = ref.read(loggerProvider);

    final googleResult = await _googleReverseGeocode(lat, lng, lang, logger);
    if (googleResult != null) return googleResult;

    return await _nominatimReverseGeocode(lat, lng, logger);
  }

  Future<String?> _googleReverseGeocode(
    double lat,
    double lng,
    String lang,
    dynamic logger,
  ) async {
    try {
      final apiKey = AppConfig.mapsApiKey;
      if (apiKey.isEmpty) return null;

      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=$lat,$lng&key=$apiKey&language=$lang',
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final status = data['status'] as String?;
        if (status != 'OK') {
          logger.d('Google Geocoding status: $status');
          return null;
        }
        final results = data['results'] as List<dynamic>?;
        if (results != null && results.isNotEmpty) {
          final first = results.first as Map<String, dynamic>;
          final formattedAddress = first['formatted_address'] as String?;
          if (formattedAddress != null && formattedAddress.isNotEmpty) {
            return formattedAddress;
          }
        }
      }
    } catch (e) {
      logger.d('Google Geocoding error: $e');
    }
    return null;
  }

  Future<String> _nominatimReverseGeocode(
    double lat,
    double lng,
    dynamic logger,
  ) async {
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
        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          return displayName;
        }
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          final parts = <String>[];
          final road = address['road'] as String?;
          final neighbourhood = address['neighbourhood'] as String? ??
              address['suburb'] as String? ??
              address['residential'] as String? ??
              address['quarter'] as String?;
          final city = address['city'] as String? ??
              address['town'] as String? ??
              address['village'] as String?;
          final state = address['state'] as String?;
          final country = address['country'] as String?;
          if (road != null) parts.add(road);
          if (neighbourhood != null && neighbourhood != road) {
            parts.add(neighbourhood);
          }
          if (city != null && city != neighbourhood) parts.add(city);
          if (state != null && state != city) parts.add(state);
          if (country != null) parts.add(country);
          if (parts.isNotEmpty) return parts.join(', ');
          return address['country'] as String? ?? '';
        }
      }
    } catch (e) {
      logger.d('Nominatim Geocoding error: $e');
    }
    return '';
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_determinePosition);
  }
}
