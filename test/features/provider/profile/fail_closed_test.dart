import 'package:delwaqty/features/provider/capability/domain/provider_capability.dart';
import 'package:delwaqty/features/provider/capability/domain/provider_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/provider/capability/presentation/providers/provider_capability_providers.dart';

void main() {
  test('malformed business profile is unknown and pending is not approved', () {
    final malformed = ProviderBusinessProfile.fromJson({'id': 'x'});
    expect(malformed.categoryType, 'unknown');
    expect(malformed.isApproved, isFalse);
    expect(const ProviderProfilesState().activeCategory, 'unknown');
    final pending = ProviderBusinessProfile.fromJson({
      'id': 'y',
      'category_type': 'restaurant',
      'status': 'pending',
    });
    expect(pending.isApproved, isFalse);
  });
  for (final p in [ProviderProfile.loading(), ProviderProfile.failed()]) {
    test('not-ready profile fails closed (${p.status.name})', () {
      expect(p.isReady, isFalse);
      expect(p.allowsRoute('/merchant-dashboard'), isTrue);
      expect(p.allowsRoute('/provider-financial-center'), isTrue);
      for (final r in [
        '/provider-services',
        '/provider-orders',
        '/provider-catalog',
        '/merchant-dashboard/reviews',
        '/provider-documents',
      ]) {
        expect(p.allowsRoute(r), isFalse, reason: r);
      }
    });
  }

  test('unknown category gets only dashboard and financial', () {
    final p = ProviderProfile.forCategory(ProviderCategory.unknown);
    expect(p.tabs, [ProviderTabIds.dashboard, ProviderTabIds.financial]);
    expect(p.has(ProviderCapability.orders), isFalse);
    expect(p.has(ProviderCapability.catalog), isFalse);
  });

  test('route map covers reviews, availability, documents, verification', () {
    final home = ProviderProfile.forCategory(ProviderCategory.homeServices);
    expect(home.allowsRoute('/provider-availability'), isTrue);
    final rest = ProviderProfile.forCategory(ProviderCategory.restaurant);
    expect(rest.allowsRoute('/provider-documents'), isFalse);
  });
}
