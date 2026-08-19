import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the app is running as the standalone Admin Delwaqty.
/// Overridden to `true` in `main_admin.dart`; defaults to `false` (customer).
final isAdminAppProvider = Provider<bool>((ref) => false);
