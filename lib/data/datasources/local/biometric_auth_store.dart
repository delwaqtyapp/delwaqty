import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricCredentials {
  const BiometricCredentials({required this.email, required this.password});

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

  Future<void> saveCredentials({
    required String userId,
    required String email,
    required String password,
  }) async {
    final payload = jsonEncode({'email': email, 'password': password});
    await _secureStorage.write(key: _credentialKey(userId), value: payload);
    await _secureStorage.write(key: _activeUserKey, value: userId);
  }

  Future<BiometricCredentials?> credentialsFor(String userId) async {
    final raw = await _secureStorage.read(key: _credentialKey(userId));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final email = decoded['email'] as String?;
      final password = decoded['password'] as String?;
      if (email == null || email.isEmpty || password == null || password.isEmpty) {
        return null;
      }
      return BiometricCredentials(email: email, password: password);
    } catch (_) {
      return null;
    }
  }

  Future<BiometricCredentials?> activeCredentials() async {
    final userId = await _secureStorage.read(key: _activeUserKey);
    if (userId == null || userId.isEmpty) return null;
    return credentialsFor(userId);
  }

  Future<void> clearActive() async {
    final userId = await _secureStorage.read(key: _activeUserKey);
    await _secureStorage.delete(key: _activeUserKey);
    if (userId != null && userId.isNotEmpty) {
      await _secureStorage.delete(key: _credentialKey(userId));
    }
  }

  String _credentialKey(String userId) => '$_credentialKeyPrefix$userId';
}
