import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:delwaqty/features/_shared/regions/data/datasources/remote/supabase_region_data_source.dart';
import 'package:delwaqty/features/_shared/regions/data/repositories/region_repository_impl.dart';
import 'package:delwaqty/features/_shared/regions/domain/entities/region.dart';
import 'package:delwaqty/features/_shared/regions/domain/entities/geo_entity.dart';
import 'package:delwaqty/features/_shared/regions/domain/entities/spatial_resolution.dart';

class _MockDataSource extends Mock implements RegionDataSource {}

void main() {
  final now = DateTime(2026, 8, 15);

  final cairo = Region(
    id: 'r-cairo',
    code: 'EG-C',
    type: RegionType.governorate,
    nameAr: 'Ø§Ù„Ù‚Ø§Ù‡Ø±Ø©',
    nameEn: 'Cairo',
    createdAt: now,
  );
  final giza = Region(
    id: 'r-giza',
    code: 'EG-GZ',
    type: RegionType.governorate,
    nameAr: 'Ø§Ù„Ø¬ÙŠØ²Ø©',
    nameEn: 'Giza',
    createdAt: now,
  );
  final preference = UserRegionPreference(
    userId: 'u1',
    regionId: 'r-cairo',
    source: RegionPreferenceSource.manual,
    updatedAt: now,
  );

  late _MockDataSource dataSource;
  late RegionRepositoryImpl repository;

  setUp(() {
    dataSource = _MockDataSource();
    repository = RegionRepositoryImpl(dataSource);
  });

  group('getGovernorates', () {
    test('returns governorates provided by the data source', () async {
      when(() => dataSource.getGovernorates())
          .thenAnswer((_) async => [giza, cairo]);

      final result = await repository.getGovernorates();

      expect(result, [giza, cairo]);
      verify(() => dataSource.getGovernorates()).called(1);
    });

    test('rethrows data source errors', () {
      when(() => dataSource.getGovernorates())
          .thenThrow(Exception('db down'));

      expect(() => repository.getGovernorates(), throwsException);
    });
  });

  group('getChildren', () {
    test('returns children for a parent region', () async {
      when(() => dataSource.getChildren('r-eg'))
          .thenAnswer((_) async => [giza, cairo]);

      final result = await repository.getChildren('r-eg');

      expect(result, [giza, cairo]);
      verify(() => dataSource.getChildren('r-eg')).called(1);
    });
  });

  group('getRegion', () {
    test('returns a single region', () async {
      when(() => dataSource.getRegion('r-cairo'))
          .thenAnswer((_) async => cairo);

      final result = await repository.getRegion('r-cairo');

      expect(result, cairo);
    });

    test('rethrows missing region error', () {
      when(() => dataSource.getRegion('nope'))
          .thenThrow(const RegionException('not found'));

      expect(
        () => repository.getRegion('nope'),
        throwsA(isA<RegionException>()),
      );
    });
  });

  group('getRegionByCode', () {
    test('returns a region by ISO code', () async {
      when(() => dataSource.getRegionByCode('EG-C'))
          .thenAnswer((_) async => cairo);

      final result = await repository.getRegionByCode('EG-C');

      expect(result, cairo);
    });
  });

  group('searchRegions', () {
    test('returns ranked search results', () async {
      when(() => dataSource.searchRegions('qah'))
          .thenAnswer((_) async => [cairo]);

      final result = await repository.searchRegions('qah');

      expect(result, [cairo]);
    });
  });

  group('setUserRegion', () {
    test('persists preference with given source', () async {
      when(
        () => dataSource.setUserRegion(
          userId: 'u1',
          regionId: 'r-cairo',
          source: RegionPreferenceSource.verified,
        ),
      ).thenAnswer((_) async {});

      await repository.setUserRegion(
        userId: 'u1',
        regionId: 'r-cairo',
        source: RegionPreferenceSource.verified,
      );

      verify(
        () => dataSource.setUserRegion(
          userId: 'u1',
          regionId: 'r-cairo',
          source: RegionPreferenceSource.verified,
        ),
      ).called(1);
    });
  });

  group('getUserRegion', () {
    test('returns the stored preference', () async {
      when(() => dataSource.getUserRegion('u1'))
          .thenAnswer((_) async => preference);

      final result = await repository.getUserRegion('u1');

      expect(result, preference);
    });

    test('returns null when no preference exists', () async {
      when(() => dataSource.getUserRegion('u1'))
          .thenAnswer((_) async => null);

      final result = await repository.getUserRegion('u1');

      expect(result, isNull);
    });
  });

  group('getGeoPlaces', () {
    test('forwards type filter to the data source', () async {
      final places = [
        GeoPlace(
          id: 'p1',
          type: GeoPlaceType.airport,
          source: 'geonames',
          sourceRef: 'r1',
          sourceType: GeoSourceType.secondaryVerified,
          confidence: GeoConfidence.high,
          createdAt: now,
        ),
      ];
      when(
        () => dataSource.getGeoPlaces(type: 'airport'),
      ).thenAnswer((_) async => places);

      final result = await repository.getGeoPlaces(type: 'airport');

      expect(result, places);
      verify(() => dataSource.getGeoPlaces(type: 'airport')).called(1);
    });

    test('forwards query filter to the data source', () async {
      when(
        () => dataSource.getGeoPlaces(query: 'pyram'),
      ).thenAnswer((_) async => const <GeoPlace>[]);

      final result = await repository.getGeoPlaces(query: 'pyram');

      expect(result, isEmpty);
    });
  });

  group('getGeoPlace', () {
    test('returns a single place', () async {
      final place = GeoPlace(
        id: 'p1',
        type: GeoPlaceType.hotel,
        source: 'geonames',
        sourceRef: 'r1',
        sourceType: GeoSourceType.secondaryVerified,
        confidence: GeoConfidence.medium,
        createdAt: now,
      );
      when(() => dataSource.getGeoPlace('p1')).thenAnswer((_) async => place);

      final result = await repository.getGeoPlace('p1');

      expect(result, place);
    });

    test('returns null when missing', () async {
      when(() => dataSource.getGeoPlace('nope')).thenAnswer((_) async => null);

      final result = await repository.getGeoPlace('nope');

      expect(result, isNull);
    });
  });

  group('resolveRegionForPoint', () {
    test('returns spatial resolution from the data source', () async {
      final resolution = const SpatialResolution(
        regionId: 'r-giza',
        governorateId: 'r-giza',
        confidence: GeoConfidence.high,
      );
      when(
        () => dataSource.resolveRegionForPoint(
          lat: 29.98,
          lon: 31.13,
          maxDepth: any(named: 'maxDepth'),
          toleranceM: any(named: 'toleranceM'),
        ),
      ).thenAnswer((_) async => resolution);

      final result = await repository.resolveRegionForPoint(
        lat: 29.98,
        lon: 31.13,
      );

      expect(result, resolution);
    });

    test('returns null when the RPC finds nothing', () async {
      when(
        () => dataSource.resolveRegionForPoint(
          lat: 0,
          lon: 0,
          maxDepth: any(named: 'maxDepth'),
          toleranceM: any(named: 'toleranceM'),
        ),
      ).thenAnswer((_) async => null);

      final result = await repository.resolveRegionForPoint(lat: 0, lon: 0);

      expect(result, isNull);
    });
  });
}
