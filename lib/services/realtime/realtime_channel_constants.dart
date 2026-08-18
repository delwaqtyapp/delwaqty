/// Canonical names for all Supabase Realtime channels.
///
/// Use these constants instead of raw strings to prevent typos and enable
/// a single point of change if naming conventions evolve.
abstract final class RealtimeChannels {
  RealtimeChannels._();

  static const String inAppNotifications = 'in-app-notifications';
  static const String driverOffers = 'driver-offers';
  static const String activeRide = 'active-ride';
  static const String activeDelivery = 'active-delivery';
  static const String chatMessages = 'chat-messages';
  static const String sosAlerts = 'sos-alerts';
  static const String trustedContacts = 'trusted-contacts';
  static const String locationUpdates = 'location-updates';
  static const String profileUpdates = 'profile-updates';
  static const String merchantReviews = 'merchant-reviews';
  static const String inventoryUpdates = 'inventory-updates';
}
