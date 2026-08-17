import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/core/deep_link/deep_link_resolver.dart';

void main() {
  group('DeepLinkResolver.resolve', () {
    test('resolves login-callback host on the io.delwaqty scheme', () {
      expect(
        DeepLinkResolver.resolve('io.delwaqty://login-callback'),
        DeepLinkRoute.loginCallback,
      );
    });

    test('resolves login-callback with query parameters', () {
      expect(
        DeepLinkResolver.resolve(
          'io.delwaqty://login-callback?code=abc&state=xyz',
        ),
        DeepLinkRoute.loginCallback,
      );
    });

    test('returns null for unknown hosts on the scheme', () {
      expect(DeepLinkResolver.resolve('io.delwaqty://profile'), isNull);
      expect(DeepLinkResolver.resolve('io.delwaqty://'), isNull);
    });

    test('returns null for foreign schemes', () {
      expect(DeepLinkResolver.resolve('https://delwaqty.app/login'), isNull);
      expect(DeepLinkResolver.resolve('deeplink://login-callback'), isNull);
    });

    test('rejects host variants that are not the exact callback host', () {
      expect(DeepLinkResolver.resolve('io.delwaqty://login'), isNull);
      expect(DeepLinkResolver.resolve('io.delwaqty://callback'), isNull);
      expect(DeepLinkResolver.resolve('io.delwaqty://login-callbackx'), isNull);
    });
  });
}