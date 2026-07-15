/// A price quote returned by the pricing engine.
class PriceQuote {
  /// Creates a [PriceQuote] instance.
  const PriceQuote({
    required this.itemId,
    required this.basePrice,
    required this.finalPrice,
    this.currency = 'SAR',
    this.surgeMultiplier = 1.0,
    this.breakdown = const {},
    this.validUntil,
  });

  /// Identifier of the item being priced.
  final String itemId;

  /// The base price before adjustments.
  final double basePrice;

  /// The final price after all adjustments.
  final double finalPrice;

  /// Currency code (ISO 4217).
  final String currency;

  /// Surge pricing multiplier applied.
  final double surgeMultiplier;

  /// Itemized breakdown of price components.
  final Map<String, double> breakdown;

  /// Timestamp until which this quote is valid.
  final DateTime? validUntil;
}

/// A promotion available to a user.
class Promotion {
  /// Creates a [Promotion] instance.
  const Promotion({
    required this.id,
    required this.title,
    required this.discountType,
    required this.discountValue,
    this.description,
    this.code,
    this.minOrderValue,
    this.maxDiscount,
    this.validFrom,
    this.validUntil,
    this.applicableCategories = const [],
  });

  /// Unique promotion identifier.
  final String id;

  /// Display title for the promotion.
  final String title;

  /// Type of discount (percentage or fixed amount).
  final DiscountType discountType;

  /// Value of the discount (percentage or fixed amount).
  final double discountValue;

  /// Optional description of the promotion.
  final String? description;

  /// Coupon code required to apply this promotion.
  final String? code;

  /// Minimum order value to qualify for this promotion.
  final double? minOrderValue;

  /// Maximum discount amount that can be applied.
  final double? maxDiscount;

  /// Start date of the promotion validity.
  final DateTime? validFrom;

  /// End date of the promotion validity.
  final DateTime? validUntil;

  /// Categories to which this promotion applies.
  final List<String> applicableCategories;
}

/// Types of discounts.
enum DiscountType {
  /// Percentage-based discount.
  percentage,

  /// Fixed amount discount.
  fixed,
}

/// A price estimate for a multi-item order.
class PriceEstimate {
  /// Creates a [PriceEstimate] instance.
  const PriceEstimate({
    required this.subtotal,
    required this.deliveryFee,
    required this.taxes,
    required this.total,
    this.currency = 'SAR',
    this.items = const [],
    this.estimatedDuration,
  });

  /// Sum of all item prices.
  final double subtotal;

  /// Delivery or service fee.
  final double deliveryFee;

  /// Applicable taxes.
  final double taxes;

  /// Grand total including all fees and taxes.
  final double total;

  /// Currency code (ISO 4217).
  final String currency;

  /// Per-item price breakdown.
  final List<PriceEstimateItem> items;

  /// Estimated duration for delivery or service.
  final Duration? estimatedDuration;
}

/// A single item in a price estimate.
class PriceEstimateItem {
  /// Creates a [PriceEstimateItem] instance.
  const PriceEstimateItem({
    required this.itemId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    required this.totalPrice,
  });

  /// Identifier of the item.
  final String itemId;

  /// Display name of the item.
  final String name;

  /// Price per unit.
  final double unitPrice;

  /// Quantity ordered.
  final int quantity;

  /// Total price for this line item.
  final double totalPrice;
}

/// Result of applying a discount to a price.
class DiscountedPrice {
  /// Creates a [DiscountedPrice] instance.
  const DiscountedPrice({
    required this.originalPrice,
    required this.discountAmount,
    required this.finalPrice,
    required this.promotionId,
    this.couponCode,
    this.currency = 'SAR',
  });

  /// The price before the discount.
  final double originalPrice;

  /// The amount deducted by the discount.
  final double discountAmount;

  /// The price after the discount.
  final double finalPrice;

  /// Identifier of the applied promotion.
  final String promotionId;

  /// The coupon code that was applied.
  final String? couponCode;

  /// Currency code (ISO 4217).
  final String currency;
}

/// Dynamic pricing abstraction.
///
/// Provides surge pricing, promotional offers, price estimation,
/// and discount application across the super platform.
abstract interface class PricingService {
  /// Returns a price quote for the given [itemId].
  ///
  /// Optional parameters allow location-based, demand-based,
  /// and time-based pricing adjustments.
  Future<PriceQuote> getPrice(
    String itemId, {
    String? location,
    double? demand,
    DateTime? time,
  });

  /// Returns the current surge multiplier for the given [location] and
  /// [serviceType].
  ///
  /// A multiplier of 1.0 means no surge. Values above 1.0 indicate
  /// increased pricing due to demand.
  Future<double> getSurgeMultiplier(String location, String serviceType);

  /// Returns active promotions available to the [userId] at the
  /// given [location].
  Future<List<Promotion>> getPromotions(String userId, String location);

  /// Estimates the total price for ordering [quantity] of [itemId]
  /// at the specified [location].
  Future<PriceEstimate> estimatePrice(
    String itemId,
    int quantity,
    String location,
  );

  /// Applies a [couponCode] to the given [price] and returns the
  /// discounted result.
  Future<DiscountedPrice> applyDiscount(double price, String couponCode);
}
