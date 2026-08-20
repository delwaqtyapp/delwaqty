import 'package:delwaqty/features/_shared/regions/domain/entities/region.dart';
import 'package:delwaqty/features/_shared/regions/domain/entities/geo_entity.dart';
import 'package:delwaqty/features/_shared/regions/domain/entities/spatial_resolution.dart';
import 'package:delwaqty/features/_shared/regions/domain/repositories/region_repository.dart';

/// In-memory fake used by widget tests. Mirrors the hand-rolled mock
/// repository pattern already used for notifications.
class MockRegionRepository implements RegionRepository {
  MockRegionRepository({
    List<Region>? governorates,
    List<Region>? children,
    this._preference,
    List<GeoPlace>? geoPlaces,
    this._spatialResolution,
  }) : _governorates = governorates ?? [],
       _children = children ?? [],
       _geoPlaces = geoPlaces ?? [];

  final List<Region> _governorates;
  final List<Region> _children;
  final List<GeoPlace> _geoPlaces;
  SpatialResolution? _spatialResolution;
  UserRegionPreference? _preference;
  Object? _error;

  void throwOnNextCall(Object error) => _error = error;

  void setPreference(UserRegionPreference? preference) => _preference = preference;

  UserRegionPreference? get preference => _preference;

  void setSpatialResolution(SpatialResolution resolution) =>
      _spatialResolution = resolution;

  @override
  Future<List<Region>> getGovernorates() async {
    _maybeThrow();
    return _governorates;
  }

  @override
  Future<List<Region>> getChildren(String parentRegionId) async {
    _maybeThrow();
    return _children;
  }

  @override
  Future<Region> getRegion(String regionId) async {
    _maybeThrow();
    return _governorates.firstWhere((r) => r.id == regionId);
  }

  @override
  Future<Region?> getRegionByCode(String code) async {
    _maybeThrow();
    for (final region in _governorates) {
      if (region.code == code) return region;
    }
    return null;
  }

  @override
  Future<List<Region>> searchRegions(String query) async {
    _maybeThrow();
    final q = query.toLowerCase();
    return _governorates
        .where((r) => (r.nameEn ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  Future<void> setUserRegion({
    required String userId,
    required String regionId,
    required RegionPreferenceSource source,
  }) async {
    _maybeThrow();
    _preference = UserRegionPreference(
      userId: userId,
      regionId: regionId,
      source: source,
      updatedAt: DateTime(2026, 8, 15),
    );
  }

  @override
  Future<UserRegionPreference?> getUserRegion(String userId) async {
    _maybeThrow();
    return _preference;
  }

  @override
  Future<List<GeoPlace>> getGeoPlaces({String? type, String? query}) async {
    _maybeThrow();
    var result = _geoPlaces;
    if (type != null) {
      result = result.where((p) => p.type.code == type).toList();
    }
    if (query != null && query.trim().isNotEmpty) {
      final q = query.toLowerCase();
      result = result
          .where(
            (p) =>
                (p.nameEn ?? '').toLowerCase().contains(q) ||
                (p.nameAr ?? '').contains(query),
          )
          .toList();
    }
    return result;
  }

  @override
  Future<GeoPlace?> getGeoPlace(String id) async {
    _maybeThrow();
    for (final place in _geoPlaces) {
      if (place.id == id) return place;
    }
    return null;
  }

  @override
  Future<SpatialResolution?> resolveRegionForPoint({
    required double lat,
    required double lon,
    int maxDepth = 2,
    double toleranceM = 25000,
  }) async {
    _maybeThrow();
    return _spatialResolution;
  }

  void _maybeThrow() {
    final error = _error;
    if (error != null) {
      _error = null;
      throw error;
    }
  }
}
