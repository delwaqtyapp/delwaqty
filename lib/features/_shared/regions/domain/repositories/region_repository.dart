import 'package:delwaqty/features/_shared/regions/domain/entities/region.dart';
import 'package:delwaqty/features/_shared/regions/domain/entities/geo_entity.dart';
import 'package:delwaqty/features/_shared/regions/domain/entities/spatial_resolution.dart';

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

  Future<List<GeoPlace>> getGeoPlaces({String? type, String? query});

  Future<GeoPlace?> getGeoPlace(String id);

  Future<SpatialResolution?> resolveRegionForPoint({
    required double lat,
    required double lon,
    int maxDepth = 2,
    double toleranceM = 25000,
  });
}
