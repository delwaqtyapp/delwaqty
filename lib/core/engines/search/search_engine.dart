/// A search result returned by the engine.
class SearchResult {
  /// Creates a [SearchResult] instance.
  const SearchResult({
    required this.id,
    required this.type,
    required this.title,
    this.description,
    this.imageUrl,
    this.score = 0.0,
    this.highlights = const [],
    this.metadata = const {},
  });

  /// Unique identifier of the result.
  final String id;

  /// Type of the result (e.g., "product", "merchant", "service").
  final String type;

  /// Display title.
  final String title;

  /// Short description or snippet.
  final String? description;

  /// URL of an associated image.
  final String? imageUrl;

  /// Relevance score (higher = more relevant).
  final double score;

  /// Highlighted text fragments matching the query.
  final List<String> highlights;

  /// Additional metadata from the index.
  final Map<String, dynamic> metadata;
}

/// Search filters applied to a query.
class SearchFilters {
  /// Creates a [SearchFilters] instance.
  const SearchFilters({
    this.types,
    this.location,
    this.priceMin,
    this.priceMax,
    this.rating,
    this.sortBy,
    this.sortOrder,
    this.custom = const {},
  });

  /// Filter by result types.
  final List<String>? types;

  /// Filter by geographic location.
  final String? location;

  /// Minimum price filter.
  final double? priceMin;

  /// Maximum price filter.
  final double? priceMax;

  /// Minimum rating filter.
  final double? rating;

  /// Sort field name.
  final String? sortBy;

  /// Sort order (ascending or descending).
  final SearchSortOrder? sortOrder;

  /// Arbitrary custom filter parameters.
  final Map<String, dynamic> custom;
}

/// Sort order for search results.
enum SearchSortOrder {
  /// Sort in ascending order.
  ascending,

  /// Sort in descending order.
  descending,
}

/// Paginated search response.
class SearchResponse {
  /// Creates a [SearchResponse] instance.
  const SearchResponse({
    required this.results,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    this.query,
    this.filters,
    this.suggestions = const [],
  });

  /// List of search results for the current page.
  final List<SearchResult> results;

  /// Total number of results matching the query.
  final int totalCount;

  /// Current page number (1-indexed).
  final int page;

  /// Number of results per page.
  final int pageSize;

  /// The original query string.
  final String? query;

  /// The filters that were applied.
  final SearchFilters? filters;

  /// Query suggestions for "did you mean" functionality.
  final List<String> suggestions;
}

/// An autocomplete suggestion.
class AutocompleteResult {
  /// Creates an [AutocompleteResult] instance.
  const AutocompleteResult({
    required this.text,
    required this.type,
    this.secondaryText,
    this.imageUrl,
  });

  /// The suggested text.
  final String text;

  /// Type of suggestion (e.g., "query", "product", "merchant").
  final String type;

  /// Secondary display text (e.g., category or location).
  final String? secondaryText;

  /// Optional image associated with the suggestion.
  final String? imageUrl;
}

/// A recent or historical search entry.
class SearchHistoryEntry {
  /// Creates a [SearchHistoryEntry] instance.
  const SearchHistoryEntry({
    required this.query,
    required this.timestamp,
    this.resultCount,
  });

  /// The search query that was executed.
  final String query;

  /// When the search was performed.
  final DateTime timestamp;

  /// Number of results returned, if known.
  final int? resultCount;
}

/// A search filter option available for a given result type.
class SearchFilterOption {
  /// Creates a [SearchFilterOption] instance.
  const SearchFilterOption({
    required this.field,
    required this.label,
    required this.type,
    this.options = const [],
  });

  /// The filter field identifier.
  final String field;

  /// Human-readable label for the filter.
  final String label;

  /// Data type of the filter (e.g., "text", "range", "select", "boolean").
  final String type;

  /// Available options for select-type filters.
  final List<SearchFilterOptionValue> options;
}

/// A selectable value within a search filter.
class SearchFilterOptionValue {
  /// Creates a [SearchFilterOptionValue] instance.
  const SearchFilterOptionValue({
    required this.value,
    required this.label,
    this.count,
  });

  /// The filter value.
  final String value;

  /// Display label.
  final String label;

  /// Number of results matching this value, if known.
  final int? count;
}

/// Unified search engine abstraction.
///
/// Provides full-text search, autocomplete, voice search, semantic search,
/// and search history management across the super platform.
abstract interface class SearchEngine {
  /// Executes a search for the given [query].
  ///
  /// [filters] narrows results. [page] and [pageSize] control pagination.
  Future<SearchResponse> search(
    String query, {
    SearchFilters? filters,
    int? page,
    int? pageSize,
  });

  /// Adds a document to the search index.
  ///
  /// [type] is the document category (e.g., "product"). [id] is the
  /// unique document identifier. [data] is the document content.
  Future<void> indexDocument(String type, String id, Map<String, dynamic> data);

  /// Removes a document from the search index.
  Future<void> removeDocument(String type, String id);

  /// Updates a document in the search index.
  Future<void> updateDocument(
    String type,
    String id,
    Map<String, dynamic> data,
  );

  /// Returns autocomplete suggestions for the given [query].
  ///
  /// [limit] caps the number of suggestions returned.
  Future<List<String>> getSuggestions(String query, {int? limit});

  /// Returns rich autocomplete results for the given [query].
  ///
  /// [limit] caps the number of results returned.
  Future<List<AutocompleteResult>> getAutocomplete(String query, {int? limit});

  /// Returns recent searches performed by the given [userId].
  Future<List<String>> getRecentSearches(String userId);

  /// Records a [query] in the recent search history for [userId].
  Future<void> addRecentSearch(String userId, String query);

  /// Clears all recent searches for the given [userId].
  Future<void> clearRecentSearches(String userId);

  /// Returns popular search queries for the given [location].
  Future<List<String>> getPopularSearches(String location);

  /// Transcribes audio [audioData] into text using speech recognition.
  ///
  /// Returns the transcribed search query string.
  Future<String> voiceSearch(List<int> audioData);

  /// Performs a semantic search using natural language understanding.
  ///
  /// [query] is a natural language question. [context] provides
  /// additional context for disambiguation.
  Future<List<SearchResult>> semanticSearch(String query, {String? context});

  /// Returns available search filters for the given result [type].
  Future<List<SearchFilterOption>> getSearchFilters(String type);

  /// Returns the search history for the given [userId].
  ///
  /// [limit] caps the number of entries returned.
  Future<List<SearchHistoryEntry>> getSearchHistory(
    String userId, {
    int? limit,
  });
}
