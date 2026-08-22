import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/core/auth/platform_capabilities.dart';

PlatformCapabilities capsFrom({
  bool customer = false,
  bool driver = false,
  bool provider = false,
  bool merchant = false,
  bool admin = false,
  bool owner = false,
}) =>
    PlatformCapabilities(
      customer: customer,
      driver: driver,
      provider: provider,
      merchant: merchant,
      admin: admin,
      owner: owner,
    );

void main() {
  group('PlatformCapabilities.fromJson', () {
    test('maps raw backend flags', () {
      final c = PlatformCapabilities.fromJson({
        'customer': true,
        'driver': false,
        'provider': false,
        'merchant': true,
        'admin': true,
        'owner': true,
      });
      expect(c.customer, isTrue);
      expect(c.driver, isFalse);
      expect(c.merchant, isTrue);
      expect(c.owner, isTrue);
    });

    test('derives can_use_* from explicit then legacy flags', () {
      final c = PlatformCapabilities.fromJson({
        'customer': true,
        'driver': true,
        'admin': true,
      });
      expect(c.canUseCustomer, isTrue);
      expect(c.canUseDelivery, isTrue);
      expect(c.canUseAdmin, isTrue);
      expect(c.canUseProvider, isFalse);
    });

    test('falls back to legacy flags when can_use_* absent', () {
      final c = PlatformCapabilities.fromJson({'provider': true});
      expect(c.canUseProvider, isTrue);
    });
  });

  group('OwnerContextResolver', () {
    test('Owner is authorized for every context even with no ops rows', () {
      final r = OwnerContextResolver(capsFrom(owner: true, customer: true, admin: true));
      expect(r.authorizedCustomer, isTrue);
      expect(r.authorizedDelivery, isTrue);
      expect(r.authorizedProvider, isTrue);
      expect(r.authorizedAdmin, isTrue);
      expect(r.availableContexts, containsAll(['customer', 'delivery', 'provider', 'admin']));
    });

    test('normal Delivery user is NOT admin/provider', () {
      final r = OwnerContextResolver(capsFrom(customer: true, driver: true));
      expect(r.authorizedDelivery, isTrue);
      expect(r.authorizedProvider, isFalse);
      expect(r.authorizedAdmin, isFalse);
    });

    test('normal Provider user is NOT delivery/admin', () {
      final r = OwnerContextResolver(capsFrom(customer: true, provider: true, merchant: true));
      expect(r.authorizedProvider, isTrue);
      expect(r.authorizedDelivery, isFalse);
      expect(r.authorizedAdmin, isFalse);
    });

    test('customer-only user has no operational contexts', () {
      final r = OwnerContextResolver(capsFrom(customer: true));
      expect(r.authorizedCustomer, isTrue);
      expect(r.authorizedDelivery, isFalse);
      expect(r.authorizedProvider, isFalse);
      expect(r.authorizedAdmin, isFalse);
    });
  });
}
