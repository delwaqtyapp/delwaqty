import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delwaqty/services/push_notification/device_identity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final uuidPattern =
      RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

  setUp(() {
    DeviceIdentity.debugResetForTest();
  });

  group('DeviceIdentity', () {
    test('returns a v4 UUID', () async {
      SharedPreferences.setMockInitialValues({});
      final id = await DeviceIdentity.getOrCreate();

      expect(id, matches(uuidPattern));
    });

    test('persists and returns the same id on later calls', () async {
      SharedPreferences.setMockInitialValues({});
      final first = await DeviceIdentity.getOrCreate();
      final second = await DeviceIdentity.getOrCreate();

      expect(second, first);
    });

    test('reuses an existing stored id', () async {
      const stored = 'a1b2c3d4-1111-4a2b-8c3d-4e5f6a7b8c9d';
      SharedPreferences.setMockInitialValues({'delwaqty_device_id': stored});

      final id = await DeviceIdentity.getOrCreate();
      expect(id, stored);
    });

    test('two fresh identities are different', () async {
      SharedPreferences.setMockInitialValues({});
      final a = await DeviceIdentity.getOrCreate();
      DeviceIdentity.debugResetForTest();
      SharedPreferences.setMockInitialValues({});
      final b = await DeviceIdentity.getOrCreate();

      expect(a, isNot(b));
    });
  });
}
