import 'dart:convert';
import 'package:delwaqty/services/storage/storage_service.dart';

/// In-memory mock implementation of [StorageService] for development.
///
/// Stores all data in a [Map] so that reads and writes behave consistently
/// within a single app session. Encrypted values are stored in plain text
/// for development convenience.
class StorageServiceImpl implements StorageService {
  final Map<String, dynamic> _data = {};
  final Map<String, String> _encryptedData = {};

  @override
  String? getString(String key) => _data[key] as String?;

  @override
  void setString(String key, String value) => _data[key] = value;

  @override
  int? getInt(String key) => _data[key] as int?;

  @override
  void setInt(String key, int value) => _data[key] = value;

  @override
  bool? getBool(String key) => _data[key] as bool?;

  @override
  void setBool(String key, bool value) => _data[key] = value;

  @override
  double? getDouble(String key) => _data[key] as double?;

  @override
  void setDouble(String key, double value) => _data[key] = value;

  @override
  T? getObject<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final raw = _data[key];
    if (raw == null) return null;
    if (raw is String) {
      return fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
    if (raw is Map<String, dynamic>) {
      return fromJson(raw);
    }
    return null;
  }

  @override
  void setObject<T>(
    String key,
    Map<String, dynamic> Function(T value) toJson,
    T value,
  ) {
    _data[key] = toJson(value);
  }

  @override
  void remove(String key) => _data.remove(key);

  @override
  void clear() => _data.clear();

  @override
  bool containsKey(String key) => _data.containsKey(key);

  @override
  Future<String?> getEncryptedString(String key) async {
    return _encryptedData[key];
  }

  @override
  Future<void> setEncryptedString(String key, String value) async {
    _encryptedData[key] = value;
  }
}
