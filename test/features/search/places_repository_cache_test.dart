import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:delwaqty/features/customer/search/data/datasources/local/recent_searches_store.dart';
import 'package:delwaqty/features/customer/search/data/datasources/remote/supabase_saved_places_data_source.dart';
import 'package:delwaqty/features/customer/search/data/repositories/places_repository_impl.dart';
import 'package:delwaqty/features/customer/search/domain/entities/geo_point.dart';
import 'package:delwaqty/features/customer/search/domain/entities/place_details.dart';
import 'package:delwaqty/features/customer/search/domain/entities/place_suggestion.dart';
import 'package:delwaqty/features/customer/search/domain/entities/search_session.dart';
import 'package:delwaqty/features/customer/search/domain/geocoding_provider.dart';

class _MockSavedPlaces extends Mock implements SupabaseSavedPlacesDataSource {}

class _MockRecentStore extends Mock implements RecentSearchesStore {}

class _CountingProvider implements GeocodingProvider {
  int autocompleteCalls = 0;
  int detailsCalls = 0;
  int reverseCalls = 0;

  @override
  String get id => 'counting';

  @override
  bool get usesSessionTokens => true;

  @override
  Future<List<PlaceSuggestion>> autocomplete({
    required String query,
    required String languageCode,
    GeoPoint? origin,
    SearchSession? session,
  }) async {
    autocompleteCalls++;
    return const [
      PlaceSuggestion(placeId: 'p', primaryText: 'A', secondaryText: 'B'),
    ];
  }

  @override
  Future<PlaceDetails> details({
    required String placeId,
    required String languageCode,
    SearchSession? session,
  }) async {
    detailsCalls++;
    return const PlaceDetails(
      placeId: 'p',
      name: 'A',
      formattedAddress: 'B',
      location: GeoPoint(1, 2),
    );
  }

  @override
  Future<PlaceDetails?> reverseGeocode({
    required GeoPoint point,
    required String languageCode,
  }) async {
    reverseCalls++;
    return const PlaceDetails(
      placeId: 'r',
      name: 'Rev',
      formattedAddress: 'Addr',
      location: GeoPoint(1, 2),
    );
  }

  @override
  Future<List<PlaceDetails>> nearbySearch({
    required GeoPoint point,
    required String languageCode,
    String? keyword,
    int radiusMeters = 1500,
  }) async =>
      const [];
}

void main() {
  late _CountingProvider provider;
  late PlacesRepositoryImpl repo;
  const session = SearchSession('s');

  setUp(() {
    provider = _CountingProvider();
    repo = PlacesRepositoryImpl(
      provider: provider,
      savedPlaces: _MockSavedPlaces(),
      recentSearches: _MockRecentStore(),
    );
  });

  test('autocomplete caches identical queries', () async {
    await repo.autocomplete(query: 'cairo', languageCode: 'en', session: session);
    await repo.autocomplete(query: 'cairo', languageCode: 'en', session: session);
    expect(provider.autocompleteCalls, 1);
  });

  test('autocomplete does not cache across languages', () async {
    await repo.autocomplete(query: 'cairo', languageCode: 'en', session: session);
    await repo.autocomplete(query: 'cairo', languageCode: 'ar', session: session);
    expect(provider.autocompleteCalls, 2);
  });

  test('empty query short-circuits without provider call', () async {
    final r = await repo.autocomplete(
        query: '  ', languageCode: 'en', session: session);
    expect(r, isEmpty);
    expect(provider.autocompleteCalls, 0);
  });

  test('details caches by placeId', () async {
    await repo.details(placeId: 'p', languageCode: 'en', session: session);
    await repo.details(placeId: 'p', languageCode: 'en', session: session);
    expect(provider.detailsCalls, 1);
  });

  test('reverseGeocode caches rounded coordinates', () async {
    await repo.reverseGeocode(
        point: const GeoPoint(30.00001, 31.00001), languageCode: 'en');
    await repo.reverseGeocode(
        point: const GeoPoint(30.00002, 31.00002), languageCode: 'en');
    expect(provider.reverseCalls, 1);
  });
}
