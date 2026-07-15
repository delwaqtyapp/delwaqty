import 'package:delwaqty/features/commerce/domain/entities/geo_location.dart';
import 'package:delwaqty/features/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/commerce/domain/entities/product.dart';

/// A merchant search result with relevance scoring.
class MerchantSearchResult {
  /// Creates a [MerchantSearchResult].
  const MerchantSearchResult({
    required this.merchant,
    this.relevanceScore,
    this.distanceMetres,
  });

  /// The matched [Merchant] entity.
  final Merchant merchant;

  /// Relevance score between 0.0 and 1.0, where 1.0 is a perfect match.
  final double? relevanceScore;

  /// Distance from the search origin in metres, if location-based.
  final double? distanceMetres;
}

/// A product search result with relevance scoring.
class ProductSearchResult {
  /// Creates a [ProductSearchResult].
  const ProductSearchResult({
    required this.product,
    this.relevanceScore,
    this.merchantName,
  });

  /// The matched [Product] entity.
  final Product product;

  /// Relevance score between 0.0 and 1.0.
  final double? relevanceScore;

  /// Name of the merchant that sells this product.
  final String? merchantName;
}

/// Paginated search results containing both merchants and products.
class SearchResults {
  /// Creates [SearchResults].
  const SearchResults({
    required this.merchants,
    required this.products,
    required this.totalMerchants,
    required this.totalProducts,
  });

  /// Matching merchants for this search.
  final List<MerchantSearchResult> merchants;

  /// Matching products for this search.
  final List<ProductSearchResult> products;

  /// Total number of merchant matches (may exceed [merchants] length for
  /// paginated results).
  final int totalMerchants;

  /// Total number of product matches.
  final int totalProducts;
}

/// Abstract interface for search services across merchants and products.
///
/// Provides full-text search, recent/popular searches, and autocomplete
/// suggestions.
abstract interface class SearchService {
  /// Executes a search for [query] with optional [filters].
  Future<SearchResults> search(String query, {Map<String, dynamic>? filters});

  /// Searches for merchants matching [query] near the given [location].
  Future<List<MerchantSearchResult>> searchMerchants(
    String query, {
    GeoLocation? location,
  });

  /// Searches for products matching [query] within a specific [merchantId].
  Future<List<ProductSearchResult>> searchProducts(
    String query, {
    String? merchantId,
  });

  /// Returns the user's recent search queries, most recent first.
  Future<List<String>> getRecentSearches();

  /// Adds [query] to the user's recent search history.
  Future<void> addRecentSearch(String query);

  /// Clears all recent search history for the current user.
  Future<void> clearRecentSearches();

  /// Returns a list of popular/trending search queries.
  Future<List<String>> getPopularSearches();

  /// Returns autocomplete [suggestions] for a partial [query].
  Future<List<String>> getSuggestions(String query);
}
