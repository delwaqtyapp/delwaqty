import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/_shared/regions/domain/entities/region.dart';

void main() {
  final now = DateTime(2026, 8, 15);

  group('RegionType', () {
    test('has all values', () {
      expect(RegionType.values.length, 8);
      expect(RegionType.country.code, 'country');
      expect(RegionType.governorate.code, 'governorate');
      expect(RegionType.markaz.code, 'markaz');
      expect(RegionType.district.code, 'district');
      expect(RegionType.city.code, 'city');
      expect(RegionType.village.code, 'village');
      expect(RegionType.newCity.code, 'new_city');
      expect(RegionType.area.code, 'area');
    });

    test('fromCode maps known codes and falls back to country', () {
      expect(RegionType.fromCode('governorate'), RegionType.governorate);
      expect(RegionType.fromCode('markaz'), RegionType.markaz);
      expect(RegionType.fromCode('city'), RegionType.city);
      expect(RegionType.fromCode('village'), RegionType.village);
      expect(RegionType.fromCode('new_city'), RegionType.newCity);
      expect(RegionType.fromCode('district'), RegionType.district);
      expect(RegionType.fromCode('area'), RegionType.area);
      expect(RegionType.fromCode('country'), RegionType.country);
      expect(RegionType.fromCode('unknown'), RegionType.country);
      expect(RegionType.fromCode(null), RegionType.country);
    });
  });

  group('RegionPreferenceSource', () {
    test('has all values', () {
      expect(RegionPreferenceSource.values.length, 3);
      expect(RegionPreferenceSource.detected.code, 'detected');
      expect(RegionPreferenceSource.manual.code, 'manual');
      expect(RegionPreferenceSource.verified.code, 'verified');
    });

    test('fromCode maps known codes and falls back to detected', () {
      expect(RegionPreferenceSource.fromCode('manual'), RegionPreferenceSource.manual);
      expect(RegionPreferenceSource.fromCode('verified'), RegionPreferenceSource.verified);
      expect(RegionPreferenceSource.fromCode('detected'), RegionPreferenceSource.detected);
      expect(RegionPreferenceSource.fromCode('unknown'), RegionPreferenceSource.detected);
      expect(RegionPreferenceSource.fromCode(null), RegionPreferenceSource.detected);
    });
  });

  group('Region', () {
    test('fromJson maps a row', () {
      final region = Region.fromJson({
        'id': '00000000-0000-0000-0000-000000000107',
        'code': 'EG-C',
        'parentRegionId': '00000000-0000-0000-0000-000000000001',
        'countryCode': 'EG',
        'type': 'governorate',
        'nameAr': 'القاهرة',
        'nameEn': 'Cairo',
        'isActive': true,
        'metadata': {'iso3166_2': 'EG-C', 'aliases': ['Al Qahirah']},
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });

      expect(region.id, '00000000-0000-0000-0000-000000000107');
      expect(region.code, 'EG-C');
      expect(region.parentRegionId, '00000000-0000-0000-0000-000000000001');
      expect(region.countryCode, 'EG');
      expect(region.type, RegionType.governorate);
      expect(region.nameAr, 'القاهرة');
      expect(region.nameEn, 'Cairo');
      expect(region.isActive, true);
      expect(region.aliases, ['Al Qahirah']);
    });

    test('defaults are applied when fields are missing', () {
      final region = Region.fromJson({
        'id': 'r1',
        'code': 'EG-C',
        'type': 'governorate',
        'nameAr': 'القاهرة',
        'createdAt': now.toIso8601String(),
      });

      expect(region.countryCode, 'EG');
      expect(region.isActive, true);
      expect(region.parentRegionId, isNull);
      expect(region.nameEn, isNull);
      expect(region.aliases, isEmpty);
    });

    test('displayName respects language', () {
      final region = Region(
        id: 'r1',
        code: 'EG-C',
        type: RegionType.governorate,
        nameAr: 'القاهرة',
        nameEn: 'Cairo',
        createdAt: now,
      );

      expect(region.displayName('ar'), 'القاهرة');
      expect(region.displayName('en'), 'Cairo');
    });

    test('displayName falls back to Arabic when no English name', () {
      final region = Region(
        id: 'r1',
        code: 'EG-C',
        type: RegionType.governorate,
        nameAr: 'القاهرة',
        createdAt: now,
      );

      expect(region.displayName('en'), 'القاهرة');
    });
  });

  group('UserRegionPreference', () {
    test('fromJson maps a row', () {
      final preference = UserRegionPreference.fromJson({
        'userId': 'u1',
        'regionId': 'r1',
        'source': 'verified',
        'updatedAt': now.toIso8601String(),
      });

      expect(preference.userId, 'u1');
      expect(preference.regionId, 'r1');
      expect(preference.source, RegionPreferenceSource.verified);
      expect(preference.updatedAt, now);
    });
  });
}
