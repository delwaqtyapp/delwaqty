import 'package:delwaqty/features/regions/domain/entities/region.dart';
import 'package:delwaqty/features/regions/domain/repositories/region_repository.dart';

/// In-memory fake used by widget tests. Mirrors the hand-rolled mock
/// repository pattern already used for notifications.
class MockRegionRepository implements RegionRepository {
  MockRegionRepository({
    List<Region>? governorates,
    List<Region>? children,
    this._preference,
  }) : _governorates = governorates ?? [],
       _children = children ?? [];

  final List<Region> _governorates;
  final List<Region> _children;
  UserRegionPreference? _preference;
  Object? _error;

  void throwOnNextCall(Object error) => _error = error;

  void setPreference(UserRegionPreference? preference) => _preference = preference;

  UserRegionPreference? get preference => _preference;

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

  void _maybeThrow() {
    final error = _error;
    if (error != null) {
      _error = null;
      throw error;
    }
  }
}
