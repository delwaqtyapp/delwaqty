import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/_shared/regions/domain/entities/region.dart';
import 'package:delwaqty/features/_shared/regions/domain/entities/geo_entity.dart';
import 'package:delwaqty/features/_shared/regions/domain/entities/spatial_resolution.dart';

abstract class RegionDataSource {
  Future<List<Region>> getGovernorates();

  Future<List<Region>> getChildren(String parentRegionId);

  Future<Region> getRegion(String regionId);

  Future<Region?> getRegionByCode(String code);

  Future<List<Region>> searchRegions(String query);

  Future<void> setUserRegion({
    required String userId,
    required String regionId,
    required RegionPreferenceSource source,
  });

  Future<UserRegionPreference?> getUserRegion(String userId);

  Future<List<GeoPlace>> getGeoPlaces({String? type, String? query});

  Future<GeoPlace?> getGeoPlace(String id);

  Future<SpatialResolution?> resolveRegionForPoint({
    required double lat,
    required double lon,
    int maxDepth = 2,
    double toleranceM = 25000,
  });
}

class SupabaseRegionDataSource implements RegionDataSource {
  SupabaseRegionDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Region>> getGovernorates() async {
    try {
      final rows = await _client
          .from('regions')
          .select()
          .eq('type', 'governorate')
          .eq('is_active', true)
          .order('name_en');
      return rows.map(_fromRow).toList();
    } catch (e) {
      throw RegionException('Failed to load governorates: $e');
    }
  }

  @override
  Future<List<Region>> getChildren(String parentRegionId) async {
    try {
      final rows = await _client
          .from('regions')
          .select()
          .eq('parent_region_id', parentRegionId)
          .order('name_en');
      return rows.map(_fromRow).toList();
    } catch (e) {
      throw RegionException('Failed to load region children: $e');
    }
  }

  @override
  Future<Region> getRegion(String regionId) async {
    try {
      final row = await _client
          .from('regions')
          .select()
          .eq('id', regionId)
          .single();
      return _fromRow(row);
    } catch (e) {
      throw RegionException('Failed to load region $regionId: $e');
    }
  }

  @override
  Future<Region?> getRegionByCode(String code) async {
    try {
      final row = await _client
          .from('regions')
          .select()
          .eq('code', code)
          .maybeSingle();
      return row == null ? null : _fromRow(row);
    } catch (e) {
      throw RegionException('Failed to load region by code $code: $e');
    }
  }

  @override
  Future<List<Region>> searchRegions(String query) async {
    try {
      final rows = await _client
          .from('regions')
          .select()
          .eq('is_active', true)
          .or('name_ar.ilike.%$query%,name_en.ilike.%$query%')
          .limit(20);
      return rows.map(_fromRow).toList();
    } catch (e) {
      throw RegionException('Failed to search regions: $e');
    }
  }

  @override
  Future<void> setUserRegion({
    required String userId,
    required String regionId,
    required RegionPreferenceSource source,
  }) async {
    try {
      await _client.from('user_region_preferences').upsert({
        'user_id': userId,
        'region_id': regionId,
        'source': source.code,
      }, onConflict: 'user_id');
    } catch (e) {
      throw RegionException('Failed to save user region: $e');
    }
  }

  @override
  Future<UserRegionPreference?> getUserRegion(String userId) async {
    try {
      final row = await _client
          .from('user_region_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return null;
      return UserRegionPreference(
        userId: row['user_id'] as String,
        regionId: row['region_id'] as String,
        source: RegionPreferenceSource.fromCode(row['source'] as String?),
        updatedAt: DateTime.parse(row['updated_at'] as String),
      );
    } catch (e) {
      throw RegionException('Failed to load user region: $e');
    }
  }

  @override
  Future<List<GeoPlace>> getGeoPlaces({String? type, String? query}) async {
    try {
      var request = _client
          .from('geo_places')
          .select()
          .eq('is_active', true);
      if (type != null) {
        request = request.eq('type', type);
      }
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim();
        request = request.or('name_ar.ilike.%$q%,name_en.ilike.%$q%');
      }
      final rows = await request.order('name_en').limit(50);
      return rows.map(GeoPlace.fromRow).toList();
    } catch (e) {
      throw RegionException('Failed to load geo places: $e');
    }
  }

  @override
  Future<GeoPlace?> getGeoPlace(String id) async {
    try {
      final row = await _client
          .from('geo_places')
          .select()
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : GeoPlace.fromRow(row);
    } catch (e) {
      throw RegionException('Failed to load geo place $id: $e');
    }
  }

  @override
  Future<SpatialResolution?> resolveRegionForPoint({
    required double lat,
    required double lon,
    int maxDepth = 2,
    double toleranceM = 25000,
  }) async {
    try {
      final rows = await _client.rpc(
        'geo_region_for_point',
        params: {
          'p_lat': lat,
          'p_lon': lon,
          'p_max_depth': maxDepth,
          'p_tolerance_m': toleranceM,
        },
      );
      if (rows == null || rows.isEmpty) return null;
      final row = rows is List ? rows.first : rows;
      if (row is! Map) return null;
      return SpatialResolution.fromRpc(Map<String, dynamic>.from(row));
    } catch (e) {
      throw RegionException('Failed to resolve region for point: $e');
    }
  }

  Region _fromRow(Map<String, dynamic> row) {
    return Region(
      id: row['id'] as String,
      code: row['code'] as String,
      parentRegionId: row['parent_region_id'] as String?,
      countryCode: row['country_code'] as String? ?? 'EG',
      type: RegionType.fromCode(row['type'] as String?),
      nameAr: row['name_ar'] as String,
      nameEn: row['name_en'] as String?,
      isActive: row['is_active'] as bool? ?? true,
      metadata: row['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : null,
    );
  }
}
