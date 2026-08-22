import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/constants/storage_keys.dart';
import 'package:delwaqty/data/datasources/local/shared_preferences_service.dart';

/// Admin-only locale, independent from the main app language (STEP 18).
///
/// The Admin Command Center defaults to Arabic regardless of the app locale
/// and persists its own choice across logout/login/restarts. It is switched
/// from Admin Settings without restarting the app.
final adminLocaleProvider = NotifierProvider<AdminLocaleNotifier, Locale>(
  AdminLocaleNotifier.new,
);

class AdminLocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final sharedPrefs = ref.watch(sharedPreferencesProvider);
    final saved = sharedPrefs.getString(key: StorageKeys.adminLocale);
    if (saved != null) {
      return Locale(saved);
    }
    final system = PlatformDispatcher.instance.locale;
    final code = system?.languageCode ?? '';
    return code.toLowerCase() == 'ar' ? const Locale('ar') : const Locale('en');
  }

  Future<void> setAdminLocale(Locale locale) async {
    if (locale.languageCode != 'ar' && locale.languageCode != 'en') {
      return;
    }
    final sharedPrefs = ref.read(sharedPreferencesProvider);
    await sharedPrefs.saveString(
      key: StorageKeys.adminLocale,
      value: locale.languageCode,
    );
    state = locale;
  }

  Future<void> toggleAdminLocale() async {
    final next = state.languageCode == 'ar'
        ? const Locale('en')
        : const Locale('ar');
    await setAdminLocale(next);
  }
}