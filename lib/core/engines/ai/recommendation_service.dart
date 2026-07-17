/// A single recommendation returned by the engine.
class Recommendation {
  /// Creates a [Recommendation] instance.
  const Recommendation({
    required this.itemId,
    required this.itemType,
    required this.score,
    this.title,
    this.description,
    this.imageUrl,
    this.metadata = const {},
  });

  /// Unique identifier of the recommended item.
  final String itemId;

  /// Type of the recommended item (e.g., "product", "service", "merchant").
  final String itemType;

  /// Relevance score between 0.0 and 1.0.
  final double score;

  /// Display title for the recommendation.
  final String? title;

  /// Short description of the recommended item.
  final String? description;

  /// URL of the item's image.
  final String? imageUrl;

  /// Additional metadata associated with this recommendation.
  final Map<String, dynamic> metadata;
}

/// An item similar to a given reference item.
class SimilarItem {
  /// Creates a [SimilarItem] instance.
  const SimilarItem({
    required this.itemId,
    required this.itemType,
    required this.similarity,
    this.title,
    this.imageUrl,
  });

  /// Unique identifier of the similar item.
  final String itemId;

  /// Type of the similar item.
  final String itemType;

  /// Similarity score between 0.0 and 1.0.
  final double similarity;

  /// Display title for the item.
  final String? title;

  /// URL of the item's image.
  final String? imageUrl;
}

/// User preferences for recommendation personalization.
class UserPreferences {
  /// Creates a [UserPreferences] instance.
  const UserPreferences({
    required this.userId,
    this.favoriteCategories = const [],
    this.preferredLocations = const [],
    this.priceRange,
    this.languages = const [],
    this.customPreferences = const {},
  });

  /// The user identifier.
  final String userId;

  /// List of preferred category identifiers.
  final List<String> favoriteCategories;

  /// List of preferred location identifiers or names.
  final List<String> preferredLocations;

  /// Optional price range preference.
  final PriceRange? priceRange;

  /// Preferred languages (ISO 639-1 codes).
  final List<String> languages;

  /// Arbitrary custom preferences.
  final Map<String, dynamic> customPreferences;
}

/// A price range constraint for preferences.
class PriceRange {
  /// Creates a [PriceRange] instance.
  const PriceRange({required this.min, required this.max});

  /// Minimum price in the range.
  final double min;

  /// Maximum price in the range.
  final double max;
}

/// A trending item with popularity metrics.
class TrendingItem {
  /// Creates a [TrendingItem] instance.
  const TrendingItem({
    required this.itemId,
    required this.itemType,
    required this.trendScore,
    this.title,
    this.imageUrl,
    this.viewCount = 0,
    this.orderCount = 0,
  });

  /// Unique identifier of the trending item.
  final String itemId;

  /// Type of the trending item.
  final String itemType;

  /// Trending score (higher = more trending).
  final double trendScore;

  /// Display title.
  final String? title;

  /// URL of the item's image.
  final String? imageUrl;

  /// Number of views in the trending period.
  final int viewCount;

  /// Number of orders in the trending period.
  final int orderCount;
}

/// Types of recommendation requests.
enum RecommendationType {
  /// General personalized recommendations.
  personalized,

  /// Content-based recommendations.
  contentBased,

  /// Collaborative filtering recommendations.
  collaborative,

  /// Trending items.
  trending,

  /// Recently viewed items.
  recentlyViewed,

  /// Items frequently bought together.
  frequentlyBoughtTogether,
}

/// Types of user interactions that can be tracked.
enum InteractionAction {
  /// User viewed an item.
  view,

  /// User added an item to cart.
  addToCart,

  /// User purchased an item.
  purchase,

  /// User rated an item.
  rate,

  /// User liked an item.
  like,

  /// User shared an item.
  share,

  /// User searched for something.
  search,
}

/// Recommendation engine abstraction.
///
/// Provides personalized recommendations, similarity lookups, preference
/// management, and interaction tracking for the super platform.
abstract interface class RecommendationService {
  /// Returns personalized recommendations for the given [userId].
  ///
  /// The optional [type] filters the recommendation strategy.
  /// [limit] caps the number of results returned.
  Future<List<Recommendation>> getRecommendations(
    String userId, {
    RecommendationType? type,
    int? limit,
  });

  /// Finds items similar to the given [itemId].
  ///
  /// [itemType] specifies the item category. [limit] caps results.
  Future<List<SimilarItem>> getSimilarItems(
    String itemId,
    String itemType, {
    int? limit,
  });

  /// Retrieves the stored preferences for the given [userId].
  Future<UserPreferences> getUserPreferences(String userId);

  /// Updates a single [preference] for the given [userId].
  Future<void> updatePreference(String userId, Map<String, dynamic> preference);

  /// Tracks a user [action] on the specified [itemId].
  Future<void> trackInteraction(
    String userId,
    String itemId,
    InteractionAction action,
  );

  /// Returns trending items in the given [category] and [location].
  ///
  /// [limit] caps the number of results returned.
  Future<List<TrendingItem>> getTrending(
    String category,
    String location, {
    int? limit,
  });
}
