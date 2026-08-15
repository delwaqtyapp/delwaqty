import 'package:delwaqty/features/regions/domain/entities/region.dart';

abstract class RegionRepository {
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
}
