import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/constants/storage_keys.dart';
import 'package:delwaqty/data/datasources/local/shared_preferences_service.dart';
import 'package:delwaqty/features/_shared/auth/domain/saved_account.dart';

final savedAccountsStoreProvider = Provider<SavedAccountsStore>((ref) {
  return SavedAccountsStore(ref.watch(sharedPreferencesProvider));
});

class SavedAccountsStore {
  SavedAccountsStore(this._prefs);

  final SharedPreferencesService _prefs;

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
    final account = SavedAccount(email: normalized, displayName: displayName);
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
    return accounts;
  }

  Future<void> _writeAccounts(List<SavedAccount> accounts) async {
    await _prefs.saveString(
      key: StorageKeys.savedAccounts,
      value: jsonEncode(accounts.map((a) => a.toJson()).toList()),
    );
  }
}
