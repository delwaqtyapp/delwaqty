import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:delwaqty/features/regions/data/datasources/remote/supabase_region_data_source.dart';
import 'package:delwaqty/features/regions/data/repositories/region_repository_impl.dart';
import 'package:delwaqty/features/regions/domain/entities/region.dart';

class _MockDataSource extends Mock implements RegionDataSource {}

void main() {
  final now = DateTime(2026, 8, 15);

  final cairo = Region(
    id: 'r-cairo',
    code: 'EG-C',
    type: RegionType.governorate,
    nameAr: 'القاهرة',
    nameEn: 'Cairo',
    createdAt: now,
  );
  final giza = Region(
    id: 'r-giza',
    code: 'EG-GZ',
    type: RegionType.governorate,
    nameAr: 'الجيزة',
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
}
