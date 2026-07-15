import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delwaqty/core/constants/storage_keys.dart';

final sharedPreferencesProvider = Provider<SharedPreferencesService>((ref) {
  throw UnimplementedError(
    'SharedPreferencesService must be initialized in main() using ProviderScope',
  );
});

class SharedPreferencesService {
  SharedPreferencesService(this._prefs);

  final SharedPreferences _prefs;

  Future<bool> saveString({required String key, required String value}) {
    return _prefs.setString(key, value);
  }

  String? getString({required String key}) {
    return _prefs.getString(key);
  }

  Future<bool> saveBool({required String key, required bool value}) {
    return _prefs.setBool(key, value);
  }

  bool getBool({required String key, bool defaultValue = false}) {
    return _prefs.getBool(key) ?? defaultValue;
  }

  Future<bool> remove({required String key}) {
    return _prefs.remove(key);
  }

  Future<bool> clear() {
    return _prefs.clear();
  }

  bool get isOnboardingComplete =>
      getBool(key: StorageKeys.onboardingComplete);

  Future<void> setOnboardingComplete() {
    return saveBool(key: StorageKeys.onboardingComplete, value: true);
  }
}
