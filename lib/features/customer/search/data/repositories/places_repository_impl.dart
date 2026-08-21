import 'package:delwaqty/features/customer/search/data/cache/ttl_cache.dart';
import 'package:delwaqty/features/customer/search/data/datasources/local/recent_searches_store.dart';
import 'package:delwaqty/features/customer/search/data/datasources/remote/supabase_saved_places_data_source.dart';
import 'package:delwaqty/features/customer/search/domain/entities/geo_point.dart';
import 'package:delwaqty/features/customer/search/domain/entities/place_details.dart';
import 'package:delwaqty/features/customer/search/domain/entities/place_suggestion.dart';
import 'package:delwaqty/features/customer/search/domain/entities/recent_search.dart';
import 'package:delwaqty/features/customer/search/domain/entities/saved_place.dart';
import 'package:delwaqty/features/customer/search/domain/entities/search_session.dart';
import 'package:delwaqty/features/customer/search/domain/geocoding_provider.dart';
import 'package:delwaqty/features/customer/search/domain/repositories/places_repository.dart';

class PlacesRepositoryImpl implements PlacesRepository {
  PlacesRepositoryImpl({
    required GeocodingProvider provider,
    required SupabaseSavedPlacesDataSource savedPlaces,
    required RecentSearchesStore recentSearches,
  })  : _provider = provider,
        _savedPlaces = savedPlaces,
        _recentSearches = recentSearches;

  final GeocodingProvider _provider;
  final SupabaseSavedPlacesDataSource _savedPlaces;
  final RecentSearchesStore _recentSearches;

  final TtlCache<String, List<PlaceSuggestion>> _autocompleteCache =
      TtlCache(maxEntries: 60, ttl: const Duration(minutes: 3));
  final TtlCache<String, PlaceDetails> _detailsCache =
      TtlCache(maxEntries: 60, ttl: const Duration(hours: 12));
  final TtlCache<String, PlaceDetails?> _reverseCache =
      TtlCache(maxEntries: 40, ttl: const Duration(minutes: 30));

  @override
  Future<List<PlaceSuggestion>> autocomplete({
    required String query,
    required String languageCode,
    GeoPoint? origin,
    required SearchSession session,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    final cacheKey = '$languageCode|$trimmed|${origin?.latitude ?? ''}';
    final cached = _autocompleteCache.get(cacheKey);
    if (cached != null) return cached;
    final results = await _provider.autocomplete(
      query: trimmed,
      languageCode: languageCode,
      origin: origin,
      session: _provider.usesSessionTokens ? session : null,
    );
    _autocompleteCache.put(cacheKey, results);
    return results;
  }

  @override
  Future<PlaceDetails> details({
    required String placeId,
    required String languageCode,
    required SearchSession session,
  }) async {
    final cacheKey = '$languageCode|$placeId';
    final cached = _detailsCache.get(cacheKey);
    if (cached != null) return cached;
    final result = await _provider.details(
      placeId: placeId,
      languageCode: languageCode,
      session: _provider.usesSessionTokens ? session : null,
    );
    _detailsCache.put(cacheKey, result);
    return result;
  }

  @override
  Future<PlaceDetails?> reverseGeocode({
    required GeoPoint point,
    required String languageCode,
  }) async {
    final rl = point.latitude.toStringAsFixed(4);
    final rn = point.longitude.toStringAsFixed(4);
    final cacheKey = '$languageCode|$rl,$rn';
    final cached = _reverseCache.get(cacheKey);
    if (cached != null) return cached;
    final result =
        await _provider.reverseGeocode(point: point, languageCode: languageCode);
    _reverseCache.put(cacheKey, result);
    return result;
  }

  @override
  Future<List<PlaceDetails>> nearbySearch({
    required GeoPoint point,
    required String languageCode,
    String? keyword,
  }) {
    return _provider.nearbySearch(
      point: point,
      languageCode: languageCode,
      keyword: keyword,
    );
  }

  @override
  Future<List<SavedPlace>> getSavedPlaces() => _savedPlaces.getSavedPlaces();

  @override
  Future<SavedPlace> upsertSavedPlace(SavedPlace place) =>
      _savedPlaces.upsertSavedPlace(place);

  @override
  Future<void> deleteSavedPlace(String id) =>
      _savedPlaces.deleteSavedPlace(id);

  @override
  Future<List<RecentSearch>> getRecentSearches() async =>
      _recentSearches.getAll();

  @override
  Future<void> addRecentSearch(RecentSearch search) =>
      _recentSearches.add(search);

  @override
  Future<void> clearRecentSearches() => _recentSearches.clear();
}
