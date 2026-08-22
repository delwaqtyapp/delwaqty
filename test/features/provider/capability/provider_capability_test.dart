import 'package:delwaqty/features/provider/capability/domain/provider_capability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProviderCategory.owner capability resolution', () {
    test('owner is granted the full provider capability set', () {
      final caps = resolveCapabilities(ProviderCategory.owner);
      expect(caps, contains(ProviderCapability.dashboard));
      expect(caps, contains(ProviderCapability.orders));
      expect(caps, contains(ProviderCapability.catalog));
      expect(caps, contains(ProviderCapability.financial));
      expect(caps, contains(ProviderCapability.notifications));
      expect(caps, contains(ProviderCapability.verification));
      expect(caps, contains(ProviderCapability.documents));
      // Owner must reach operational UI without a registration gate.
      expect(caps.length, greaterThan(10));
    });

    test('normalize maps owner literal', () {
      expect(ProviderCategory.normalize('owner'), ProviderCategory.owner);
    });
  });
}
