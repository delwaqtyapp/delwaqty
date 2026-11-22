import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/services/ota/ota_update_manager.dart';

void main() {
  test('rolling metadata requests have distinct cache keys', () {
    const url = 'https://example.invalid/development/versions.json';
    final first = otaFreshUri(url, requestId: 8);
    final second = otaFreshUri(url, requestId: 9);
    expect(first.path, '/development/versions.json');
    expect(first.queryParameters['ota'], '8');
    expect(second.queryParameters['ota'], '9');
    expect(first, isNot(second));
  });

  test('cache key preserves existing query parameters', () {
    final uri = otaFreshUri('https://example.invalid/latest?x=y', requestId: 8);
    expect(uri.queryParameters, {'x': 'y', 'ota': '8'});
  });

  test('visible version is independent from internal OTA build', () {
    final manifest = OtaManifest.fromJson({
      'channels': {
        'customer': {
          'version': 8,
          'versionName': '1.0.0',
          'apk': 'delwaqty-customer-8.apk',
          'notes': '',
          'sha256': 'a' * 64,
        },
      },
    });
    expect(manifest.channels['customer']!.version, 8);
    expect(manifest.channels['customer']!.versionName, '1.0.0');
    expect(manifest.channels['customer']!.apk, 'delwaqty-customer-8.apk');
  });
}
