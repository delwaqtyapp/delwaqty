import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/provider/capability/domain/provider_capability.dart';

void main() {
  group('ProviderCategory.normalize', () {
    test('maps restaurant vocabulary', () {
      expect(ProviderCategory.normalize('restaurant'), ProviderCategory.restaurant);
      expect(ProviderCategory.normalize('food'), ProviderCategory.restaurant);
      expect(ProviderCategory.normalize('FOOD '), ProviderCategory.restaurant);
    });

    test('maps pharmacy / grocery / marketplace vocabulary', () {
      expect(ProviderCategory.normalize('pharmacy'), ProviderCategory.pharmacy);
      expect(ProviderCategory.normalize('grocery'), ProviderCategory.grocery);
      expect(ProviderCategory.normalize('supermarket'), ProviderCategory.grocery);
      expect(ProviderCategory.normalize('marketplace'), ProviderCategory.marketplace);
    });

    test('maps retail vocabulary', () {
      expect(ProviderCategory.normalize('electronics'), ProviderCategory.retail);
      expect(ProviderCategory.normalize('fashion'), ProviderCategory.retail);
      expect(ProviderCategory.normalize('flowers'), ProviderCategory.retail);
      expect(ProviderCategory.normalize('bakery'), ProviderCategory.retail);
      expect(ProviderCategory.normalize('general'), ProviderCategory.retail);
    });

    test('maps home services vocabulary', () {
      expect(ProviderCategory.normalize('plumbing'), ProviderCategory.homeServices);
      expect(ProviderCategory.normalize('electrical'), ProviderCategory.homeServices);
      expect(ProviderCategory.normalize('cleaning'), ProviderCategory.homeServices);
      expect(ProviderCategory.normalize('home_services'), ProviderCategory.homeServices);
    });

    test('unknown value falls back to unknown (safe minimal set)', () {
      expect(ProviderCategory.normalize(null), ProviderCategory.unknown);
      expect(ProviderCategory.normalize(''), ProviderCategory.unknown);
      expect(ProviderCategory.normalize('taxi'), ProviderCategory.unknown);
    });
  });

  group('resolveCapabilities', () {
    test('restaurant has orders/catalog/reviews but not services', () {
      final caps = resolveCapabilities(ProviderCategory.restaurant);
      expect(caps, containsAll({
        ProviderCapability.dashboard,
        ProviderCapability.orders,
        ProviderCapability.catalog,
        ProviderCapability.branches,
        ProviderCapability.offers,
        ProviderCapability.reviews,
        ProviderCapability.availability,
        ProviderCapability.deliveries,
        ProviderCapability.financial,
      }));
      expect(caps, isNot(contains(ProviderCapability.services)));
      expect(caps, isNot(contains(ProviderCapability.bookings)));
    });

    test('pharmacy has no deliveries', () {
      final caps = resolveCapabilities(ProviderCategory.pharmacy);
      expect(caps, contains(ProviderCapability.orders));
      expect(caps, isNot(contains(ProviderCapability.deliveries)));
    });

    test('grocery / marketplace / retail share the same capability set', () {
      final a = resolveCapabilities(ProviderCategory.grocery);
      final b = resolveCapabilities(ProviderCategory.marketplace);
      final c = resolveCapabilities(ProviderCategory.retail);
      expect(a, equals(b));
      expect(b, equals(c));
      expect(a, contains(ProviderCapability.deliveries));
    });

    test('home services has services/bookings/documents/verification, not orders', () {
      final caps = resolveCapabilities(ProviderCategory.homeServices);
      expect(caps, containsAll({
        ProviderCapability.services,
        ProviderCapability.bookings,
        ProviderCapability.documents,
        ProviderCapability.verification,
        ProviderCapability.availability,
        ProviderCapability.reviews,
      }));
      expect(caps, isNot(contains(ProviderCapability.orders)));
      expect(caps, isNot(contains(ProviderCapability.catalog)));
      expect(caps, isNot(contains(ProviderCapability.branches)));
    });

    test('unknown yields the minimal safe capability set', () {
      final caps = resolveCapabilities(ProviderCategory.unknown);
      expect(caps, {
        ProviderCapability.dashboard,
        ProviderCapability.financial,
        ProviderCapability.notifications,
        ProviderCapability.support,
      });
    });
  });

  group('hasCapability', () {
    test('checks membership', () {
      final caps = resolveCapabilities(ProviderCategory.restaurant);
      expect(hasCapability(caps, ProviderCapability.orders), isTrue);
      expect(hasCapability(caps, ProviderCapability.services), isFalse);
    });
  });
}
