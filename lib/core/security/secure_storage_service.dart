/// Secure storage abstraction for the Delwaqty platform.
///
/// Provides a key-value store for sensitive data such as tokens, keys,
/// and credentials. Implementations may target flutter_secure_storage,
/// platform keychain, or an in-memory mock.
library;

/// Abstract interface for secure key-value storage.
abstract class SecureStorageService {
  /// Writes a [value] under the given [key].
  Future<void> write(String key, String value);

  /// Reads the value for [key], or returns null if not found.
  Future<String?> read(String key);

  /// Deletes the entry for [key].
  Future<void> delete(String key);

  /// Deletes all entries.
  Future<void> deleteAll();

  /// Returns true if [key] exists in storage.
  Future<bool> containsKey(String key);

  /// Returns all key-value pairs currently in storage.
  Future<Map<String, String>> readAll();
}

/// In-memory implementation of [SecureStorageService].
///
/// Data is held in a plain [Map] and is lost when the process exits.
/// Suitable for unit tests and development.
class InMemorySecureStorage extends SecureStorageService {
  final Map<String, String> _store = {};

  @override
  Future<void> write(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<String?> read(String key) async {
    return _store[key];
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _store.clear();
  }

  @override
  Future<bool> containsKey(String key) async {
    return _store.containsKey(key);
  }

  @override
  Future<Map<String, String>> readAll() async {
    return Map.unmodifiable(_store);
  }
}

/// Always-failing storage for testing error paths.
class FailingSecureStorage extends SecureStorageService {
  @override
  Future<void> write(String key, String value) async {
    throw StateError('Secure storage is unavailable');
  }

  @override
  Future<String?> read(String key) async {
    throw StateError('Secure storage is unavailable');
  }

  @override
  Future<void> delete(String key) async {
    throw StateError('Secure storage is unavailable');
  }

  @override
  Future<void> deleteAll() async {
    throw StateError('Secure storage is unavailable');
  }

  @override
  Future<bool> containsKey(String key) async {
    throw StateError('Secure storage is unavailable');
  }

  @override
  Future<Map<String, String>> readAll() async {
    throw StateError('Secure storage is unavailable');
  }
}
