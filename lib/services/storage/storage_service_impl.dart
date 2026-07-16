import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:delwaqty/services/storage/storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageServiceImpl(
    SharedPreferences.getInstance(),
    const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    ),
  );
});

class StorageServiceImpl implements StorageService {
  StorageServiceImpl(this._prefsFuture, this._secureStorage);

  final Future<SharedPreferences> _prefsFuture;
  final FlutterSecureStorage _secureStorage;
  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await _prefsFuture;
    return _prefs!;
  }

  @override
  String? getString(String key) => _prefs?.getString(key);

  @override
  void setString(String key, String value) {
    _prefs?.setString(key, value);
  }

  @override
  int? getInt(String key) => _prefs?.getInt(key);

  @override
  void setInt(String key, int value) {
    _prefs?.setInt(key, value);
  }

  @override
  bool? getBool(String key) => _prefs?.getBool(key);

  @override
  void setBool(String key, bool value) {
    _prefs?.setBool(key, value);
  }

  @override
  double? getDouble(String key) => _prefs?.getDouble(key);

  @override
  void setDouble(String key, double value) {
    _prefs?.setDouble(key, value);
  }

  @override
  T? getObject<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final raw = _prefs?.getString(key);
    if (raw == null) return null;
    return fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  void setObject<T>(
    String key,
    Map<String, dynamic> Function(T value) toJson,
    T value,
  ) {
    _prefs?.setString(key, jsonEncode(toJson(value)));
  }

  @override
  void remove(String key) {
    _prefs?.remove(key);
  }

  @override
  void clear() {
    _prefs?.clear();
  }

  @override
  bool containsKey(String key) {
    return _prefs?.containsKey(key) ?? false;
  }

  @override
  Future<String?> getEncryptedString(String key) async {
    return _secureStorage.read(key: key);
  }

  @override
  Future<void> setEncryptedString(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  Future<void> initialize() async {
    await _getPrefs();
  }
}
