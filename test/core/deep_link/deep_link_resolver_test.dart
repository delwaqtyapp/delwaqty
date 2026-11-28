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
      expect(
        DeepLinkResolver.resolve('io.delwaqty.admin://login-callback'),
        DeepLinkRoute.loginCallback,
      );
      expect(DeepLinkResolver.resolve('io.delwaqty.admin://profile'), isNull);
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

    test('activation email redirect is its own route; OAuth return is not', () {
      expect(
        DeepLinkResolver.resolve(
          'io.delwaqty://login-callback/activated#access_token=a&refresh_token=b',
        ),
        DeepLinkRoute.emailActivated,
      );
      expect(
        DeepLinkResolver.resolve(
          'io.delwaqty://login-callback/activated?code=abc',
        ),
        DeepLinkRoute.emailActivated,
      );
      // No session in the link: must not sign anyone out.
      expect(
        DeepLinkResolver.resolve('io.delwaqty://login-callback/activated'),
        DeepLinkRoute.loginCallback,
      );
      expect(
        DeepLinkResolver.resolve('io.delwaqty://login-callback?code=abc'),
        DeepLinkRoute.loginCallback,
      );
      expect(
        DeepLinkResolver.resolve('io.delwaqty://login-callback/other'),
        DeepLinkRoute.loginCallback,
      );
    });
  });
}
