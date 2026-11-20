import 'package:delwaqty/features/customer/driver/domain/repositories/dispatch_repository.dart';
import 'package:delwaqty/features/customer/driver/presentation/providers/dispatch_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

class FakeDispatch extends Fake implements DispatchRepository {
  bool online = false;
  int renewals = 0;
  final writes = <bool>[];
  @override
  Future<bool> getOnline(String id) async => online;
  @override
  Future<void> setOnline(
    String id,
    bool value, {
    double? lat,
    double? lng,
  }) async {
    online = value;
    writes.add(value);
  }

  @override
  Future<void> updateLocation(
    String id,
    double lat,
    double lng, {
    double? heading,
    double? speed,
  }) async {
    renewals++;
  }
}

class FakePositionSource extends DriverPositionSource {
  bool fail = false;
  int reads = 0;
  @override
  Future<Position> current() async {
    reads++;
    if (fail) throw StateError('location_unavailable');
    return Position(
      latitude: 30,
      longitude: 31,
      timestamp: DateTime.now(),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

void main() {
  testWidgets(
    'restores server presence and renews stationary driver with fresh reads',
    (tester) async {
      final repo = FakeDispatch()..online = true;
      final gps = FakePositionSource();
      final container = ProviderContainer(
        overrides: [
          dispatchRepositoryProvider.overrideWithValue(repo),
          driverPositionSourceProvider.overrideWithValue(gps),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(driverOnlineProvider('driver').notifier);
      await tester.pump();
      expect(container.read(driverOnlineProvider('driver')).value, true);
      expect(gps.reads, 1);
      await tester.pump(const Duration(seconds: 46));
      await tester.pump();
      expect(repo.renewals, 1);
      expect(gps.reads, 2);
      await notifier.goOffline();
      await tester.pump(const Duration(seconds: 46));
      expect(repo.renewals, 1);
      expect(repo.online, false);
    },
  );
  testWidgets('failed fresh GPS blocks online and reconciles server offline', (
    tester,
  ) async {
    final repo = FakeDispatch();
    final gps = FakePositionSource()..fail = true;
    final container = ProviderContainer(
      overrides: [
        dispatchRepositoryProvider.overrideWithValue(repo),
        driverPositionSourceProvider.overrideWithValue(gps),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(driverOnlineProvider('driver').notifier);
    await tester.pump();
    await notifier.goOnline();
    expect(repo.writes, [false]);
    expect(container.read(driverOnlineProvider('driver')).hasError, true);
    expect(repo.online, false);
  });
  testWidgets(
    'heartbeat failure stops dispatchable state instead of resending cached GPS',
    (tester) async {
      final repo = FakeDispatch()..online = true;
      final gps = FakePositionSource();
      final container = ProviderContainer(
        overrides: [
          dispatchRepositoryProvider.overrideWithValue(repo),
          driverPositionSourceProvider.overrideWithValue(gps),
        ],
      );
      addTearDown(container.dispose);
      container.read(driverOnlineProvider('driver'));
      await tester.pump();
      gps.fail = true;
      await tester.pump(const Duration(seconds: 46));
      await tester.pump();
      expect(repo.renewals, 0);
      expect(repo.online, false);
      expect(container.read(driverOnlineProvider('driver')).hasError, true);
    },
  );
}
