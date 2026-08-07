import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:delwaqty/core/constants/storage_keys.dart';
import 'package:delwaqty/data/datasources/local/shared_preferences_service.dart';
import 'package:delwaqty/features/auth/domain/saved_account.dart';

final savedAccountsStoreProvider = Provider<SavedAccountsStore>((ref) {
  return SavedAccountsStore(
    ref.watch(sharedPreferencesProvider),
    const FlutterSecureStorage(),
  );
});

class SavedAccountsStore {
  SavedAccountsStore(this._prefs, this._secureStorage);

  final SharedPreferencesService _prefs;
  final FlutterSecureStorage _secureStorage;

  static const String _biometricKeyPrefix = 'biometric_password_';

  Future<List<SavedAccount>> loadAccounts() async {
    final raw = _prefs.getString(key: StorageKeys.savedAccounts);
    if (raw == null || raw.isEmpty) return <SavedAccount>[];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return List<SavedAccount>.unmodifiable(
        decoded
            .whereType<Map<String, dynamic>>()
            .map(SavedAccount.fromJson)
            .where((account) => account.email.trim().isNotEmpty),
      );
    } catch (_) {
      return <SavedAccount>[];
    }
  }

  Future<List<SavedAccount>> saveAccount({
    required String email,
    String displayName = '',
  }) async {
    final normalized = email.trim().toLowerCase();
    final accounts = [...await loadAccounts()];
    final index = accounts.indexWhere((a) => a.key == normalized);
    final account = SavedAccount(
      email: normalized,
      displayName: displayName,
      hasBiometric: index >= 0 ? accounts[index].hasBiometric : false,
    );
    if (index >= 0) {
      accounts[index] = account;
    } else {
      accounts.add(account);
    }
    await _writeAccounts(accounts);
    return accounts;
  }

  Future<List<SavedAccount>> removeAccount(String email) async {
    final normalized = email.trim().toLowerCase();
    final accounts = [...await loadAccounts()];
    accounts.removeWhere((a) => a.key == normalized);
    await _writeAccounts(accounts);
    await _secureStorage.delete(key: _biometricKey(normalized));
    return accounts;
  }

  Future<void> setBiometric({
    required String email,
    required String password,
    required bool enabled,
  }) async {
    final normalized = email.trim().toLowerCase();
    final accounts = [...await loadAccounts()];
    final index = accounts.indexWhere((a) => a.key == normalized);
    if (index < 0) {
      accounts.add(
        SavedAccount(email: normalized, hasBiometric: enabled),
      );
    } else {
      accounts[index] = accounts[index].copyWith(hasBiometric: enabled);
    }
    await _writeAccounts(accounts);
    if (enabled) {
      await _secureStorage.write(
        key: _biometricKey(normalized),
        value: password,
      );
    } else {
      await _secureStorage.delete(key: _biometricKey(normalized));
    }
  }

  Future<String?> biometricPassword(String email) {
    return _secureStorage.read(key: _biometricKey(email));
  }

  Future<SavedAccount?> biometricAccount() async {
    final accounts = await loadAccounts();
    for (final account in accounts) {
      if (account.hasBiometric) return account;
    }
    return null;
  }

  String _biometricKey(String email) =>
      '$_biometricKeyPrefix${email.trim().toLowerCase()}';

  Future<void> _writeAccounts(List<SavedAccount> accounts) async {
    await _prefs.saveString(
      key: StorageKeys.savedAccounts,
      value: jsonEncode(accounts.map((a) => a.toJson()).toList()),
    );
  }
}
