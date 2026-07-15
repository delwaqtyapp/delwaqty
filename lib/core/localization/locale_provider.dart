import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/constants/storage_keys.dart';
import 'package:delwaqty/data/datasources/local/shared_preferences_service.dart';

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final sharedPrefs = ref.watch(sharedPreferencesProvider);
    final savedLocale = sharedPrefs.getString(key: StorageKeys.locale);
    if (savedLocale != null) {
      return Locale(savedLocale);
    }
    return WidgetsBinding.instance.platformDispatcher.locale;
  }

  Future<void> setLocale(Locale locale) async {
    final sharedPrefs = ref.read(sharedPreferencesProvider);
    await sharedPrefs.saveString(
      key: StorageKeys.locale,
      value: locale.languageCode,
    );
    state = locale;
  }

  Future<void> toggleLocale() async {
    final newLocale =
        state.languageCode == 'ar' ? const Locale('en') : const Locale('ar');
    await setLocale(newLocale);
  }
}
