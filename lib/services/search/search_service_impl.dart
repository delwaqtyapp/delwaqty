import 'package:delwaqty/features/commerce/domain/entities/geo_location.dart';
import 'package:delwaqty/services/search/search_service.dart';

/// Mock implementation of [SearchService] for development.
///
/// Returns empty results for search queries and maintains a small in-memory
/// list of recent searches. Useful for UI development without a backend.
class SearchServiceImpl implements SearchService {
  final List<String> _recentSearches = [];

  @override
  Future<SearchResults> search(
    String query, {
    Map<String, dynamic>? filters,
  }) async {
    return const SearchResults(
      merchants: [],
      products: [],
      totalMerchants: 0,
      totalProducts: 0,
    );
  }

  @override
  Future<List<MerchantSearchResult>> searchMerchants(
    String query, {
    GeoLocation? location,
  }) async {
    return const [];
  }

  @override
  Future<List<ProductSearchResult>> searchProducts(
    String query, {
    String? merchantId,
  }) async {
    return const [];
  }

  @override
  Future<List<String>> getRecentSearches() async {
    return List.unmodifiable(_recentSearches);
  }

  @override
  Future<void> addRecentSearch(String query) async {
    _recentSearches.remove(query);
    _recentSearches.insert(0, query);
    if (_recentSearches.length > 20) {
      _recentSearches.removeLast();
    }
  }

  @override
  Future<void> clearRecentSearches() async {
    _recentSearches.clear();
  }

  @override
  Future<List<String>> getPopularSearches() async {
    return const [
      'restaurants',
      'groceries',
      'pharmacy',
      'flowers',
      'electronics',
    ];
  }

  @override
  Future<List<String>> getSuggestions(String query) async {
    if (query.isEmpty) return const [];
    return [
      '$query near me',
      '$query delivery',
      '$query open now',
    ];
  }
}
