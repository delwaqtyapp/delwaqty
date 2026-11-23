import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// Per-app customization of the shared navigation shell.
///
/// The customer and driver apps leave both providers at `null` and keep the
/// static module list. The provider app overrides them so the bottom tabs and
/// the side menu follow the signed-in account type (restaurant,
/// shop, home services, teacher...). This is a UX layer only; server-side
/// authorization (RLS / RPC) stays the enforcement.
class ShellNavConfig {
  const ShellNavConfig({required this.visibleModuleIds, this.labelFor});

  /// Ordered ids of the nav modules to show. Modules not listed are hidden.
  final List<String> visibleModuleIds;

  /// Optional label override for a module id. Return `null` to keep the
  /// module's own name.
  final String? Function(String moduleId, AppLocalizations l10n)? labelFor;
}

/// Overridden by the provider app. `null` means "show every nav module".
final shellNavConfigProvider = Provider<ShellNavConfig?>((ref) => null);

/// Overridden by the provider app. `null` means "show every drawer entry".
final drawerEntryFilterProvider = Provider<bool Function(String id)?>(
  (ref) => null,
);
