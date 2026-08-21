import 'package:delwaqty/features/customer/search/domain/entities/geo_point.dart';
import 'package:delwaqty/features/customer/search/domain/entities/place_details.dart';
import 'package:delwaqty/features/customer/search/domain/entities/place_suggestion.dart';
import 'package:delwaqty/features/customer/search/domain/entities/recent_search.dart';
import 'package:delwaqty/features/customer/search/domain/entities/saved_place.dart';
import 'package:delwaqty/features/customer/search/domain/entities/search_session.dart';

abstract class PlacesRepository {
  Future<List<PlaceSuggestion>> autocomplete({
    required String query,
    required String languageCode,
    GeoPoint? origin,
    required SearchSession session,
  });

  Future<PlaceDetails> details({
    required String placeId,
    required String languageCode,
    required SearchSession session,
  });

  Future<PlaceDetails?> reverseGeocode({
    required GeoPoint point,
    required String languageCode,
  });

  Future<List<PlaceDetails>> nearbySearch({
    required GeoPoint point,
    required String languageCode,
    String? keyword,
  });

  Future<List<SavedPlace>> getSavedPlaces();
  Future<SavedPlace> upsertSavedPlace(SavedPlace place);
  Future<void> deleteSavedPlace(String id);

  Future<List<RecentSearch>> getRecentSearches();
  Future<void> addRecentSearch(RecentSearch search);
  Future<void> clearRecentSearches();
}
