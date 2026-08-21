import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:delwaqty/config/app_config.dart';
import 'package:delwaqty/core/localization/locale_provider.dart';
import 'package:delwaqty/features/customer/search/data/datasources/local/recent_searches_store.dart';
import 'package:delwaqty/features/customer/search/data/datasources/remote/supabase_saved_places_data_source.dart';
import 'package:delwaqty/features/customer/search/data/providers/google_places_provider.dart';
import 'package:delwaqty/features/customer/search/data/repositories/places_repository_impl.dart';
import 'package:delwaqty/features/customer/search/domain/entities/recent_search.dart';
import 'package:delwaqty/features/customer/search/domain/entities/saved_place.dart';
import 'package:delwaqty/features/customer/search/domain/geocoding_provider.dart';
import 'package:delwaqty/features/customer/search/domain/repositories/places_repository.dart';

final geocodingProviderProvider = Provider<GeocodingProvider>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return GooglePlacesProvider(apiKey: AppConfig.mapsApiKey, client: client);
});

final placesRepositoryProvider = Provider<PlacesRepository>((ref) {
  return PlacesRepositoryImpl(
    provider: ref.watch(geocodingProviderProvider),
    savedPlaces: ref.watch(supabaseSavedPlacesDataSourceProvider),
    recentSearches: ref.watch(recentSearchesStoreProvider),
  );
});

final searchLanguageProvider = Provider<String>((ref) {
  return ref.watch(localeProvider).languageCode;
});

final savedPlacesProvider = FutureProvider<List<SavedPlace>>((ref) async {
  return ref.watch(placesRepositoryProvider).getSavedPlaces();
});

final recentSearchesProvider =
    FutureProvider<List<RecentSearch>>((ref) async {
  return ref.watch(placesRepositoryProvider).getRecentSearches();
});
