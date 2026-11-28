import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricCredentials {
  const BiometricCredentials({
    required this.userId,
    required this.identifier,
    required this.password,
  });

  final String userId;

  /// The LOGIN identifier (phone or username) replayed through the
  /// auth-login-identifier function - never an email. Email is not a
  /// login identifier (441); a stored email-shaped value is a legacy
  /// credential and is discarded on read.
  final String identifier;
  final String password;
}

/// The login identifier to store for biometric replay: the account's
/// phone when present, otherwise its username. NEVER an email - email
/// is not a login identifier (441). Returns null when the account has
/// no usable identifier; biometric enroll must not proceed then.
String? biometricLoginIdentifier({String? phone, String? username}) {
  if (phone != null && phone.isNotEmpty) return phone;
  if (username != null && username.isNotEmpty) return username;
  return null;
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
    required String identifier,
    required String password,
  }) async {
    final payload = jsonEncode({
      'identifier': identifier,
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
      // Current key is 'identifier'; entries written before the rename
      // carry the same value under the legacy 'email' key.
      final identifier =
          (decoded['identifier'] as String?) ?? (decoded['email'] as String?);
      final password = decoded['password'] as String?;
      if (identifier == null ||
          identifier.isEmpty ||
          password == null ||
          password.isEmpty) {
        return null;
      }
      // Only the technical phone identifier is dead; a real email is a login
      // identifier again (467, owner decision 2026-11-28).
      if (identifier.toLowerCase().endsWith('@delwaqty.app')) {
        // Legacy credential stored when email was a login identifier
        // (registration / settings enroll saved user.email). Email
        // login is gone (441), so this entry can never sign in:
        // discard it explicitly; the user re-enrolls with their
        // phone/username on the next password login or in settings.
        await clearForUser(userId);
        return null;
      }
      return BiometricCredentials(
        userId: userId,
        identifier: identifier,
        password: password,
      );
    } catch (_) {
      return null;
    }
  }

  Future<BiometricCredentials?> credentialsForIdentifier(
    String identifier,
  ) async {
    final userIds = await allUserIds();
    for (final uid in userIds) {
      final creds = await credentialsFor(uid);
      if (creds != null &&
          creds.identifier.toLowerCase() == identifier.toLowerCase()) {
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
