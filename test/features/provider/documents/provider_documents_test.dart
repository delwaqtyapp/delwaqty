import 'package:flutter_test/flutter_test.dart';

import 'package:delwaqty/features/provider/capability/domain/provider_capability.dart';
import 'package:delwaqty/features/provider/documents/presentation/providers/provider_documents_providers.dart';

void main() {
  group('Provider Documents capability mapping', () {
    test('homeServices exposes documents capability', () {
      final caps = resolveCapabilities(ProviderCategory.homeServices);
      expect(caps, contains(ProviderCapability.documents));
    });

    test('restaurant does not expose documents capability', () {
      final caps = resolveCapabilities(ProviderCategory.restaurant);
      expect(caps, isNot(contains(ProviderCapability.documents)));
    });

    test('document type catalog is capability-driven and fixed', () {
      expect(
        providerDocTypes.map((e) => e.key),
        containsAll(['identity', 'license', 'certification', 'insurance']),
      );
    });
  });
}
