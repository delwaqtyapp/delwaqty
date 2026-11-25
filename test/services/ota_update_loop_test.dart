import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delwaqty/core/config/app_mode_provider.dart';
import 'package:delwaqty/services/ota/ota_update_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('suppressAutoOtaOffer (update loop gate)', () {
    test(
      'suppresses only the exact handed-off version still not installed',
      () {
        // Installer opened for 12, still running 7: do not re-offer on resume.
        expect(
          suppressAutoOtaOffer(current: 7, latest: 12, handedOff: 12),
          isTrue,
        );
        // No handoff yet: offer normally.
        expect(
          suppressAutoOtaOffer(current: 7, latest: 12, handedOff: null),
          isFalse,
        );
        // Install completed (running build caught up): nothing to suppress.
        expect(
          suppressAutoOtaOffer(current: 12, latest: 12, handedOff: 12),
          isFalse,
        );
        // A newer build than the handed-off one always offers again.
        expect(
          suppressAutoOtaOffer(current: 7, latest: 13, handedOff: 12),
          isFalse,
        );
      },
    );
  });

  group('install handoff record', () {
    test('mark, read and clear roundtrip per flavor', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await otaInstallHandedOffVersion(AppFlavor.customer), isNull);
      await markOtaInstallHandedOff(AppFlavor.customer, 12);
      await markOtaInstallHandedOff(AppFlavor.driver, 9);
      expect(await otaInstallHandedOffVersion(AppFlavor.customer), 12);
      expect(await otaInstallHandedOffVersion(AppFlavor.driver), 9);
      await clearOtaInstallHandoff(AppFlavor.customer);
      expect(await otaInstallHandedOffVersion(AppFlavor.customer), isNull);
      expect(await otaInstallHandedOffVersion(AppFlavor.driver), 9);
    });
  });
}
