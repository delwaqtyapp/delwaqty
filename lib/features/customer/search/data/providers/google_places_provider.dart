import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:delwaqty/features/customer/search/domain/entities/geo_point.dart';
import 'package:delwaqty/features/customer/search/domain/entities/place_details.dart';
import 'package:delwaqty/features/customer/search/domain/entities/place_suggestion.dart';
import 'package:delwaqty/features/customer/search/domain/entities/search_session.dart';
import 'package:delwaqty/features/customer/search/domain/geocoding_provider.dart';

class GooglePlacesProvider implements GeocodingProvider {
  GooglePlacesProvider({
    required String apiKey,
    http.Client? client,
    this.regionCode = 'eg',
  })  : _apiKey = apiKey,
        _client = client ?? http.Client();

  final String _apiKey;
  final http.Client _client;
  final String regionCode;

  static const _base = 'maps.googleapis.com';

  @override
  String get id => 'google_places';

  @override
  bool get usesSessionTokens => true;

  @override
  Future<List<PlaceSuggestion>> autocomplete({
    required String query,
    required String languageCode,
    GeoPoint? origin,
    SearchSession? session,
  }) async {
    if (query.trim().isEmpty) return [];
    final params = <String, String>{
      'input': query,
      'language': languageCode,
      'components': 'country:$regionCode',
      'key': _apiKey,
    };
    if (session != null) params['sessiontoken'] = session.token;
    if (origin != null) {
      params['location'] = '${origin.latitude},${origin.longitude}';
      params['radius'] = '50000';
      params['origin'] = '${origin.latitude},${origin.longitude}';
    }
    final data = await _get('/maps/api/place/autocomplete/json', params);
    final predictions = (data['predictions'] as List?) ?? const [];
    return predictions.map((p) {
      final m = p as Map<String, dynamic>;
      final structured =
          m['structured_formatting'] as Map<String, dynamic>? ?? const {};
      return PlaceSuggestion(
        placeId: m['place_id'] as String? ?? '',
        primaryText: structured['main_text'] as String? ??
            m['description'] as String? ??
            '',
        secondaryText: structured['secondary_text'] as String? ?? '',
        distanceMeters: (m['distance_meters'] as num?)?.toInt(),
        types: ((m['types'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
    }).where((s) => s.placeId.isNotEmpty).toList();
  }

  @override
  Future<PlaceDetails> details({
    required String placeId,
    required String languageCode,
    SearchSession? session,
  }) async {
    final params = <String, String>{
      'place_id': placeId,
      'language': languageCode,
      'fields': 'place_id,name,formatted_address,geometry,type',
      'key': _apiKey,
    };
    if (session != null) params['sessiontoken'] = session.token;
    final data = await _get('/maps/api/place/details/json', params);
    final result = data['result'] as Map<String, dynamic>?;
    if (result == null) {
      throw const GeocodingException(GeocodingErrorKind.notFound);
    }
    return _detailsFromResult(result);
  }

  @override
  Future<PlaceDetails?> reverseGeocode({
    required GeoPoint point,
    required String languageCode,
  }) async {
    final params = <String, String>{
      'latlng': '${point.latitude},${point.longitude}',
      'language': languageCode,
      'key': _apiKey,
    };
    final data = await _get('/maps/api/geocode/json', params);
    final results = (data['results'] as List?) ?? const [];
    if (results.isEmpty) return null;
    final first = results.first as Map<String, dynamic>;
    final geometry = first['geometry'] as Map<String, dynamic>?;
    final loc = geometry?['location'] as Map<String, dynamic>?;
    return PlaceDetails(
      placeId: first['place_id'] as String? ?? '',
      name: first['formatted_address'] as String? ?? '',
      formattedAddress: first['formatted_address'] as String? ?? '',
      location: loc != null
          ? GeoPoint((loc['lat'] as num).toDouble(),
              (loc['lng'] as num).toDouble())
          : point,
      types: ((first['types'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  @override
  Future<List<PlaceDetails>> nearbySearch({
    required GeoPoint point,
    required String languageCode,
    String? keyword,
    int radiusMeters = 1500,
  }) async {
    final params = <String, String>{
      'location': '${point.latitude},${point.longitude}',
      'radius': '$radiusMeters',
      'language': languageCode,
      'key': _apiKey,
    };
    if (keyword != null && keyword.trim().isNotEmpty) {
      params['keyword'] = keyword;
    }
    final data = await _get('/maps/api/place/nearbysearch/json', params);
    final results = (data['results'] as List?) ?? const [];
    return results.map((r) => _detailsFromResult(r as Map<String, dynamic>)).toList();
  }

  PlaceDetails _detailsFromResult(Map<String, dynamic> result) {
    final geometry = result['geometry'] as Map<String, dynamic>?;
    final loc = geometry?['location'] as Map<String, dynamic>?;
    return PlaceDetails(
      placeId: result['place_id'] as String? ?? '',
      name: result['name'] as String? ??
          result['formatted_address'] as String? ??
          '',
      formattedAddress: result['formatted_address'] as String? ??
          result['vicinity'] as String? ??
          '',
      location: loc != null
          ? GeoPoint((loc['lat'] as num).toDouble(),
              (loc['lng'] as num).toDouble())
          : const GeoPoint(0, 0),
      types: ((result['types'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> params,
  ) async {
    if (_apiKey.isEmpty) {
      throw const GeocodingException(
          GeocodingErrorKind.denied, 'Missing Maps API key');
    }
    final uri = Uri.https(_base, path, params);
    http.Response response;
    try {
      response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 10));
    } on Exception catch (e) {
      throw GeocodingException(GeocodingErrorKind.network, e.toString());
    }
    if (response.statusCode == 429) {
      throw const GeocodingException(GeocodingErrorKind.rateLimited);
    }
    if (response.statusCode != 200) {
      throw GeocodingException(
          GeocodingErrorKind.network, 'HTTP ${response.statusCode}');
    }
    final body = json.decode(response.body) as Map<String, dynamic>;
    final status = body['status'] as String? ?? 'UNKNOWN_ERROR';
    switch (status) {
      case 'OK':
      case 'ZERO_RESULTS':
        return body;
      case 'OVER_QUERY_LIMIT':
        throw const GeocodingException(GeocodingErrorKind.rateLimited);
      case 'REQUEST_DENIED':
        throw GeocodingException(
            GeocodingErrorKind.denied, body['error_message'] as String?);
      case 'NOT_FOUND':
        throw const GeocodingException(GeocodingErrorKind.notFound);
      default:
        throw GeocodingException(
            GeocodingErrorKind.unknown, body['error_message'] as String?);
    }
  }
}
