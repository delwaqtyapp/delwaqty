/// Abstract interface for key-value and object storage services.
///
/// Wraps local persistence mechanisms (SharedPreferences, secure storage)
/// behind a unified API for reading and writing primitive types, objects,
/// and encrypted values.
abstract interface class StorageService {
  /// Returns the string value associated with [key], or null if absent.
  String? getString(String key);

  /// Stores a [value] under [key] as a string.
  void setString(String key, String value);

  /// Returns the integer value associated with [key], or null if absent.
  int? getInt(String key);

  /// Stores a [value] under [key] as an integer.
  void setInt(String key, int value);

  /// Returns the boolean value associated with [key], or null if absent.
  bool? getBool(String key);

  /// Stores a [value] under [key] as a boolean.
  void setBool(String key, bool value);

  /// Returns the double value associated with [key], or null if absent.
  double? getDouble(String key);

  /// Stores a [value] under [key] as a double.
  void setDouble(String key, double value);

  /// Deserialises and returns the object associated with [key] using
  /// [fromJson], or null if absent.
  T? getObject<T>(String key, T Function(Map<String, dynamic>) fromJson);

  /// Serialises [value] using [toJson] and stores it under [key].
  void setObject<T>(
    String key,
    Map<String, dynamic> Function(T value) toJson,
    T value,
  );

  /// Removes the entry associated with [key].
  void remove(String key);

  /// Removes all entries from storage.
  void clear();

  /// Returns true if an entry with [key] exists.
  bool containsKey(String key);

  /// Returns the encrypted string value associated with [key], or null.
  Future<String?> getEncryptedString(String key);

  /// Stores a [value] under [key] using encryption.
  Future<void> setEncryptedString(String key, String value);
}
