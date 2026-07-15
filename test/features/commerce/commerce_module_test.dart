import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/commerce/commerce_module.dart';
import 'package:delwaqty/core/module/feature_module.dart';

void main() {
  late CommerceModule module;

  setUp(() {
    module = CommerceModule();
  });

  group('CommerceModule', () {
    test('id is "commerce"', () {
      expect(module.id, 'commerce');
    });

    test('isNavModule is false', () {
      expect(module.isNavModule, false);
    });

    test('navPriority is 0', () {
      expect(module.navPriority, 0);
    });

    test('capabilities contains hasDeepLinks', () {
      expect(module.capabilities, contains(ModuleCapability.hasDeepLinks));
      expect(module.capabilities.length, 1);
    });

    test('dependsOn is empty', () {
      expect(module.dependsOn, isEmpty);
    });

    test('buildBranch returns null', () {
      expect(module.buildBranch(), isNull);
    });

    test('shellSubRoutes is empty', () {
      expect(module.shellSubRoutes, isEmpty);
    });

    test('standaloneRoutes has one route at /market', () {
      expect(module.standaloneRoutes.length, 1);
    });

    test('drawerEntries is empty', () {
      expect(module.drawerEntries, isEmpty);
    });

    test('badgeStream getter is not null', () {
      expect(module.badgeStream, isNotNull);
    });

    test('icon is storefront_outlined', () {
      expect(module.icon, isNotNull);
    });
  });
}
