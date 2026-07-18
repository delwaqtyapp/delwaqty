import 'package:delwaqty/features/search/domain/entities/geo_point.dart';
import 'package:delwaqty/features/search/domain/entities/place_details.dart';
import 'package:delwaqty/features/search/domain/entities/place_suggestion.dart';
import 'package:delwaqty/features/search/domain/entities/search_session.dart';

enum GeocodingErrorKind { network, rateLimited, denied, notFound, unknown }

class GeocodingException implements Exception {
  const GeocodingException(this.kind, [this.message]);

  final GeocodingErrorKind kind;
  final String? message;

  @override
  String toString() => 'GeocodingException($kind): ${message ?? ''}';
}

/// Provider-agnostic geocoding + place search contract.
///
/// Implemented by concrete providers (Google Places, Mapbox, Nominatim,
/// HERE, TomTom, ...). Business logic and UI depend only on this interface,
/// so swapping providers requires no changes above the data layer.
abstract class GeocodingProvider {
  String get id;

  /// Whether this provider uses billing session tokens for autocomplete.
  bool get usesSessionTokens;

  Future<List<PlaceSuggestion>> autocomplete({
    required String query,
    required String languageCode,
    GeoPoint? origin,
    SearchSession? session,
  });

  Future<PlaceDetails> details({
    required String placeId,
    required String languageCode,
    SearchSession? session,
  });

  Future<PlaceDetails?> reverseGeocode({
    required GeoPoint point,
    required String languageCode,
  });

  Future<List<PlaceDetails>> nearbySearch({
    required GeoPoint point,
    required String languageCode,
    String? keyword,
    int radiusMeters = 1500,
  });
}
