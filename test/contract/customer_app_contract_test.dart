import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards customer app invariants across l10n, checkout, cart, wallet,
/// home services, delivery, privacy settings, and dead-code cleanup.
void main() {
  String read(String path) => File(path).readAsStringSync();

  group('l10n and pubspec contract', () {
    test('app_en.arb and app_ar.arb have zero duplicate top-level keys', () {
      final topLevelKeyPattern = RegExp(r'^  "([^"]+)"\s*:', multiLine: true);
      for (final path in ['lib/l10n/app_en.arb', 'lib/l10n/app_ar.arb']) {
        final src = read(path);
        final seen = <String>{};
        final duplicates = <String>[];
        for (final match in topLevelKeyPattern.allMatches(src)) {
          final key = match.group(1)!;
          if (!seen.add(key)) {
            duplicates.add(key);
          }
        }
        expect(
          duplicates,
          isEmpty,
          reason: '$path contains duplicate top-level keys: $duplicates',
        );
      }
    });

    test('app_en.arb and app_ar.arb have 100% key parity with app_localizations.dart', () {
      final en =
          jsonDecode(read('lib/l10n/app_en.arb')) as Map<String, dynamic>;
      final ar =
          jsonDecode(read('lib/l10n/app_ar.arb')) as Map<String, dynamic>;
      final enKeys = en.keys.where((k) => !k.startsWith('@')).toSet();
      final arKeys = ar.keys.where((k) => !k.startsWith('@')).toSet();

      final locSrc = read('lib/l10n/app_localizations.dart');
      final locKeyPattern = RegExp(
        r'^\s+String (?:get )?([a-zA-Z0-9_]+)(?:;|\()',
        multiLine: true,
      );
      final locKeys = locKeyPattern
          .allMatches(locSrc)
          .map((m) => m.group(1)!)
          .toSet();

      expect(
        enKeys.difference(arKeys),
        isEmpty,
        reason: 'keys in app_en.arb missing from app_ar.arb',
      );
      expect(
        arKeys.difference(enKeys),
        isEmpty,
        reason: 'keys in app_ar.arb missing from app_en.arb',
      );
      expect(
        enKeys.difference(locKeys),
        isEmpty,
        reason: 'keys in app_en.arb missing from app_localizations.dart',
      );
      expect(
        locKeys.difference(enKeys),
        isEmpty,
        reason: 'keys in app_localizations.dart missing from app_en.arb',
      );
    });

    test('pubspec.yaml does not have a duplicate generate: key', () {
      final src = read('pubspec.yaml');
      final matches = RegExp(
        r'^\s*generate\s*:',
        multiLine: true,
      ).allMatches(src);
      expect(
        matches.length,
        1,
        reason: 'pubspec.yaml must declare generate: exactly once',
      );
    });
  });

  group('commerce and checkout contract', () {
    test('ProductDetailPage does not call getProductById() inside build() and '
        'passes modifierTotal and specialInstructions to CartItem', () {
      const path =
          'lib/features/customer/commerce/presentation/pages/product_detail_page.dart';
      final src = read(path);
      final buildIdx = src.indexOf('Widget build(BuildContext context)');
      expect(buildIdx, isNot(-1), reason: 'build() not found in $path');

      final buildAndAfter = src.substring(buildIdx);
      expect(
        buildAndAfter.contains('getProductById('),
        isFalse,
        reason: '$path must not call getProductById() inside build()',
      );

      final cartItemIdx = src.indexOf('CartItem(');
      expect(cartItemIdx, isNot(-1), reason: 'CartItem( not found in $path');
      final cartItemEnd = (cartItemIdx + 600).clamp(0, src.length);
      final cartItemBlock = src.substring(cartItemIdx, cartItemEnd);
      expect(
        cartItemBlock.contains('modifierTotal'),
        isTrue,
        reason: '$path must pass modifierTotal to CartItem',
      );
      expect(
        cartItemBlock.contains('specialInstructions'),
        isTrue,
        reason: '$path must pass specialInstructions to CartItem',
      );
    });

    test('CheckoutPage validates empty address in _placeOrder and invalidates '
        'cartProvider', () {
      const path =
          'lib/features/customer/commerce/presentation/pages/checkout_page.dart';
      final src = read(path);
      final placeOrderIdx = src.indexOf('Future<void> _placeOrder(');
      expect(
        placeOrderIdx,
        isNot(-1),
        reason: '_placeOrder not found in $path',
      );
      final placeOrderBody = src.substring(
        placeOrderIdx,
        (placeOrderIdx + 600).clamp(0, src.length),
      );
      expect(
        placeOrderBody.contains('_addressController.text.trim()') &&
            placeOrderBody.contains('.isEmpty'),
        isTrue,
        reason: '$path _placeOrder must validate empty trimmed address',
      );
      expect(
        src.contains('ref.invalidate(cartProvider)'),
        isTrue,
        reason: '$path must invalidate cartProvider',
      );
      expect(
        src.contains('ref.invalidate(_cartFutureProvider)'),
        isFalse,
        reason: '$path must not invalidate _cartFutureProvider',
      );
    });

    test('OrderCompletedPage PopScope defines onPopInvokedWithResult', () {
      const path =
          'lib/features/customer/commerce/presentation/pages/order_completed_page.dart';
      final src = read(path);
      expect(
        src.contains('PopScope('),
        isTrue,
        reason: 'PopScope not found in $path',
      );
      expect(
        src.contains('onPopInvokedWithResult:'),
        isTrue,
        reason: '$path PopScope must define onPopInvokedWithResult',
      );
    });
  });

  group('confirmation dialogs contract', () {
    void expectConfirmation(String path, String action) {
      final src = read(path);
      final idx = src.indexOf(action);
      expect(idx, isNot(-1), reason: '$action not found in $path');
      final window = src.substring(
        (idx - 2500).clamp(0, src.length),
        (idx + 2500).clamp(0, src.length),
      );
      expect(
        window.contains('showDialog<bool>') ||
            window.contains('ConfirmDialog') ||
            window.contains('showConfirmDialog'),
        isTrue,
        reason: '"$action" in $path must ask for confirmation first',
      );
    }

    test('CartPage confirms before clearing cart', () {
      expectConfirmation(
        'lib/features/customer/commerce/presentation/pages/cart_page.dart',
        '.clear()',
      );
    });

    test('WalletTopUpPage confirms before topping up wallet', () {
      expectConfirmation(
        'lib/features/customer/wallet/presentation/pages/wallet_topup_page.dart',
        '.topUp(',
      );
    });

    test('ServiceBookingPage confirms before booking a service', () {
      expectConfirmation(
        'lib/features/customer/home_services/presentation/pages/'
            'service_booking_page.dart',
        '.createBooking(',
      );
    });

    test(
      'FingerprintLoginPage confirms before removing biometric credentials',
      () {
        expectConfirmation(
          'lib/features/customer/settings/presentation/pages/privacy/'
              'fingerprint_login_page.dart',
          '_removeCredential(',
        );
      },
    );
  });

  group('delivery and privacy contract', () {
    test(
      'SupabaseDeliveryDataSource.rateDelivery does not call rate_passenger',
      () {
        const path =
            'lib/features/customer/delivery/data/datasources/remote/'
            'supabase_delivery_data_source.dart';
        final src = read(path);
        final idx = src.indexOf('Future<void> rateDelivery(');
        expect(idx, isNot(-1), reason: 'rateDelivery not found in $path');
        final body = src.substring(idx, (idx + 800).clamp(0, src.length));
        expect(
          body.contains('rate_passenger'),
          isFalse,
          reason: '$path rateDelivery must not call rate_passenger',
        );
      },
    );

    test(
      'DeliveryTrackingPage does not use onboardingNext as a minutes unit',
      () {
        const path =
            'lib/features/customer/delivery/presentation/pages/'
            'delivery_tracking_page.dart';
        final src = read(path);
        expect(
          src.contains('onboardingNext'),
          isFalse,
          reason: '$path must not use onboardingNext',
        );
      },
    );

    test('LocationSharingPage does not declare late final SharedPreferences _prefs', () {
      const path =
          'lib/features/customer/settings/presentation/pages/privacy/'
          'location_sharing_page.dart';
      final src = read(path);
      expect(
        RegExp(r'late\s+final\s+SharedPreferences\s+_prefs').hasMatch(src),
        isFalse,
        reason: '$path must not declare late final SharedPreferences _prefs',
      );
    });
  });

  group('dead files contract', () {
    test('deleted dead files do not exist under lib/', () {
      const deadFiles = <String>{
        'car_product.freezed.dart',
        'car_product.g.dart',
        'place_row.dart',
        'destination_search_controller.dart',
      };
      final found = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) {
            final name = f.uri.pathSegments.last;
            return deadFiles.contains(name);
          })
          .map((f) => f.path)
          .toList();
      expect(found, isEmpty, reason: 'deleted dead files still exist: $found');
    });
  });
}
