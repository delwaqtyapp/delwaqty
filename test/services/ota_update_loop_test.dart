import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delwaqty/core/config/app_mode_provider.dart';
import 'package:delwaqty/services/ota/ota_update_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final t0 = DateTime(2026, 11, 25, 12);

  group('suppressAutoOtaOffer (update loop gate)', () {
    test('suppresses only the handed-off version still not installed, within '
        'the cooldown', () {
      // Installer opened for 12 two hours ago, still running 7: do not
      // re-offer on every resume (cancelled install case).
      expect(
        suppressAutoOtaOffer(
          current: 7,
          latest: 12,
          handedOffVersion: 12,
          handedOffAt: t0.subtract(const Duration(hours: 2)),
          now: t0,
        ),
        isTrue,
      );
      // No handoff yet: offer normally.
      expect(
        suppressAutoOtaOffer(
          current: 7,
          latest: 12,
          handedOffVersion: null,
          handedOffAt: null,
          now: t0,
        ),
        isFalse,
      );
      // Install completed (running build caught up): nothing to suppress.
      expect(
        suppressAutoOtaOffer(
          current: 12,
          latest: 12,
          handedOffVersion: 12,
          handedOffAt: t0,
          now: t0,
        ),
        isFalse,
      );
      // A newer build than the handed-off one always offers again.
      expect(
        suppressAutoOtaOffer(
          current: 7,
          latest: 13,
          handedOffVersion: 12,
          handedOffAt: t0,
          now: t0,
        ),
        isFalse,
      );
    });

    test('cooldown expiry re-offers a cancelled or failed install', () {
      // Installer opened for 12 nine hours ago, still running 7: the offer
      // comes back after the 8h cooldown instead of being suppressed forever.
      expect(
        suppressAutoOtaOffer(
          current: 7,
          latest: 12,
          handedOffVersion: 12,
          handedOffAt: t0.subtract(const Duration(hours: 9)),
          now: t0,
        ),
        isFalse,
      );
      // Exactly at the boundary the offer returns.
      expect(
        suppressAutoOtaOffer(
          current: 7,
          latest: 12,
          handedOffVersion: 12,
          handedOffAt: t0.subtract(kOtaInstallHandoffCooldown),
          now: t0,
        ),
        isFalse,
      );
    });
  });

  group('install handoff record', () {
    test('mark, read across restart, and clear roundtrip per flavor', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await otaInstallHandoff(AppFlavor.customer), isNull);
      await markOtaInstallHandedOff(AppFlavor.customer, 12);
      final handoff = await otaInstallHandoff(AppFlavor.customer);
      expect(handoff?.$1, 12);
      expect(handoff?.$2, isNotNull);

      // Simulate a restart: rebuild the store from the persisted values.
      final raw = (await SharedPreferences.getInstance()).getString(
        'ota_install_handed_off_customer',
      );
      SharedPreferences.setMockInitialValues({
        'ota_install_handed_off_customer': raw ?? '',
      });
      expect((await otaInstallHandoff(AppFlavor.customer))?.$1, 12);

      await markOtaInstallHandedOff(AppFlavor.driver, 9);
      await clearOtaInstallHandoff(AppFlavor.customer);
      expect(await otaInstallHandoff(AppFlavor.customer), isNull);
      expect((await otaInstallHandoff(AppFlavor.driver))?.$1, 9);
    });

    test('a malformed record reads as no handoff', () async {
      SharedPreferences.setMockInitialValues({
        'ota_install_handed_off_customer': 'garbage',
      });
      expect(await otaInstallHandoff(AppFlavor.customer), isNull);
    });
  });
}
