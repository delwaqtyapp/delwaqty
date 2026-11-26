import 'package:delwaqty/core/module/shell_customization.dart';
import 'package:delwaqty/features/provider/capability/domain/provider_capability.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// Whether the account type is known yet.
enum ProviderProfileStatus { loading, failed, ready }

/// Operating-experience families. Categories in the same family share every
/// flow and differ only by labels.
enum ProviderFamily {
  restaurant,
  retail,
  homeServices,
  professional,
  owner,
  unknown,
}

/// Ids of the provider app's bottom-tab modules (see `merchant_module.dart`).
class ProviderTabIds {
  const ProviderTabIds._();

  static const dashboard = 'merchant';
  static const orders = 'provider-orders-nav';
  static const products = 'provider-products-nav';
  static const bookings = 'provider-bookings-nav';
  static const services = 'provider-services-nav';
  static const cashier = 'provider-cashier-nav';
  static const financial = 'provider-financial';

  static const all = [
    dashboard,
    orders,
    products,
    bookings,
    services,
    cashier,
    financial,
  ];
}

/// Drawer entry id -> capability required to show it.
const Map<String, ProviderCapability> kDrawerEntryCapability = {
  'merchant-storefront': ProviderCapability.storefront,
  'merchant-branches': ProviderCapability.branches,
  'provider-availability': ProviderCapability.availability,
  'provider-financial-center': ProviderCapability.financial,
  'merchant-reviews': ProviderCapability.reviews,
  'provider-support': ProviderCapability.support,
};

/// Route prefix -> capability required to open it. Used by the router guard
/// so a hidden surface cannot be reached by a stale deep link or notification.
const Map<String, ProviderCapability> kRouteCapability = {
  '/provider-availability': ProviderCapability.availability,
  '/provider-financial-center': ProviderCapability.financial,
  '/merchant-dashboard/reviews': ProviderCapability.reviews,
  '/provider-documents': ProviderCapability.documents,
  '/provider-verification': ProviderCapability.verification,
  '/provider-orders': ProviderCapability.orders,
  '/merchant-dashboard/orders': ProviderCapability.orders,
  '/provider-products': ProviderCapability.catalog,
  '/merchant-dashboard/products': ProviderCapability.catalog,
  '/merchant-dashboard/inventory': ProviderCapability.inventory,
  '/provider-cashier': ProviderCapability.cashier,
  '/merchant-dashboard/pos': ProviderCapability.cashier,
  '/merchant-dashboard/cashier-license': ProviderCapability.cashier,
  '/merchant-dashboard/storefront': ProviderCapability.storefront,
  '/merchant-dashboard/banners': ProviderCapability.banners,
  '/merchant-dashboard/offers': ProviderCapability.offers,
  '/merchant-dashboard/branches': ProviderCapability.branches,
  '/merchant-dashboard/reservations': ProviderCapability.bookings,
  '/provider-bookings': ProviderCapability.bookings,
  '/provider-services': ProviderCapability.services,
};

/// Everything the provider app needs to know about how one account type
/// operates: tabs, menu, feature flags and wording.
class ProviderProfile {
  const ProviderProfile._({
    required this.family,
    required this.category,
    required this.capabilities,
    required this.tabs,
    this.status = ProviderProfileStatus.ready,
  });

  factory ProviderProfile.forCategory(ProviderCategory category) {
    final caps = resolveCapabilities(category);
    return ProviderProfile._(
      family: familyOf(category),
      category: category,
      capabilities: caps,
      tabs: _tabsFor(familyOf(category)),
    );
  }

  /// Account type still loading: only the dashboard and financial tabs, and
  /// the route guard fails closed (see [allowsRoute]).
  factory ProviderProfile.loading() => const ProviderProfile._(
    family: ProviderFamily.unknown,
    category: ProviderCategory.unknown,
    capabilities: {},
    tabs: [ProviderTabIds.dashboard, ProviderTabIds.financial],
    status: ProviderProfileStatus.loading,
  );

  /// Account type lookup failed: same closed surface as loading; the
  /// dashboard shows a retry.
  factory ProviderProfile.failed() => const ProviderProfile._(
    family: ProviderFamily.unknown,
    category: ProviderCategory.unknown,
    capabilities: {},
    tabs: [ProviderTabIds.dashboard, ProviderTabIds.financial],
    status: ProviderProfileStatus.failed,
  );

  /// Kept for existing callers: same as [loading].
  factory ProviderProfile.neutral() => ProviderProfile.loading();

  final ProviderFamily family;
  final ProviderCategory category;
  final Set<ProviderCapability> capabilities;

  /// Ordered bottom-tab module ids.
  final List<String> tabs;
  final ProviderProfileStatus status;

  bool get isReady => status == ProviderProfileStatus.ready;
  bool get isLoading => status == ProviderProfileStatus.loading;
  bool get hasFailed => status == ProviderProfileStatus.failed;
  bool get isNeutral => !isReady;

  bool has(ProviderCapability c) => capabilities.contains(c);

  // Feature flags.
  bool get hasCashier => has(ProviderCapability.cashier);
  bool get hasBarcode => has(ProviderCapability.barcode);
  bool get hasProducts => has(ProviderCapability.catalog);
  bool get hasInventory => has(ProviderCapability.inventory);
  bool get hasOrders => has(ProviderCapability.orders);
  bool get hasBookings => has(ProviderCapability.bookings);
  bool get hasServicesView => has(ProviderCapability.services);
  bool get hasStorefront => has(ProviderCapability.storefront);

  /// Whether bookings are service jobs/appointments (not table reservations).
  bool get bookingsAreServiceJobs =>
      family == ProviderFamily.homeServices ||
      family == ProviderFamily.professional;

  bool allowsDrawerEntry(String id) {
    final needed = kDrawerEntryCapability[id];
    if (needed == null) return true;
    return isNeutral ? id == 'provider-support' : has(needed);
  }

  /// True when [location] may be opened by this profile.
  ///
  /// Fails closed: until the account type is known, only the dashboard root,
  /// the financial center and shared (non-provider) routes open. Once known,
  /// gated surfaces need their capability; unknown paths stay allowed.
  bool allowsRoute(String location) {
    final path = Uri.tryParse(location)?.path ?? location;
    if (!isReady) {
      if (path == '/merchant-dashboard') return true;
      if (path == '/provider-financial-center' ||
          path.startsWith('/provider-financial-center/')) {
        return true;
      }
      return !(path.startsWith('/provider-') ||
          path.startsWith('/merchant-dashboard/'));
    }
    for (final entry in kRouteCapability.entries) {
      if (path == entry.key || path.startsWith('${entry.key}/')) {
        return has(entry.value);
      }
    }
    return true;
  }

  static ProviderFamily familyOf(ProviderCategory c) {
    switch (c) {
      case ProviderCategory.restaurant:
        return ProviderFamily.restaurant;
      case ProviderCategory.grocery:
      case ProviderCategory.marketplace:
      case ProviderCategory.retail:
        return ProviderFamily.retail;
      case ProviderCategory.homeServices:
        return ProviderFamily.homeServices;
      case ProviderCategory.teacher:
      case ProviderCategory.healthProfessional:
        return ProviderFamily.professional;
      case ProviderCategory.owner:
        return ProviderFamily.owner;
      case ProviderCategory.unknown:
        return ProviderFamily.unknown;
    }
  }

  static List<String> _tabsFor(ProviderFamily f) {
    switch (f) {
      case ProviderFamily.restaurant:
      case ProviderFamily.retail:
      case ProviderFamily.owner:
        return const [
          ProviderTabIds.dashboard,
          ProviderTabIds.orders,
          ProviderTabIds.products,
          ProviderTabIds.cashier,
          ProviderTabIds.financial,
        ];
      case ProviderFamily.homeServices:
      case ProviderFamily.professional:
        return const [
          ProviderTabIds.dashboard,
          ProviderTabIds.bookings,
          ProviderTabIds.services,
          ProviderTabIds.financial,
        ];
      case ProviderFamily.unknown:
        return const [ProviderTabIds.dashboard, ProviderTabIds.financial];
    }
  }

  /// Label for [key] in this profile's wording.
  String label(ProviderLabel key, AppLocalizations l10n) =>
      ProviderLabels.resolve(this, key, l10n);

  /// Shell configuration for the shared bottom navigation.
  ShellNavConfig toShellNavConfig() => ShellNavConfig(
    visibleModuleIds: tabs,
    labelFor: (moduleId, l10n) {
      final key = ProviderLabels.tabKeys[moduleId];
      if (key == null) return null;
      return label(key, l10n);
    },
  );
}

/// Wording slots that change per account type.
enum ProviderLabel {
  tabOrders,
  tabProducts,
  tabBookings,
  tabServices,
  tabCashier,
  manageProducts,
  viewOrders,
  bookingsTitle,
  myServicesTitle,
  emptyServices,
}

/// Label resolver per family. Families that look alike (restaurant vs
/// shops, grocery vs retail) differ by wording only. All text comes from the
/// ARB files.
class ProviderLabels {
  const ProviderLabels._();

  static const Map<String, ProviderLabel> tabKeys = {
    ProviderTabIds.orders: ProviderLabel.tabOrders,
    ProviderTabIds.products: ProviderLabel.tabProducts,
    ProviderTabIds.bookings: ProviderLabel.tabBookings,
    ProviderTabIds.services: ProviderLabel.tabServices,
    ProviderTabIds.cashier: ProviderLabel.tabCashier,
  };

  static String resolve(
    ProviderProfile profile,
    ProviderLabel key,
    AppLocalizations l,
  ) {
    final c = profile.category;
    switch (key) {
      case ProviderLabel.tabOrders:
        return l.orders;
      case ProviderLabel.tabCashier:
        return l.provTabCashier;
      case ProviderLabel.viewOrders:
        return profile.bookingsAreServiceJobs
            ? resolve(profile, ProviderLabel.bookingsTitle, l)
            : l.viewOrders;
      case ProviderLabel.tabProducts:
        switch (c) {
          case ProviderCategory.restaurant:
            return l.provTabMenu;
          case ProviderCategory.grocery:
            return l.provTabItems;
          default:
            return l.products;
        }
      case ProviderLabel.manageProducts:
        switch (c) {
          case ProviderCategory.restaurant:
            return l.provManageMenu;
          case ProviderCategory.grocery:
            return l.provManageItems;
          default:
            return l.manageProducts;
        }
      case ProviderLabel.tabBookings:
        switch (c) {
          case ProviderCategory.restaurant:
            return l.provTabTableBookings;
          case ProviderCategory.teacher:
            return l.provTabLessonRequests;
          case ProviderCategory.healthProfessional:
            return l.provTabAppointments;
          case ProviderCategory.homeServices:
            return l.provTabJobs;
          default:
            return l.reservations;
        }
      case ProviderLabel.bookingsTitle:
        switch (c) {
          case ProviderCategory.restaurant:
            return l.provTabTableBookings;
          case ProviderCategory.teacher:
            return l.provTabLessonRequests;
          case ProviderCategory.healthProfessional:
            return l.provTabAppointments;
          case ProviderCategory.homeServices:
            return l.provServiceRequests;
          default:
            return l.reservations;
        }
      case ProviderLabel.tabServices:
        return c == ProviderCategory.teacher
            ? l.provTabMyLessons
            : l.provTabMyServices;
      case ProviderLabel.myServicesTitle:
        return c == ProviderCategory.teacher
            ? l.provMyLessonsPrices
            : l.provMyServicesPrices;
      case ProviderLabel.emptyServices:
        return c == ProviderCategory.teacher
            ? l.provEmptyLessons
            : l.provEmptyServices;
    }
  }
}
