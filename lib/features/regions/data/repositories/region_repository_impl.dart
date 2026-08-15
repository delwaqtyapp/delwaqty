import 'package:delwaqty/features/regions/domain/entities/region.dart';
import 'package:delwaqty/features/regions/domain/repositories/region_repository.dart';
import 'package:delwaqty/features/regions/data/datasources/remote/supabase_region_data_source.dart';

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
}
