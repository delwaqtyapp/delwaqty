import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  throw UnimplementedError(
    'SecureStorageService must be initialized in main() using ProviderScope',
  );
});

class SecureStorageService {
  SecureStorageService(this._storage);

  final FlutterSecureStorage _storage;

  Future<void> write({required String key, required String value}) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> read({required String key}) async {
    return _storage.read(key: key);
  }

  Future<void> delete({required String key}) async {
    await _storage.delete(key: key);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
