import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppFlavor { customer, admin, driver, provider }

/// Which standalone Delwaqty app is running. Overridden in each entrypoint's
/// `main_admin.dart` / `main_customer.dart` etc. so shared code can adapt.
final appFlavorProvider = Provider<AppFlavor>((ref) => AppFlavor.customer);

/// Whether the app is running as the standalone Admin Delwaqty.
/// Overridden to `true` in `main_admin.dart`; defaults to `false` (customer).
final isAdminAppProvider = Provider<bool>((ref) => ref.watch(appFlavorProvider) == AppFlavor.admin);