/// Configuration for a search index.
class SearchIndexConfig {
  /// Creates a [SearchIndexConfig] instance.
  const SearchIndexConfig({
    required this.fields,
    this.searchableFields = const [],
    this.filterableFields = const [],
    this.sortableFields = const [],
    this.settings = const {},
  });

  /// All indexed fields with their types.
  final Map<String, SearchFieldType> fields;

  /// Fields that are included in full-text search.
  final List<String> searchableFields;

  /// Fields that can be used for filtering.
  final List<String> filterableFields;

  /// Fields that can be used for sorting.
  final List<String> sortableFields;

  /// Additional index settings (e.g., language, synonyms).
  final Map<String, dynamic> settings;
}

/// Data types for indexed fields.
enum SearchFieldType {
  /// Text field for full-text search.
  text,

  /// Exact-match string field.
  keyword,

  /// Numeric field.
  number,

  /// Boolean field.
  boolean,

  /// Date/time field.
  date,

  /// Geographic location field.
  geo,

  /// Array of values.
  array,
}

/// A document to be indexed in the search engine.
class IndexDocument {
  /// Creates an [IndexDocument] instance.
  const IndexDocument({
    required this.id,
    required this.data,
    this.timestamp,
  });

  /// Unique document identifier.
  final String id;

  /// Document content as key-value pairs.
  final Map<String, dynamic> data;

  /// Optional timestamp for the document.
  final DateTime? timestamp;
}

/// Statistics about a search index.
class IndexStats {
  /// Creates an [IndexStats] instance.
  const IndexStats({
    required this.name,
    required this.documentCount,
    required this.sizeInBytes,
    required this.lastUpdated,
    this.fieldCount = 0,
    this.settings = const {},
  });

  /// Name of the index.
  final String name;

  /// Total number of documents in the index.
  final int documentCount;

  /// Approximate size of the index in bytes.
  final int sizeInBytes;

  /// Timestamp of the last update to the index.
  final DateTime lastUpdated;

  /// Number of fields in the index schema.
  final int fieldCount;

  /// Current index settings.
  final Map<String, dynamic> settings;
}

/// Search index abstraction.
///
/// Manages the creation, configuration, and maintenance of search indices
/// for the super platform's search engine.
abstract interface class SearchIndex {
  /// Creates a new search index with the given [name] and [config].
  Future<void> addIndex(String name, SearchIndexConfig config);

  /// Removes the search index identified by [name].
  Future<void> removeIndex(String name);

  /// Adds a [document] to the index identified by [indexName].
  Future<void> addToIndex(String indexName, IndexDocument document);

  /// Removes the document with [documentId] from the [indexName] index.
  Future<void> removeFromIndex(String indexName, String documentId);

  /// Updates an existing [document] in the [indexName] index.
  Future<void> updateIndex(String indexName, IndexDocument document);

  /// Rebuilds the index identified by [name] from scratch.
  ///
  /// This may be necessary after schema changes or to optimize performance.
  Future<void> rebuildIndex(String name);

  /// Returns statistics about the index identified by [name].
  Future<IndexStats> getIndexStats(String name);
}
