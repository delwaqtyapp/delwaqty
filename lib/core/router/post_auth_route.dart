import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/config/app_mode_provider.dart';

/// The route a user should land on after signing in (or continuing as a
/// guest) in the CURRENT flavor.
///
/// The welcome/login/register screens and the device-unlock gate are
/// shared by all four apps, but `/home` only exists in the customer
/// registry. Hard-coding it sent the driver and provider apps to the
/// router's "page not found" error page, which is an unrecoverable dead
/// end (there is no navigation there to escape).
String postAuthRoute(AppFlavor flavor) {
  switch (flavor) {
    case AppFlavor.admin:
      return '/admin';
    case AppFlavor.driver:
      return '/driver';
    case AppFlavor.provider:
      return '/merchant-dashboard';
    case AppFlavor.customer:
      return '/home';
  }
}

/// Riverpod convenience wrapper for [postAuthRoute].
final postAuthRouteProvider = Provider<String>(
  (ref) => postAuthRoute(ref.watch(appFlavorProvider)),
);