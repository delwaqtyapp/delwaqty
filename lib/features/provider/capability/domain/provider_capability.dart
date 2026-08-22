/// Provider capability model.
///
/// Capabilities are a UX-composition layer ONLY. They never replace backend
/// authorization (RLS / RPC / ownership / region scope). The canonical source
/// of a provider's classification is the database:
///   - `merchants.type`      (restaurant/food, pharmacy, grocery, marketplace,
///                            electronics, fashion, flowers, bakery, general)
///   - `service_providers.category_type` (plumbing, electrical, cleaning, ...)
/// These DB literals are preserved and normalized to [ProviderCategory].
enum ProviderCapability {
  dashboard,
  orders,
  catalog,
  services,
  bookings,
  branches,
  offers,
  reviews,
  availability,
  deliveries,
  wallet,
  earnings,
  commission,
  financial,
  verification,
  documents,
  support,
  notifications,
}

/// Canonical provider categories derived from the database vocabulary.
enum ProviderCategory {
  restaurant,
  pharmacy,
  grocery,
  marketplace,
  retail,
  homeServices,
  unknown;

  /// Maps a raw database value (`merchants.type` or
  /// `service_providers.category_type`) to a canonical category.
  ///
  /// Unknown values fall back to [ProviderCategory.unknown] so the UI stays
  /// safe (minimal capability set) rather than assuming a type.
  static ProviderCategory normalize(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    switch (value) {
      case 'food':
      case 'restaurant':
        return ProviderCategory.restaurant;
      case 'pharmacy':
        return ProviderCategory.pharmacy;
      case 'grocery':
      case 'supermarket':
      case 'marketplace':
        return value == 'marketplace'
            ? ProviderCategory.marketplace
            : ProviderCategory.grocery;
      case 'electronics':
      case 'fashion':
      case 'flowers':
      case 'bakery':
      case 'general':
      case 'retail':
        return ProviderCategory.retail;
      case 'plumbing':
      case 'electrical':
      case 'cleaning':
      case 'handyman':
      case 'home_services':
      case 'homeservices':
        return ProviderCategory.homeServices;
      default:
        return ProviderCategory.unknown;
    }
  }
}

/// Pure resolver: category -> capability set.
///
/// This is the single source of truth for which surfaces a provider sees.
/// It is intentionally free of I/O so it can be unit-tested exhaustively and
/// reused by navigation, deep-links, and notification routing.
Set<ProviderCapability> resolveCapabilities(ProviderCategory category) {
  switch (category) {
    case ProviderCategory.restaurant:
      return {
        ProviderCapability.dashboard,
        ProviderCapability.orders,
        ProviderCapability.catalog,
        ProviderCapability.branches,
        ProviderCapability.offers,
        ProviderCapability.reviews,
        ProviderCapability.availability,
        ProviderCapability.deliveries,
        ProviderCapability.wallet,
        ProviderCapability.earnings,
        ProviderCapability.commission,
        ProviderCapability.financial,
        ProviderCapability.notifications,
        ProviderCapability.support,
      };
    case ProviderCategory.pharmacy:
      return {
        ProviderCapability.dashboard,
        ProviderCapability.orders,
        ProviderCapability.catalog,
        ProviderCapability.branches,
        ProviderCapability.offers,
        ProviderCapability.availability,
        ProviderCapability.wallet,
        ProviderCapability.earnings,
        ProviderCapability.commission,
        ProviderCapability.financial,
        ProviderCapability.notifications,
        ProviderCapability.support,
      };
    case ProviderCategory.grocery:
    case ProviderCategory.marketplace:
    case ProviderCategory.retail:
      return {
        ProviderCapability.dashboard,
        ProviderCapability.orders,
        ProviderCapability.catalog,
        ProviderCapability.branches,
        ProviderCapability.offers,
        ProviderCapability.availability,
        ProviderCapability.deliveries,
        ProviderCapability.wallet,
        ProviderCapability.earnings,
        ProviderCapability.commission,
        ProviderCapability.financial,
        ProviderCapability.notifications,
        ProviderCapability.support,
      };
    case ProviderCategory.homeServices:
      return {
        ProviderCapability.dashboard,
        ProviderCapability.services,
        ProviderCapability.bookings,
        ProviderCapability.availability,
        ProviderCapability.reviews,
        ProviderCapability.documents,
        ProviderCapability.verification,
        ProviderCapability.wallet,
        ProviderCapability.earnings,
        ProviderCapability.commission,
        ProviderCapability.financial,
        ProviderCapability.notifications,
        ProviderCapability.support,
      };
    case ProviderCategory.unknown:
      return {
        ProviderCapability.dashboard,
        ProviderCapability.financial,
        ProviderCapability.notifications,
        ProviderCapability.support,
      };
  }
}

/// Convenience helper used by UI guards (does NOT replace server authz).
bool hasCapability(
  Set<ProviderCapability> capabilities,
  ProviderCapability capability,
) =>
    capabilities.contains(capability);
