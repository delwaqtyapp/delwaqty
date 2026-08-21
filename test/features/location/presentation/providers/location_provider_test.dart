import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delwaqty/features/customer/location/presentation/providers/location_provider.dart';
import 'package:delwaqty/services/logger/app_logger.dart';

class MockGeolocatorPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements GeolocatorPlatform {}

class MockAppLogger extends Mock implements AppLogger {}

Position positionWith(
  double lat,
  double lng,
  double accuracy, [
  DateTime? timestamp,
]) => Position(
  longitude: lng,
  latitude: lat,
  timestamp: timestamp ?? DateTime.now(),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

AndroidPosition androidPositionWith(
  double lat,
  double lng,
  double accuracy, {
  double satellitesUsedInFix = 0,
  DateTime? timestamp,
}) => AndroidPosition(
  longitude: lng,
  latitude: lat,
  timestamp: timestamp ?? DateTime.now(),
  accuracy: accuracy,
  altitude: 0.0,
  altitudeAccuracy: 0.0,
  heading: 0.0,
  headingAccuracy: 0.0,
  speed: 0.0,
  speedAccuracy: 0.0,
  satelliteCount: satellitesUsedInFix,
  satellitesUsedInFix: satellitesUsedInFix,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockGeolocatorPlatform mockPlatform;
  late MockAppLogger mockLogger;
  late GeolocatorPlatform original;

  setUp(() {
    original = GeolocatorPlatform.instance;
    mockPlatform = MockGeolocatorPlatform();
    mockLogger = MockAppLogger();
    GeolocatorPlatform.instance = mockPlatform;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    GeolocatorPlatform.instance = original;
  });

  group('UserLocationNotifier', () {
    test('returns null when location service is disabled', () async {
      when(
        () => mockPlatform.isLocationServiceEnabled(),
      ).thenAnswer((_) async => false);

      final container = ProviderContainer(
        overrides: [loggerProvider.overrideWithValue(mockLogger)],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(userLocationProvider.notifier)
          .refreshDeepLocked();

      expect(result, isNull);
      verifyNever(() => mockPlatform.checkPermission());
    });

    test('returns null when permission is denied', () async {
      when(
        () => mockPlatform.isLocationServiceEnabled(),
      ).thenAnswer((_) async => true);
      when(
        () => mockPlatform.checkPermission(),
      ).thenAnswer((_) async => LocationPermission.denied);
      when(
        () => mockPlatform.requestPermission(),
      ).thenAnswer((_) async => LocationPermission.denied);

      final container = ProviderContainer(
        overrides: [loggerProvider.overrideWithValue(mockLogger)],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(userLocationProvider.notifier)
          .refreshDeepLocked();

      expect(result, isNull);
    });

    test('returns null when permission is denied forever', () async {
      when(
        () => mockPlatform.isLocationServiceEnabled(),
      ).thenAnswer((_) async => true);
      when(
        () => mockPlatform.checkPermission(),
      ).thenAnswer((_) async => LocationPermission.deniedForever);

      final container = ProviderContainer(
        overrides: [loggerProvider.overrideWithValue(mockLogger)],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(userLocationProvider.notifier)
          .refreshDeepLocked();

      expect(result, isNull);
    });

    test('locks a fresh sub-metre last-known position', () async {
      when(
        () => mockPlatform.isLocationServiceEnabled(),
      ).thenAnswer((_) async => true);
      when(
        () => mockPlatform.checkPermission(),
      ).thenAnswer((_) async => LocationPermission.whileInUse);
      when(
        () => mockPlatform.getLastKnownPosition(
          forceLocationManager: any(named: 'forceLocationManager'),
        ),
      ).thenAnswer((_) async => positionWith(29.2, 32.63, 0.8));

      final container = ProviderContainer(
        overrides: [loggerProvider.overrideWithValue(mockLogger)],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(userLocationProvider.notifier)
          .refreshDeepLocked();

      expect(result, isNotNull);
      expect(result!.accuracyMeters, lessThanOrEqualTo(precisionTargetMeters));
      verifyNever(() => mockPlatform.getPositionStream());
    });

    test('locks on the first sub-metre stream sample', () async {
      when(
        () => mockPlatform.isLocationServiceEnabled(),
      ).thenAnswer((_) async => true);
      when(
        () => mockPlatform.checkPermission(),
      ).thenAnswer((_) async => LocationPermission.whileInUse);
      when(
        () => mockPlatform.getLastKnownPosition(
          forceLocationManager: any(named: 'forceLocationManager'),
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockPlatform.getPositionStream(
          locationSettings: any(named: 'locationSettings'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          positionWith(29.2, 32.63, 5.0),
          positionWith(29.2, 32.63, 0.5),
        ]),
      );

      final container = ProviderContainer(
        overrides: [loggerProvider.overrideWithValue(mockLogger)],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(userLocationProvider.notifier)
          .refreshDeepLocked();

      expect(result, isNotNull);
      expect(result!.accuracyMeters, 0.5);
    });

    test('rejects a stale last-known position when no fresh fix arrives', () async {
      when(
        () => mockPlatform.isLocationServiceEnabled(),
      ).thenAnswer((_) async => true);
      when(
        () => mockPlatform.checkPermission(),
      ).thenAnswer((_) async => LocationPermission.whileInUse);
      when(
        () => mockPlatform.getLastKnownPosition(
          forceLocationManager: any(named: 'forceLocationManager'),
        ),
      ).thenAnswer(
        (_) async => positionWith(
          29.2,
          32.63,
          30.0,
          DateTime.now().subtract(const Duration(days: 9)),
        ),
      );
      when(
        () => mockPlatform.getPositionStream(
          locationSettings: any(named: 'locationSettings'),
        ),
      ).thenAnswer((_) => const Stream<Position>.empty());

      final container = ProviderContainer(
        overrides: [loggerProvider.overrideWithValue(mockLogger)],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(userLocationProvider.notifier)
          .refreshDeepLocked();

      expect(result, isNull);
    });

    test('ignores stale stream samples and locks a fresh one', () async {
      when(
        () => mockPlatform.isLocationServiceEnabled(),
      ).thenAnswer((_) async => true);
      when(
        () => mockPlatform.checkPermission(),
      ).thenAnswer((_) async => LocationPermission.whileInUse);
      when(
        () => mockPlatform.getLastKnownPosition(
          forceLocationManager: any(named: 'forceLocationManager'),
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockPlatform.getPositionStream(
          locationSettings: any(named: 'locationSettings'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          positionWith(
            29.2,
            32.63,
            5.0,
            DateTime.now().subtract(const Duration(days: 9)),
          ),
          positionWith(29.2, 32.63, 0.5),
        ]),
      );

      final container = ProviderContainer(
        overrides: [loggerProvider.overrideWithValue(mockLogger)],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(userLocationProvider.notifier)
          .refreshDeepLocked();

      expect(result, isNotNull);
      expect(result!.accuracyMeters, 0.5);
    });

    test('prefers a fresh stream fix over a stale last-known position', () async {
      when(
        () => mockPlatform.isLocationServiceEnabled(),
      ).thenAnswer((_) async => true);
      when(
        () => mockPlatform.checkPermission(),
      ).thenAnswer((_) async => LocationPermission.whileInUse);
      when(
        () => mockPlatform.getLastKnownPosition(
          forceLocationManager: any(named: 'forceLocationManager'),
        ),
      ).thenAnswer(
        (_) async => positionWith(
          29.2,
          32.63,
          30.0,
          DateTime.now().subtract(const Duration(days: 9)),
        ),
      );
      when(
        () => mockPlatform.getPositionStream(
          locationSettings: any(named: 'locationSettings'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([positionWith(29.2, 32.63, 5.0)]),
      );

      final container = ProviderContainer(
        overrides: [loggerProvider.overrideWithValue(mockLogger)],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(userLocationProvider.notifier)
          .refreshDeepLocked();

      expect(result, isNotNull);
      expect(result!.accuracyMeters, 5.0);
    });

    test('accepts a satellite-less network/fused stream sample as fallback',
        () async {
      when(
        () => mockPlatform.isLocationServiceEnabled(),
      ).thenAnswer((_) async => true);
      when(
        () => mockPlatform.checkPermission(),
      ).thenAnswer((_) async => LocationPermission.whileInUse);
      when(
        () => mockPlatform.getLastKnownPosition(
          forceLocationManager: any(named: 'forceLocationManager'),
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockPlatform.getPositionStream(
          locationSettings: any(named: 'locationSettings'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          androidPositionWith(29.2, 32.63, 5.0),
        ]),
      );

      final container = ProviderContainer(
        overrides: [loggerProvider.overrideWithValue(mockLogger)],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(userLocationProvider.notifier)
          .refreshDeepLocked();

      expect(result, isNotNull);
      expect(result!.accuracyMeters, 5.0);
    });

    test('accepts a GNSS-verified stream sample', () async {
      when(
        () => mockPlatform.isLocationServiceEnabled(),
      ).thenAnswer((_) async => true);
      when(
        () => mockPlatform.checkPermission(),
      ).thenAnswer((_) async => LocationPermission.whileInUse);
      when(
        () => mockPlatform.getLastKnownPosition(
          forceLocationManager: any(named: 'forceLocationManager'),
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockPlatform.getPositionStream(
          locationSettings: any(named: 'locationSettings'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          androidPositionWith(29.2, 32.63, 0.5, satellitesUsedInFix: 4),
        ]),
      );

      final container = ProviderContainer(
        overrides: [loggerProvider.overrideWithValue(mockLogger)],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(userLocationProvider.notifier)
          .refreshDeepLocked();

      expect(result, isNotNull);
      expect(result!.accuracyMeters, 0.5);
    });

    test('accepts a fresh network/fused last-known in quick mode', () async {
      when(
        () => mockPlatform.isLocationServiceEnabled(),
      ).thenAnswer((_) async => true);
      when(
        () => mockPlatform.checkPermission(),
      ).thenAnswer((_) async => LocationPermission.whileInUse);
      when(
        () => mockPlatform.getLastKnownPosition(
          forceLocationManager: any(named: 'forceLocationManager'),
        ),
      ).thenAnswer(
        (_) async => androidPositionWith(
          29.2,
          32.63,
          100.0,
        ),
      );

      final container = ProviderContainer(
        overrides: [loggerProvider.overrideWithValue(mockLogger)],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(userLocationProvider.notifier)
          .refreshQuick();

      expect(result, isNotNull);
      expect(result!.accuracyMeters, 100.0);
      verifyNever(() => mockPlatform.getPositionStream());
    });

    test('rejects a fresh non-GNSS last-known with poor accuracy', () async {
      when(
        () => mockPlatform.isLocationServiceEnabled(),
      ).thenAnswer((_) async => true);
      when(
        () => mockPlatform.checkPermission(),
      ).thenAnswer((_) async => LocationPermission.whileInUse);
      when(
        () => mockPlatform.getLastKnownPosition(
          forceLocationManager: any(named: 'forceLocationManager'),
        ),
      ).thenAnswer(
        (_) async => androidPositionWith(
          29.2,
          32.63,
          900.0,
        ),
      );
      when(
        () => mockPlatform.getPositionStream(
          locationSettings: any(named: 'locationSettings'),
        ),
      ).thenAnswer((_) => const Stream<Position>.empty());

      final container = ProviderContainer(
        overrides: [loggerProvider.overrideWithValue(mockLogger)],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(userLocationProvider.notifier)
          .refreshQuick();

      expect(result, isNull);
    });

    test('accepts a GNSS last-known up to 10 minutes old in deep mode',
        () async {
      when(
        () => mockPlatform.isLocationServiceEnabled(),
      ).thenAnswer((_) async => true);
      when(
        () => mockPlatform.checkPermission(),
      ).thenAnswer((_) async => LocationPermission.whileInUse);
      when(
        () => mockPlatform.getLastKnownPosition(
          forceLocationManager: any(named: 'forceLocationManager'),
        ),
      ).thenAnswer(
        (_) async => androidPositionWith(
          29.2,
          32.63,
          5.0,
          satellitesUsedInFix: 4,
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      );
      when(
        () => mockPlatform.getPositionStream(
          locationSettings: any(named: 'locationSettings'),
        ),
      ).thenAnswer((_) => const Stream<Position>.empty());

      final container = ProviderContainer(
        overrides: [loggerProvider.overrideWithValue(mockLogger)],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(userLocationProvider.notifier)
          .refreshDeepLocked();

      expect(result, isNotNull);
      expect(result!.accuracyMeters, 5.0);
    });

    test('rejects a non-GNSS last-known older than 10 minutes', () async {
      when(
        () => mockPlatform.isLocationServiceEnabled(),
      ).thenAnswer((_) async => true);
      when(
        () => mockPlatform.checkPermission(),
      ).thenAnswer((_) async => LocationPermission.whileInUse);
      when(
        () => mockPlatform.getLastKnownPosition(
          forceLocationManager: any(named: 'forceLocationManager'),
        ),
      ).thenAnswer(
        (_) async => androidPositionWith(
          29.2,
          32.63,
          100.0,
          timestamp: DateTime.now().subtract(const Duration(minutes: 11)),
        ),
      );
      when(
        () => mockPlatform.getPositionStream(
          locationSettings: any(named: 'locationSettings'),
        ),
      ).thenAnswer((_) => const Stream<Position>.empty());

      final container = ProviderContainer(
        overrides: [loggerProvider.overrideWithValue(mockLogger)],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(userLocationProvider.notifier)
          .refreshDeepLocked();

      expect(result, isNull);
    });
    test('rejects a non-GNSS last-known with unknown (0.0) accuracy', () async {
      when(
        () => mockPlatform.isLocationServiceEnabled(),
      ).thenAnswer((_) async => true);
      when(
        () => mockPlatform.checkPermission(),
      ).thenAnswer((_) async => LocationPermission.whileInUse);
      when(
        () => mockPlatform.getLastKnownPosition(
          forceLocationManager: any(named: 'forceLocationManager'),
        ),
      ).thenAnswer(
        (_) async => androidPositionWith(
          29.2,
          32.63,
          0.0,
        ),
      );
      when(
        () => mockPlatform.getPositionStream(
          locationSettings: any(named: 'locationSettings'),
        ),
      ).thenAnswer((_) => const Stream<Position>.empty());

      final container = ProviderContainer(
        overrides: [loggerProvider.overrideWithValue(mockLogger)],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(userLocationProvider.notifier)
          .refreshQuick();

      expect(result, isNull);
    });

    test('does not report 0 m for a GNSS last-known with unknown (0.0) accuracy',
        () async {
      when(
        () => mockPlatform.isLocationServiceEnabled(),
      ).thenAnswer((_) async => true);
      when(
        () => mockPlatform.checkPermission(),
      ).thenAnswer((_) async => LocationPermission.whileInUse);
      when(
        () => mockPlatform.getLastKnownPosition(
          forceLocationManager: any(named: 'forceLocationManager'),
        ),
      ).thenAnswer(
        (_) async => androidPositionWith(
          29.2,
          32.63,
          0.0,
          satellitesUsedInFix: 4,
        ),
      );

      final container = ProviderContainer(
        overrides: [loggerProvider.overrideWithValue(mockLogger)],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(userLocationProvider.notifier)
          .refreshDeepLocked();

      expect(result, isNotNull);
      expect(result!.accuracyMeters, isNull);
      verifyNever(() => mockPlatform.getPositionStream());
    });

    test('does not report 0 m for a stream sample with unknown (0.0) accuracy',
        () async {
      when(
        () => mockPlatform.isLocationServiceEnabled(),
      ).thenAnswer((_) async => true);
      when(
        () => mockPlatform.checkPermission(),
      ).thenAnswer((_) async => LocationPermission.whileInUse);
      when(
        () => mockPlatform.getLastKnownPosition(
          forceLocationManager: any(named: 'forceLocationManager'),
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockPlatform.getPositionStream(
          locationSettings: any(named: 'locationSettings'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          androidPositionWith(29.2, 32.63, 0.0),
        ]),
      );

      final container = ProviderContainer(
        overrides: [loggerProvider.overrideWithValue(mockLogger)],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(userLocationProvider.notifier)
          .refreshDeepLocked();

      expect(result, isNotNull);
      expect(result!.accuracyMeters, isNull);
    });
  });

  group('composeGoogleAddress', () {
    List<dynamic> component(String name, List<String> types) => [
      {
        'long_name': name,
        'short_name': name,
        'types': types,
      },
    ];

    test('joins markaz and village hierarchy largest first in Arabic',
        () async {
      final components = <dynamic>[
        ...component('Zafarana offices', ['premise']),
        ...component('قرية الزعفرانة', ['sublocality_level_1']),
        ...component('مركز السويس', ['administrative_area_level_2']),
        ...component('محافظة السويس', ['administrative_area_level_1']),
        ...component('مصر', ['country']),
      ];

      final result = UserLocationNotifier.composeGoogleAddress(
        components,
        'ar',
      );

      expect(result, isNotNull);
      expect(
        result!.address,
        'Zafarana offices، مركز السويس - قرية الزعفرانة، محافظة السويس، مصر',
      );
      expect(result.hasNamed, isTrue);
    });

    test('keeps hierarchy chain and comma separators in English', () async {
      final components = <dynamic>[
        ...component('Suez Center', ['administrative_area_level_2']),
        ...component('Zafarana Village', ['sublocality_level_1']),
        ...component('Suez Governorate', ['administrative_area_level_1']),
        ...component('Egypt', ['country']),
      ];

      final result = UserLocationNotifier.composeGoogleAddress(
        components,
        'en',
      );

      expect(result, isNotNull);
      expect(
        result!.address,
        'Suez Center - Zafarana Village, Suez Governorate, Egypt',
      );
    });

    test('deduplicates names that repeat across hierarchy levels', () async {
      final components = <dynamic>[
        ...component('قرية الزعفرانة', ['sublocality_level_1']),
        ...component('السويس', ['administrative_area_level_2']),
        ...component('السويس', ['locality']),
        ...component('مصر', ['country']),
      ];

      final result = UserLocationNotifier.composeGoogleAddress(
        components,
        'ar',
      );

      expect(result, isNotNull);
      expect(result!.address, 'السويس - قرية الزعفرانة، السويس، مصر');
    });

    test('collapses identical names repeated within the hierarchy chain',
        () async {
      final components = <dynamic>[
        ...component('السويس', ['sublocality_level_1']),
        ...component('السويس', ['administrative_area_level_2']),
        ...component('مصر', ['country']),
      ];

      final result = UserLocationNotifier.composeGoogleAddress(
        components,
        'ar',
      );

      expect(result, isNotNull);
      expect(result!.address, 'السويس، مصر');
    });

    test('includes street number and route', () async {
      final components = <dynamic>[
        ...component('Zafarana offices', ['premise']),
        ...component('12', ['street_number']),
        ...component('طريق السويس', ['route']),
        ...component('عتاقة', ['sublocality_level_1']),
        ...component('مصر', ['country']),
      ];

      final result = UserLocationNotifier.composeGoogleAddress(
        components,
        'ar',
      );

      expect(result, isNotNull);
      expect(result!.address, 'Zafarana offices، 12 طريق السويس، عتاقة، مصر');
    });

    test('returns null for an empty component list', () async {
      final result = UserLocationNotifier.composeGoogleAddress([], 'ar');
      expect(result, isNull);
    });

    test('marks address without named place', () async {
      final components = <dynamic>[
        ...component('مصر', ['country']),
      ];

      final result = UserLocationNotifier.composeGoogleAddress(
        components,
        'ar',
      );

      expect(result, isNotNull);
      expect(result!.hasNamed, isFalse);
      expect(result.address, 'مصر');
    });
  });

  group('composeNominatimAddress', () {
    test('joins county (markaz) and village hierarchy largest first', () async {
      final address = <String, dynamic>{
        'county': 'مركز السويس',
        'village': 'قرية الزعفرانة',
        'state': 'محافظة السويس',
        'country': 'مصر',
      };

      final result = UserLocationNotifier.composeNominatimAddress(address, 'ar');

      expect(result, isNotNull);
      expect(
        result!.address,
        'مركز السويس - قرية الزعفرانة، محافظة السويس، مصر',
      );
    });

    test('joins city and suburb for urban addresses', () async {
      final address = <String, dynamic>{
        'city': 'القاهرة',
        'suburb': 'مدينة نصر',
        'country': 'مصر',
      };

      final result = UserLocationNotifier.composeNominatimAddress(address, 'ar');

      expect(result, isNotNull);
      expect(result!.address, 'القاهرة - مدينة نصر، مصر');
    });

    test('prepends a named place before the hierarchy chain', () async {
      final address = <String, dynamic>{
        'amenity': 'مستشفى السلام',
        'road': 'شارع الجيش',
        'city': 'القاهرة',
        'country': 'مصر',
      };

      final result = UserLocationNotifier.composeNominatimAddress(address, 'ar');

      expect(result, isNotNull);
      expect(result!.address, 'مستشفى السلام، شارع الجيش، القاهرة، مصر');
      expect(result.hasNamed, isTrue);
    });

    test('deduplicates county and city sharing the same name', () async {
      final address = <String, dynamic>{
        'county': 'السويس',
        'city': 'السويس',
        'country': 'مصر',
      };

      final result = UserLocationNotifier.composeNominatimAddress(address, 'ar');

      expect(result, isNotNull);
      expect(result!.address, 'السويس، مصر');
    });

    test('returns null for an empty address map', () async {
      final result = UserLocationNotifier.composeNominatimAddress({}, 'ar');
      expect(result, isNull);
    });
  });
}
