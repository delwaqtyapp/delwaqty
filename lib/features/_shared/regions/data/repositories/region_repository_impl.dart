import 'package:delwaqty/features/_shared/regions/domain/entities/region.dart';
import 'package:delwaqty/features/_shared/regions/domain/entities/geo_entity.dart';
import 'package:delwaqty/features/_shared/regions/domain/entities/spatial_resolution.dart';
import 'package:delwaqty/features/_shared/regions/domain/repositories/region_repository.dart';
import 'package:delwaqty/features/_shared/regions/data/datasources/remote/supabase_region_data_source.dart';

class RegionRepositoryImpl implements RegionRepository {
  RegionRepositoryImpl(this._dataSource);

  final RegionDataSource _dataSource;

  @override
  Future<List<Region>> getGovernorates() => _dataSource.getGovernorates();

  @override
  Future<List<Region>> getChildren(String parentRegionId) {
    return _dataSource.getChildren(parentRegionId);
  }

  @override
  Future<Region> getRegion(String regionId) => _dataSource.getRegion(regionId);

  @override
  Future<Region?> getRegionByCode(String code) {
    return _dataSource.getRegionByCode(code);
  }

  @override
  Future<List<Region>> searchRegions(String query) {
    return _dataSource.searchRegions(query);
  }

  @override
  Future<void> setUserRegion({
    required String userId,
    required String regionId,
    required RegionPreferenceSource source,
  }) {
    return _dataSource.setUserRegion(
      userId: userId,
      regionId: regionId,
      source: source,
    );
  }

  @override
  Future<UserRegionPreference?> getUserRegion(String userId) {
    return _dataSource.getUserRegion(userId);
  }

  @override
  Future<List<GeoPlace>> getGeoPlaces({String? type, String? query}) {
    return _dataSource.getGeoPlaces(type: type, query: query);
  }

  @override
  Future<GeoPlace?> getGeoPlace(String id) => _dataSource.getGeoPlace(id);

  @override
  Future<SpatialResolution?> resolveRegionForPoint({
    required double lat,
    required double lon,
    int maxDepth = 2,
    double toleranceM = 25000,
  }) {
    return _dataSource.resolveRegionForPoint(
      lat: lat,
      lon: lon,
      maxDepth: maxDepth,
      toleranceM: toleranceM,
    );
  }
}
