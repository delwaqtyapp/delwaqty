import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delwaqty/config/app_config.dart';
import 'package:delwaqty/services/logger/app_logger.dart';

class UserLocation {
  const UserLocation({
    required this.latitude,
    required this.longitude,
    required this.detailedAddress,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final String detailedAddress;
  final double? accuracyMeters;
}

final userLocationProvider =
    AsyncNotifierProvider<UserLocationNotifier, UserLocation?>(
      UserLocationNotifier.new,
    );

const double precisionTargetMeters = 1.0;

const String _androidCertSha1 =
    '5337185A52F0B615A3388ECC03B6576D61F34EEF';

class UserLocationNotifier extends AsyncNotifier<UserLocation?> {
  @override
  Future<UserLocation?> build() async {
    return _determinePosition(deepPrecision: false);
  }

  Future<UserLocation?> refreshDeep() {
    return _determinePosition(deepPrecision: true);
  }

  Future<UserLocation?> refreshQuick() {
    return _determinePosition(deepPrecision: false);
  }

  Future<UserLocation?> refreshDeepLocked() async {
    UserLocation? best;
    for (var attempt = 0; attempt < 3; attempt++) {
      final value = await _determinePosition(deepPrecision: true);
      if (value == null) return null;
      final accuracy = value.accuracyMeters;
      if (best == null ||
          (accuracy != null &&
              accuracy > 0 &&
              (best.accuracyMeters == null ||
                  best.accuracyMeters! <= 0 ||
                  accuracy < best.accuracyMeters!))) {
        best = value;
      }
      if (accuracy != null && accuracy > 0 && accuracy <= precisionTargetMeters) {
        return value;
      }
    }
    return best;
  }

  Future<UserLocation?> _determinePosition({bool deepPrecision = false}) async {
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

      final position = await _bestAvailablePosition(
        deepPrecision: deepPrecision,
      );
      if (position == null) {
        return null;
      }

      final detailedAddress = await _reverseGeocode(
        position.latitude,
        position.longitude,
      );

      return UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        detailedAddress: detailedAddress,
        accuracyMeters: position.accuracy > 0 ? position.accuracy : null,
      );
    } catch (e) {
      ref.read(loggerProvider).e('Failed to get location', e);
      return null;
    }
  }

  static const _maxFixAge = Duration(minutes: 2);
  static const _maxLastKnownAge = Duration(minutes: 10);

  Future<Position?> _bestAvailablePosition({bool deepPrecision = false}) async {
    final lastKnown = await _safeGetLastKnown();
    if (_isFreshAndPrecise(lastKnown)) return lastKnown;

    if (!deepPrecision && _isUsableLastKnown(lastKnown)) {
      return lastKnown;
    }

    final waitSeconds = deepPrecision && !_isUsableLastKnown(lastKnown)
        ? 45
        : 12;
    final precise = await _acquirePreciseFix(
      deepPrecision: deepPrecision,
      waitSeconds: waitSeconds,
    );
    if (precise != null) return precise;

    if (_isUsableLastKnown(lastKnown)) return lastKnown;
    return null;
  }

  bool _isFreshTimestamp(DateTime timestamp) {
    final age = DateTime.now().difference(timestamp).inMilliseconds;
    return age >= -30000 && age <= _maxFixAge.inMilliseconds;
  }

  bool _isFresh(Position? position) =>
      position != null && _isFreshTimestamp(position.timestamp);

  bool _hasLiveGnss(Position position) =>
      position is! AndroidPosition || position.satellitesUsedInFix > 0;

  bool _isFreshAndVerified(Position? position) =>
      _isFresh(position) && _hasLiveGnss(position!);

  bool _isFreshAndPrecise(Position? position) {
    if (!_isFreshAndVerified(position)) return false;
    final accuracy = position!.accuracy;
    return accuracy > 0 && accuracy <= 1;
  }

  bool _isUsableLastKnown(Position? position) {
    if (position == null) return false;
    final age = DateTime.now().difference(position.timestamp).inMilliseconds;
    if (age < -30000 || age > _maxLastKnownAge.inMilliseconds) return false;
    if (_hasLiveGnss(position)) return true;
    return position.accuracy > 0 && position.accuracy <= 500;
  }

  Future<Position?> _acquirePreciseFix({
    bool deepPrecision = false,
    int? waitSeconds,
  }) async {
    final completer = Completer<Position?>();
    Position? best;
    StreamSubscription<Position>? subscription;
    final timeout = waitSeconds ?? (deepPrecision ? 45 : 12);
    final targetMeters = deepPrecision ? 1.0 : 10.0;
    final timer = Timer(Duration(seconds: timeout), () {
      subscription?.cancel();
      if (!completer.isCompleted) completer.complete(best);
    });
    try {
      subscription =
          Geolocator.getPositionStream(
            locationSettings: LocationSettings(
              accuracy: deepPrecision
                  ? LocationAccuracy.bestForNavigation
                  : LocationAccuracy.best,
              timeLimit: Duration(seconds: timeout),
            ),
          ).listen(
            (position) {
              if (!_isFreshTimestamp(position.timestamp)) return;
              final accuracy = position.accuracy;
              if (best == null ||
                  (accuracy > 0 &&
                      (best!.accuracy <= 0 || accuracy < best!.accuracy))) {
                best = position;
              }
              if (_hasLiveGnss(position) &&
                  accuracy > 0 &&
                  accuracy <= targetMeters) {
                timer.cancel();
                subscription?.cancel();
                if (!completer.isCompleted) completer.complete(position);
              }
            },
            onError: (_) {
              timer.cancel();
              if (!completer.isCompleted) completer.complete(best);
            },
            onDone: () {
              timer.cancel();
              if (!completer.isCompleted) completer.complete(best);
            },
            cancelOnError: true,
          );
    } catch (_) {
      timer.cancel();
      if (!completer.isCompleted) completer.complete(best);
    }
    return completer.future;
  }

  Future<Position?> _safeGetLastKnown() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  static const _geocodeCacheKey = 'location_geocode_cache_v1';
  static const _geocodeCacheTtl = Duration(hours: 24);
  static const _geocodeCacheMaxEntries = 200;

  Future<Map<String, String>> _readGeocodeCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_geocodeCacheKey);
      if (raw == null) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      final now = DateTime.now().millisecondsSinceEpoch;
      final result = <String, String>{};
      decoded.forEach((key, value) {
        if (value is! Map<String, dynamic>) return;
        final address = value['a'];
        final timestamp = value['t'];
        if (address is String &&
            address.isNotEmpty &&
            timestamp is int &&
            now - timestamp < _geocodeCacheTtl.inMilliseconds) {
          result[key] = address;
        }
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeGeocodeCache(Map<String, String> cache) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      final entries = cache.entries.map(
        (e) => MapEntry(e.key, {'a': e.value, 't': now}),
      );
      final data = Map<String, dynamic>.fromEntries(
        entries.take(_geocodeCacheMaxEntries),
      );
      await prefs.setString(_geocodeCacheKey, jsonEncode(data));
    } catch (_) {}
  }

  Future<String> _reverseGeocode(double lat, double lng) async {
    final logger = ref.read(loggerProvider);

    final cacheKey = '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
    final cache = await _readGeocodeCache();
    final cached = cache[cacheKey];
    if (cached != null && cached.isNotEmpty) return cached;

    final results = await Future.wait([
      _googleStructuredAddress(lat, lng, logger),
      _photonStructuredAddress(lat, lng, logger),
      _nominatimStructuredAddress(lat, lng, logger),
      _nearestNamedPlace(lat, lng, logger),
    ]);

    final google = results[0] as ({String address, bool hasNamed})?;
    final photon = results[1] as ({String address, bool hasNamed})?;
    final osm = results[2] as ({String address, bool hasNamed})?;
    final nearestName = results[3] as String?;

    var address = '';
    var hasNamed = false;
    if (google != null && google.address.isNotEmpty) {
      address = google.address;
      hasNamed = google.hasNamed;
    } else if (photon != null && photon.address.isNotEmpty) {
      address = photon.address;
      hasNamed = photon.hasNamed;
    } else if (osm != null && osm.address.isNotEmpty) {
      address = osm.address;
      hasNamed = osm.hasNamed;
    }

    if (address.isEmpty) return '';

    if (!hasNamed && nearestName != null) {
      final firstPart = address.split(RegExp('[،,]')).first.trim();
      if (nearestName != firstPart) {
        address = '$nearestName، $address';
      }
    }

    final result = _cleanArabicAddress(address);
    if (result.isNotEmpty) {
      cache[cacheKey] = result;
      await _writeGeocodeCache(cache);
    }
    return result;
  }

  Future<({String address, bool hasNamed})?> _googleStructuredAddress(
    double lat,
    double lng,
    dynamic logger,
  ) async {
    try {
      const apiKey = AppConfig.mapsApiKey;
      if (apiKey.isEmpty) return null;

      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=$lat,$lng&key=$apiKey&language=ar',
      );
      final headers = <String, String>{};
      if (defaultTargetPlatform == TargetPlatform.android) {
        headers['X-Android-Package'] = 'com.delwaqty.app';
        headers['X-Android-Cert'] = _androidCertSha1;
      }
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      if ((data['status'] as String?) != 'OK') return null;

      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      final first = results.first as Map<String, dynamic>;
      final components = first['address_components'] as List<dynamic>?;
      if (components == null || components.isEmpty) return null;

      String? named;
      String? street;
      String? area;
      String? city;
      String? region;
      String? country;

      for (final raw in components) {
        final component = raw as Map<String, dynamic>;
        final name = component['long_name'] as String?;
        final types =
            (component['types'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            <String>[];
        if (name == null || name.trim().isEmpty) continue;
        final isNumeric = RegExp(r'\d').hasMatch(name);

        if (_typesContain(types, const [
          'establishment',
          'point_of_interest',
          'premise',
        ])) {
          if (!isNumeric && named == null) named = name;
        } else if (types.contains('route')) {
          street ??= name;
        } else if (_typesContain(types, const [
          'neighborhood',
          'sublocality_level_1',
          'sublocality_level_2',
        ])) {
          area ??= name;
        } else if (_typesContain(types, const ['locality', 'postal_town'])) {
          city ??= name;
        } else if (_typesContain(types, const [
          'administrative_area_level_1',
          'administrative_area_level_2',
        ])) {
          region ??= name;
        } else if (types.contains('country')) {
          country ??= name;
        }
      }

      final parts = <String>[
        if (named != null) named,
        if (street != null) street,
        if (area != null && area != street) area,
        if (city != null && city != area) city,
        if (region != null && region != city) region,
        if (country != null && country != region) country,
      ];

      return (address: parts.join('، '), hasNamed: named != null);
    } catch (e) {
      logger.d('Google structured geocoding error: $e');
      return null;
    }
  }

  Future<({String address, bool hasNamed})?> _nominatimStructuredAddress(
    double lat,
    double lng,
    dynamic logger,
  ) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1'
        '&accept-language=ar',
      );
      final response = await http
          .get(uri, headers: {'User-Agent': 'Delwaqty/1.0'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>?;
      if (address == null) return null;

      const namedKeys = [
        'amenity',
        'shop',
        'tourism',
        'leisure',
        'office',
        'craft',
        'building',
        'man_made',
        'house_name',
      ];
      String? named;
      for (final key in namedKeys) {
        final value = address[key] as String?;
        if (value != null &&
            value.trim().isNotEmpty &&
            !RegExp(r'\d').hasMatch(value)) {
          named = value;
          break;
        }
      }

      final road = address['road'] as String?;
      final area =
          address['neighbourhood'] as String? ??
          address['suburb'] as String? ??
          address['quarter'] as String? ??
          address['residential'] as String? ??
          address['city_district'] as String?;
      final city =
          address['city'] as String? ??
          address['town'] as String? ??
          address['village'] as String? ??
          address['hamlet'] as String? ??
          address['municipality'] as String?;
      final region =
          address['state'] as String? ??
          address['region'] as String? ??
          address['county'] as String?;
      final country = address['country'] as String?;

      final parts = <String>[
        if (named != null) named,
        if (road != null) road,
        if (area != null && area != road) area,
        if (city != null && city != area) city,
        if (region != null && region != city) region,
        if (country != null && country != region) country,
      ];

      if (parts.isEmpty) return null;

      return (address: parts.join('، '), hasNamed: named != null);
    } catch (e) {
      logger.d('Nominatim structured geocoding error: $e');
      return null;
    }
  }

  Future<({String address, bool hasNamed})?> _photonStructuredAddress(
    double lat,
    double lng,
    dynamic logger,
  ) async {
    try {
      final uri = Uri.parse(
        'https://photon.komoot.io/reverse?lon=$lng&lat=$lat',
      );
      final response = await http
          .get(uri, headers: {'User-Agent': 'Delwaqty/1.0'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final data =
          json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final features = data['features'] as List<dynamic>?;
      if (features == null || features.isEmpty) return null;

      final props =
          (features.first as Map<String, dynamic>)['properties']
              as Map<String, dynamic>?;
      if (props == null) return null;

      String part(String key) => (props[key]?.toString() ?? '').trim();

      final name = part('name');
      final street = part('street');
      final locality = part('locality');
      final district = part('district');
      final city = part('city');
      final state = part('state');
      final country = part('country');

      final hasNamed =
          name.isNotEmpty || locality.isNotEmpty || district.isNotEmpty;
      final parts = <String>[];
      final placePart = name.isNotEmpty
          ? name
          : (locality.isNotEmpty ? locality : district);
      if (placePart.isNotEmpty) parts.add(placePart);
      if (street.isNotEmpty && street != placePart) parts.add(street);
      if (city.isNotEmpty && city != placePart && city != street) {
        parts.add(city);
      }
      if (state.isNotEmpty && state != parts.lastOrNull) parts.add(state);
      if (country.isNotEmpty && country != parts.lastOrNull) {
        parts.add(country);
      }
      if (parts.isEmpty) return null;

      return (address: parts.join('، '), hasNamed: hasNamed);
    } catch (e) {
      logger.d('Photon reverse geocoding error: $e');
      return null;
    }
  }

  Future<String?> _nearestNamedPlace(
    double lat,
    double lng,
    dynamic logger,
  ) async {
    final query =
        '[out:json][timeout:15];'
        '(nwr["name"](around:4000,$lat,$lng););'
        'out tags center 80;';
    const mirrors = [
      'https://overpass-api.de/api/interpreter',
      'https://overpass.kumi.systems/api/interpreter',
      'https://overpass.private.coffee/api/interpreter',
    ];

    for (final mirror in mirrors) {
      try {
        final response = await http
            .post(
              Uri.parse(mirror),
              headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                'User-Agent': 'Delwaqty/1.0',
              },
              body: 'data=${Uri.encodeComponent(query)}',
            )
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) continue;

        final data = json.decode(response.body) as Map<String, dynamic>;
        final elements = data['elements'] as List<dynamic>?;
        if (elements == null || elements.isEmpty) continue;

        final candidates =
            <({double d2, String name, bool arabic, bool poi})>[];
        for (final element in elements) {
          final raw = element as Map<String, dynamic>;
          final tags = raw['tags'] as Map<String, dynamic>?;
          final name = tags?['name'] as String?;
          if (name == null || name.trim().isEmpty) continue;
          if (RegExp(r'\d').hasMatch(name)) continue;
          final center = _elementCenter(raw);
          if (center == null) continue;
          final d2 =
              (center.$1 - lat) * (center.$1 - lat) +
              (center.$2 - lng) * (center.$2 - lng);
          final poi =
              tags?.keys.any(
                (k) =>
                    k == 'amenity' ||
                    k == 'shop' ||
                    k == 'leisure' ||
                    k == 'tourism' ||
                    k == 'building' ||
                    k == 'office' ||
                    k == 'craft' ||
                    k == 'place' ||
                    k == 'landuse' ||
                    k == 'resort' ||
                    k == 'camp_site',
              ) ??
              false;
          candidates.add((
            d2: d2,
            name: name.trim(),
            arabic: RegExp(r'[\u0600-\u06FF]').hasMatch(name),
            poi: poi,
          ));
        }

        if (candidates.isEmpty) continue;
        candidates.sort((a, b) {
          if (a.poi != b.poi) return a.poi ? -1 : 1;
          if (a.arabic != b.arabic) return a.arabic ? -1 : 1;
          return a.d2.compareTo(b.d2);
        });
        return candidates.first.name;
      } catch (e) {
        logger.d('Overpass ($mirror) nearest-name error: $e');
      }
    }
    return null;
  }

  (double, double)? _elementCenter(Map<String, dynamic> element) {
    final lat = element['lat'];
    final lon = element['lon'];
    if (lat is num && lon is num) return (lat.toDouble(), lon.toDouble());
    final center = element['center'];
    if (center is Map<String, dynamic>) {
      final clat = center['lat'];
      final clon = center['lon'];
      if (clat is num && clon is num) return (clat.toDouble(), clon.toDouble());
    }
    return null;
  }

  bool _typesContain(List<String> types, List<String> wanted) =>
      types.any(wanted.contains);

  String _cleanArabicAddress(String input) {
    var cleaned = input.replaceAll(RegExp(r'\d'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'[()\[\]]'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s*([,.])\s*'), '، ');
    cleaned = cleaned.replaceAll(RegExp(r'(،\s*)+'), '، ');
    cleaned = cleaned.replaceAll(RegExp(r'^[،,\s]+|[،,\s]+$'), '');
    return cleaned;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_determinePosition);
  }
}
