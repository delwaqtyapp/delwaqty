import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricCredentials {
  const BiometricCredentials({
    required this.userId,
    required this.email,
    required this.password,
  });

  final String userId;
  final String email;
  final String password;
}

final biometricAuthStoreProvider = Provider<BiometricAuthStore>((ref) {
  return BiometricAuthStore(const FlutterSecureStorage());
});

class BiometricAuthStore {
  BiometricAuthStore(this._secureStorage);

  final FlutterSecureStorage _secureStorage;

  static const String _credentialKeyPrefix = 'auth_biometric_';
  static const String _activeUserKey = 'auth_biometric_active_user';
  static const String _indexKey = 'auth_biometric_index';

  Future<void> saveCredentials({
    required String userId,
    required String email,
    required String password,
  }) async {
    final payload = jsonEncode({
      'email': email,
      'password': password,
      'userId': userId,
    });
    await _secureStorage.write(key: _credentialKey(userId), value: payload);
    await _secureStorage.write(key: _activeUserKey, value: userId);
    await _addToIndex(userId);
  }

  Future<BiometricCredentials?> credentialsFor(String userId) async {
    final raw = await _secureStorage.read(key: _credentialKey(userId));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final email = decoded['email'] as String?;
      final password = decoded['password'] as String?;
      if (email == null ||
          email.isEmpty ||
          password == null ||
          password.isEmpty) {
        return null;
      }
      return BiometricCredentials(
        userId: userId,
        email: email,
        password: password,
      );
    } catch (_) {
      return null;
    }
  }

  Future<BiometricCredentials?> credentialsForEmail(String email) async {
    final userIds = await allUserIds();
    for (final uid in userIds) {
      final creds = await credentialsFor(uid);
      if (creds != null && creds.email.toLowerCase() == email.toLowerCase()) {
        return creds;
      }
    }
    return null;
  }

  Future<BiometricCredentials?> activeCredentials() async {
    final userId = await _secureStorage.read(key: _activeUserKey);
    if (userId == null || userId.isEmpty) return null;
    return credentialsFor(userId);
  }

  Future<String?> activeUserId() async {
    final userId = await _secureStorage.read(key: _activeUserKey);
    if (userId == null || userId.isEmpty) return null;
    return userId;
  }

  Future<bool> hasAnyCredentials() async {
    final userIds = await allUserIds();
    for (final uid in userIds) {
      final creds = await credentialsFor(uid);
      if (creds != null) return true;
    }
    return false;
  }

  Future<List<String>> allUserIds() async {
    final raw = await _secureStorage.read(key: _indexKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.whereType<String>().toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> clearActive() async {
    final userId = await _secureStorage.read(key: _activeUserKey);
    await _secureStorage.delete(key: _activeUserKey);
    if (userId != null && userId.isNotEmpty) {
      await _secureStorage.delete(key: _credentialKey(userId));
      await _removeFromIndex(userId);
    }
  }

  Future<void> clearForUser(String userId) async {
    final activeId = await _secureStorage.read(key: _activeUserKey);
    await _secureStorage.delete(key: _credentialKey(userId));
    await _removeFromIndex(userId);
    if (activeId == userId) {
      await _secureStorage.delete(key: _activeUserKey);
    }
  }

  Future<void> clearAll() async {
    final userIds = await allUserIds();
    for (final uid in userIds) {
      await _secureStorage.delete(key: _credentialKey(uid));
    }
    await _secureStorage.delete(key: _activeUserKey);
    await _secureStorage.delete(key: _indexKey);
  }

  Future<void> _addToIndex(String userId) async {
    final ids = await allUserIds();
    if (!ids.contains(userId)) {
      ids.add(userId);
      await _secureStorage.write(key: _indexKey, value: jsonEncode(ids));
    }
  }

  Future<void> _removeFromIndex(String userId) async {
    final ids = await allUserIds();
    ids.remove(userId);
    if (ids.isEmpty) {
      await _secureStorage.delete(key: _indexKey);
    } else {
      await _secureStorage.write(key: _indexKey, value: jsonEncode(ids));
    }
  }

  String _credentialKey(String userId) => '$_credentialKeyPrefix$userId';
}
