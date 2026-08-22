import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/constants/storage_keys.dart';
import 'package:delwaqty/data/datasources/local/shared_preferences_service.dart';

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  String get storageKey => StorageKeys.themeMode;

  @override
  ThemeMode build() {
    final sharedPrefs = ref.watch(sharedPreferencesProvider);
    final savedMode = sharedPrefs.getString(key: storageKey);
    switch (savedMode) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final sharedPrefs = ref.read(sharedPreferencesProvider);
    await sharedPrefs.saveString(key: storageKey, value: mode.name);
    state = mode;
  }

  Future<void> toggleTheme() async {
    final newMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(newMode);
  }
}

/// Per-app theme notifiers keep each application's theme choice isolated in
/// its own sandboxed SharedPreferences namespace.
class DriverThemeModeNotifier extends ThemeModeNotifier {
  @override
  String get storageKey => StorageKeys.driverThemeMode;
}

class ProviderThemeModeNotifier extends ThemeModeNotifier {
  @override
  String get storageKey => StorageKeys.providerThemeMode;
}

class CustomerThemeModeNotifier extends ThemeModeNotifier {
  @override
  String get storageKey => StorageKeys.customerThemeMode;
}

class AdminThemeModeNotifier extends ThemeModeNotifier {
  @override
  String get storageKey => StorageKeys.adminThemeMode;
}
