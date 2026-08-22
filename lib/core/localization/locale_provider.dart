import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/constants/storage_keys.dart';
import 'package:delwaqty/data/datasources/local/shared_preferences_service.dart';

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

class LocaleNotifier extends Notifier<Locale> {
  String get storageKey => StorageKeys.locale;

  @override
  Locale build() {
    final sharedPrefs = ref.watch(sharedPreferencesProvider);
    final savedLocale = sharedPrefs.getString(key: storageKey);
    if (savedLocale != null) {
      return Locale(savedLocale);
    }
    final system = PlatformDispatcher.instance.locale;
    final code = system.languageCode;
    return code.toLowerCase() == 'ar' ? const Locale('ar') : const Locale('en');
  }

  Future<void> setLocale(Locale locale) async {
    final sharedPrefs = ref.read(sharedPreferencesProvider);
    await sharedPrefs.saveString(
      key: storageKey,
      value: locale.languageCode,
    );
    state = locale;
  }

  Future<void> toggleLocale() async {
    final newLocale = state.languageCode == 'ar'
        ? const Locale('en')
        : const Locale('ar');
    await setLocale(newLocale);
  }
}

/// Per-app locale notifiers keep each application's language choice isolated
/// in its own sandboxed SharedPreferences namespace.
class DriverLocaleNotifier extends LocaleNotifier {
  @override
  String get storageKey => StorageKeys.driverLocale;
}

class ProviderLocaleNotifier extends LocaleNotifier {
  @override
  String get storageKey => StorageKeys.providerLocale;
}

class CustomerLocaleNotifier extends LocaleNotifier {
  @override
  String get storageKey => StorageKeys.customerLocale;
}
