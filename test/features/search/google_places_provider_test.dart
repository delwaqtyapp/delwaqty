import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:delwaqty/features/search/data/providers/google_places_provider.dart';
import 'package:delwaqty/features/search/domain/entities/geo_point.dart';
import 'package:delwaqty/features/search/domain/entities/search_session.dart';
import 'package:delwaqty/features/search/domain/geocoding_provider.dart';

http.Response _json(Map<String, dynamic> body) =>
    http.Response(json.encode(body), 200);

void main() {
  group('GooglePlacesProvider.autocomplete', () {
    test('parses predictions and forwards session token + key', () async {
      Uri? captured;
      final client = MockClient((req) async {
        captured = req.url;
        return _json({
          'status': 'OK',
          'predictions': [
            {
              'place_id': 'abc',
              'structured_formatting': {
                'main_text': 'Cairo Tower',
                'secondary_text': 'Gezira, Cairo',
              },
              'types': ['tourist_attraction'],
              'distance_meters': 1200,
            },
          ],
        });
      });
      final provider =
          GooglePlacesProvider(apiKey: 'KEY', client: client);
      final results = await provider.autocomplete(
        query: 'cairo',
        languageCode: 'ar',
        origin: const GeoPoint(30.0, 31.0),
        session: const SearchSession('tok-1'),
      );
      expect(results, hasLength(1));
      expect(results.first.placeId, 'abc');
      expect(results.first.primaryText, 'Cairo Tower');
      expect(results.first.secondaryText, 'Gezira, Cairo');
      expect(results.first.distanceMeters, 1200);
      expect(captured!.queryParameters['sessiontoken'], 'tok-1');
      expect(captured!.queryParameters['key'], 'KEY');
      expect(captured!.queryParameters['language'], 'ar');
      expect(captured!.queryParameters['components'], 'country:eg');
    });

    test('empty query returns empty without a request', () async {
      var called = false;
      final client = MockClient((req) async {
        called = true;
        return _json({'status': 'OK', 'predictions': []});
      });
      final provider = GooglePlacesProvider(apiKey: 'KEY', client: client);
      final results = await provider.autocomplete(
          query: '   ', languageCode: 'en');
      expect(results, isEmpty);
      expect(called, isFalse);
    });

    test('OVER_QUERY_LIMIT maps to rateLimited', () async {
      final client = MockClient((req) async =>
          _json({'status': 'OVER_QUERY_LIMIT', 'predictions': []}));
      final provider = GooglePlacesProvider(apiKey: 'KEY', client: client);
      expect(
        () => provider.autocomplete(query: 'x', languageCode: 'en'),
        throwsA(isA<GeocodingException>().having(
            (e) => e.kind, 'kind', GeocodingErrorKind.rateLimited)),
      );
    });

    test('REQUEST_DENIED maps to denied', () async {
      final client = MockClient((req) async => _json(
          {'status': 'REQUEST_DENIED', 'error_message': 'bad key'}));
      final provider = GooglePlacesProvider(apiKey: 'KEY', client: client);
      expect(
        () => provider.autocomplete(query: 'x', languageCode: 'en'),
        throwsA(isA<GeocodingException>().having(
            (e) => e.kind, 'kind', GeocodingErrorKind.denied)),
      );
    });

    test('empty api key throws denied without a request', () async {
      var called = false;
      final client = MockClient((req) async {
        called = true;
        return _json({'status': 'OK', 'predictions': []});
      });
      final provider = GooglePlacesProvider(apiKey: '', client: client);
      expect(
        () => provider.autocomplete(query: 'x', languageCode: 'en'),
        throwsA(isA<GeocodingException>().having(
            (e) => e.kind, 'kind', GeocodingErrorKind.denied)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(called, isFalse);
    });
  });

  group('GooglePlacesProvider.details', () {
    test('parses place details location', () async {
      final client = MockClient((req) async => _json({
            'status': 'OK',
            'result': {
              'place_id': 'p1',
              'name': 'Home',
              'formatted_address': 'Nasr City, Cairo',
              'geometry': {
                'location': {'lat': 30.05, 'lng': 31.34},
              },
              'types': ['premise'],
            },
          }));
      final provider = GooglePlacesProvider(apiKey: 'KEY', client: client);
      final details = await provider.details(
          placeId: 'p1', languageCode: 'en');
      expect(details.name, 'Home');
      expect(details.formattedAddress, 'Nasr City, Cairo');
      expect(details.location, const GeoPoint(30.05, 31.34));
    });
  });

  group('GooglePlacesProvider.reverseGeocode', () {
    test('returns null on zero results', () async {
      final client = MockClient((req) async =>
          _json({'status': 'ZERO_RESULTS', 'results': []}));
      final provider = GooglePlacesProvider(apiKey: 'KEY', client: client);
      final result = await provider.reverseGeocode(
          point: const GeoPoint(0, 0), languageCode: 'en');
      expect(result, isNull);
    });
  });
}
