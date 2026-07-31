import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/core/theme/theme_mode_provider.dart';
import 'package:delwaqty/core/localization/locale_provider.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'floating_sidebar_overlay.dart';

class FloatingSidebarController {
  FloatingSidebarController._();

  static OverlayEntry? _currentEntry;

  static bool get isOpen => _currentEntry != null;

  static void open(BuildContext context, WidgetRef ref) {
    if (_currentEntry != null) return;

    final l10n = AppLocalizations.of(context);
    final authState = ref.read(authStateProvider);
    final themeMode = ref.read(themeModeProvider);
    final locale = ref.read(localeProvider);

    final overlay = Overlay.of(context);

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => FloatingSidebarOverlay(
        authState: authState,
        l10n: l10n,
        themeMode: themeMode,
        locale: locale,
        ref: ref,
        onDismiss: () => close(),
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  static void close() {
    _currentEntry?.remove();
    _currentEntry = null;
  }
}
