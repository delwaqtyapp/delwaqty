import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/core/module/feature_registry.dart';
import 'package:delwaqty/customer/module_registry.dart';

void main() {
  setUpAll(() {
    registerAllModules();
  });

  test('glass side menu registers all customer feature entries', () {
    final ids =
        FeatureRegistry.instance.allDrawerEntries.map((e) => e.id).toList();

    expect(
      ids,
      containsAll([
        'home',
        'services',
        'notifications',
        'profile',
        'orders',
        'wallet',
        'direct-delivery',
        'my-complaints',
        'rewards',
      ]),
    );
    expect(ids, isNot(contains('search')));
  });
}