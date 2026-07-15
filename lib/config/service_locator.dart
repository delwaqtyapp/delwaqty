import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Central service locator for the Delwaqty platform.
///
/// All services are registered as providers with abstract types.
/// Concrete implementations can be swapped without changing consumers.
abstract final class ServiceLocator {
  /// Registers all platform services.
  static List<Override> get overrides => [
    // Add service provider overrides here as implementations are built
    // Example:
    // locationServiceProvider.overrideWithValue(GoogleLocationService()),
    // mapsServiceProvider.overrideWithValue(GoogleMapsService()),
    // storageServiceProvider.overrideWithValue(CloudflareR2Service()),
  ];
}
