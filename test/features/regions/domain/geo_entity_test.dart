import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/_shared/regions/domain/entities/geo_entity.dart';
import 'package:delwaqty/features/_shared/regions/domain/entities/spatial_resolution.dart';

void main() {
  group('GeoPlace.fromRow', () {
    test('parses a Supabase geo_places row', () {
      final place = GeoPlace.fromRow({
        'id': '5ce55b2e-b85c-5876-99b7-9a6b38d34af2',
        'type': 'airport',
        'region_id': '00000000-0000-0000-0000-000000000107',
        'name_ar': 'Cairo International Airport',
        'name_en': 'Cairo International Airport',
        'latitude': 30.12194,
        'longitude': 31.40556,
        'source': 'geonames',
        'source_ref': '6297293',
        'source_date': '2026-08-15',
        'source_type': 'SECONDARY VERIFIED',
        'confidence': 'HIGH',
        'provenance': <String, dynamic>{'source': 'geonames', 'source_ref': '6297293'},
        'license': null,
        'is_active': true,
        'metadata': <String, dynamic>{},
        'created_at': '2026-08-15T00:00:00Z',
        'updated_at': '2026-08-15T00:00:00Z',
      });

      expect(place.type, GeoPlaceType.airport);
      expect(place.regionId, '00000000-0000-0000-0000-000000000107');
      expect(place.sourceType, GeoSourceType.secondaryVerified);
      expect(place.confidence, GeoConfidence.high);
      expect(place.latitude, 30.12194);
      expect(place.isActive, isTrue);
    });

    test('displayName prefers Arabic then falls back to source_ref', () {
      final arabic = GeoPlace(
        id: 'p1',
        type: GeoPlaceType.landmark,
        nameAr: 'Ø£Ù‡Ø±Ø§Ù…Ø§Øª Ø§Ù„Ø¬ÙŠØ²Ø©',
        nameEn: 'Pyramids of Giza',
        source: 'geonames',
        sourceRef: '355017',
        sourceType: GeoSourceType.secondaryVerified,
        confidence: GeoConfidence.high,
        createdAt: DateTime(2026, 8, 15),
      );
      expect(arabic.displayName('ar'), 'Ø£Ù‡Ø±Ø§Ù…Ø§Øª Ø§Ù„Ø¬ÙŠØ²Ø©');
      expect(arabic.displayName('en'), 'Pyramids of Giza');

      final bare = GeoPlace(
        id: 'p2',
        type: GeoPlaceType.poi,
        source: 'openstreetmap',
        sourceRef: 'nominatim:thing',
        sourceType: GeoSourceType.providerDerived,
        confidence: GeoConfidence.medium,
        createdAt: DateTime(2026, 8, 15),
      );
      expect(bare.displayName('ar'), 'nominatim:thing');
    });

    test('unknown enum values fall back safely', () {
      final place = GeoPlace.fromRow({
        'id': 'p3',
        'type': 'mystery',
        'source': 'x',
        'source_ref': 'r',
        'source_type': 'UNVERIFIED',
        'confidence': null,
        'created_at': '2026-08-15T00:00:00Z',
      });
      expect(place.type, GeoPlaceType.poi);
      expect(place.sourceType, GeoSourceType.unverifiedMissing);
      expect(place.confidence, GeoConfidence.unverified);
    });
  });

  group('GeoAlias.fromRow', () {
    test('parses a Supabase geo_aliases row', () {
      final alias = GeoAlias.fromRow({
        'entity_type': 'region',
        'entity_id': '5d6b5ccd-22c6-5f46-91b0-75794b297639',
        'alias': 'Ù‚Ø³Ù… Ø§ÙˆÙ„ Ù…Ø¯ÙŠÙ†Ø© Ø§Ù„Ø¹Ø§Ø´Ø± Ù…Ù† Ø±Ù…Ø¶Ø§Ù†',
        'lang': 'ar',
        'is_primary': true,
        'source': 'cod-ab',
      });
      expect(alias.entityType, 'region');
      expect(alias.isPrimary, isTrue);
      expect(alias.alias, 'Ù‚Ø³Ù… Ø§ÙˆÙ„ Ù…Ø¯ÙŠÙ†Ø© Ø§Ù„Ø¹Ø§Ø´Ø± Ù…Ù† Ø±Ù…Ø¶Ø§Ù†');
    });
  });

  group('SpatialResolution.fromRpc (RPC response)', () {
    test('parses the geo_region_for_point payload', () {
      final resolution = SpatialResolution.fromRpc({
        'region_id': 'e5f675e5-cfe5-5432-bdf5-0ebb38bf55b5',
        'code': 'EG-ADM2-3202',
        'name_ar': 'Ù…Ø±ÙƒØ² Ø§Ù„ÙˆØ§Ø­Ø§Øª Ø§Ù„Ø¯Ø§Ø®Ù„Ø©',
        'name_en': 'A-Dakhla Oasis',
        'type': 'markaz',
        'parent_region_id': '00000000-0000-0000-0000-000000000127',
        'governorate_id': '00000000-0000-0000-0000-000000000127',
        'governorate_code': 'EG-WAD',
        'governorate_name_ar': 'Ø§Ù„ÙˆØ§Ø¯ÙŠ Ø§Ù„Ø¬Ø¯ÙŠØ¯',
        'governorate_name_en': 'New Valley',
        'confidence': 'HIGH',
        'distance_m': 0,
      });

      expect(resolution.regionId, 'e5f675e5-cfe5-5432-bdf5-0ebb38bf55b5');
      expect(resolution.code, 'EG-ADM2-3202');
      expect(resolution.type, 'markaz');
      expect(resolution.governorateCode, 'EG-WAD');
      expect(resolution.confidence, GeoConfidence.high);
      expect(resolution.distanceM, 0);
    });

    test('parses LOW fallback with distance', () {
      final resolution = SpatialResolution.fromRpc({
        'region_id': '00000000-0000-0000-0000-000000000109',
        'code': 'EG-DT',
        'name_ar': 'Ø¯Ù…ÙŠØ§Ø·',
        'name_en': 'Damietta',
        'type': 'governorate',
        'parent_region_id': '00000000-0000-0000-0000-000000000001',
        'governorate_id': '00000000-0000-0000-0000-000000000109',
        'governorate_code': 'EG-DT',
        'governorate_name_ar': 'Ø¯Ù…ÙŠØ§Ø·',
        'governorate_name_en': 'Damietta',
        'confidence': 'LOW',
        'distance_m': 56209,
      });

      expect(resolution.confidence, GeoConfidence.low);
      expect(resolution.distanceM, 56209);
    });

    test('parses INVALID as a non-resolvable outcome', () {
      final resolution = SpatialResolution.fromRpc({
        'region_id': null,
        'confidence': 'INVALID',
      });
      expect(resolution.confidence, GeoConfidence.invalid);
    });
  });
}
