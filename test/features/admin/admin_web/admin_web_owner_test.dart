import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/admin/admin_web/presentation/pages/admin_categories_page.dart';

void main() {
  group('resolveAdminWebOwner', () {
    test('no session is not owner and never queries', () async {
      var called = false;
      final r = await resolveAdminWebOwner(null, (_) async {
        called = true;
        return true;
      });
      expect(r, isFalse);
      expect(called, isFalse);
    });

    test('session uses the role lookup result', () async {
      expect(await resolveAdminWebOwner('u1', (_) async => true), isTrue);
      expect(await resolveAdminWebOwner('u1', (_) async => false), isFalse);
    });
  });
}
