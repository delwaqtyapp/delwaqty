import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/_shared/regions/domain/entities/region.dart';
import 'package:delwaqty/features/_shared/regions/domain/entities/geo_entity.dart';
import 'package:delwaqty/features/_shared/regions/domain/entities/spatial_resolution.dart';
import 'package:delwaqty/features/_shared/regions/domain/repositories/region_repository.dart';
import 'package:delwaqty/features/_shared/regions/domain/services/region_resolver.dart';
import 'package:delwaqty/features/_shared/regions/data/datasources/remote/supabase_region_data_source.dart';
import 'package:delwaqty/features/_shared/regions/data/repositories/region_repository_impl.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/customer/location/presentation/providers/location_provider.dart';

final supabaseRegionDataSourceProvider = Provider<RegionDataSource>((ref) {
  return SupabaseRegionDataSource(Supabase.instance.client);
});

final regionRepositoryProvider = Provider<RegionRepository>((ref) {
  return RegionRepositoryImpl(ref.watch(supabaseRegionDataSourceProvider));
});

final governoratesProvider = FutureProvider<List<Region>>((ref) {
  return ref.watch(regionRepositoryProvider).getGovernorates();
});

final regionChildrenProvider = FutureProvider.family<List<Region>, String>((
  ref,
  parentId,
) {
  return ref.watch(regionRepositoryProvider).getChildren(parentId);
});

final regionSearchProvider = FutureProvider.family<List<Region>, String>((
  ref,
  query,
) {
  final q = query.trim();
  if (q.isEmpty) return Future.value(<Region>[]);
  return ref.watch(regionRepositoryProvider).searchRegions(q);
});

final currentUserRegionProvider = FutureProvider<UserRegionPreference?>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState is AuthAuthenticated ? authState.user : null;
  if (user == null) return Future.value();
  return ref.watch(regionRepositoryProvider).getUserRegion(user.id);
});

/// Persists an explicit user selection (manual / verified).
final selectRegionProvider = Provider<
  Future<void> Function({
    required Region region,
    required RegionPreferenceSource source,
  })
>((ref) {
  return ({required Region region, required RegionPreferenceSource source}) async {
    final authState = ref.read(authStateProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    if (user == null) {
      throw const RegionException('Not authenticated');
    }
    await ref
        .read(regionRepositoryProvider)
        .setUserRegion(
          userId: user.id,
          regionId: region.id,
          source: source,
        );
    ref.invalidate(currentUserRegionProvider);
  };
});

/// Resolves the current GPS location to a canonical governorate (read-only).
final detectedRegionProvider = FutureProvider<Region?>((ref) async {
  final location = await ref.watch(userLocationProvider.future);
  if (location == null) return null;
  final governorates = await ref.watch(governoratesProvider.future);
  final regionId = RegionResolver.resolveGovernorateId(
    governorates: governorates,
    candidateStrings: [location.detailedAddress],
  );
  if (regionId == null) return null;
  return governorates.firstWhere((g) => g.id == regionId);
});

/// Geo-places search (tourism / transport / landmarks), optional type filter.
final geoPlacesProvider = FutureProvider.family<List<GeoPlace>, String?>((ref, type) {
  return ref.watch(regionRepositoryProvider).getGeoPlaces(type: type);
});

final geoPlaceSearchProvider = FutureProvider.family<List<GeoPlace>, String>((
  ref,
  query,
) {
  final q = query.trim();
  if (q.isEmpty) return Future.value(<GeoPlace>[]);
  return ref.watch(regionRepositoryProvider).getGeoPlaces(query: q);
});

/// Server-side spatial resolution of a GPS fix via the
/// `geo_region_for_point` RPC (PostGIS point-in-polygon / snapping).
final spatialResolutionProvider = FutureProvider.family<SpatialResolution?, ({double lat, double lon})>(
  (ref, coords) {
    return ref
        .watch(regionRepositoryProvider)
        .resolveRegionForPoint(lat: coords.lat, lon: coords.lon);
  },
);

/// Applies GPS detection, honoring the state-preservation + confidence gates.
final applyDetectedRegionProvider = Provider<Future<Region?> Function()>((ref) {
  return () async {
    final authState = ref.read(authStateProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    if (user == null) return null;

    final detected = await ref.read(detectedRegionProvider.future);
    if (detected == null) return null;

    final repository = ref.read(regionRepositoryProvider);
    final existing = await repository.getUserRegion(user.id);
    if (!RegionPreferencePolicy.shouldUpdate(
      existing: existing,
      incoming: RegionPreferenceSource.detected,
    )) {
      return null;
    }
    await repository.setUserRegion(
      userId: user.id,
      regionId: detected.id,
      source: RegionPreferenceSource.detected,
    );
    ref.invalidate(currentUserRegionProvider);
    return detected;
  };
});

/// Resolves the current GPS location via the server-side spatial RPC,
/// applying the ADR-057 confidence gates (never auto-persist LOW; MEDIUM only
/// when no preference exists; HIGH refines detected but never manual/verified).
/// Returns the resolution when it may be persisted as `detected`, else null.
final applySpatialDetectionProvider = Provider<Future<SpatialResolution?> Function()>(
  (ref) {
    return () async {
      final authState = ref.read(authStateProvider);
      final user = authState is AuthAuthenticated ? authState.user : null;
      if (user == null) return null;

      final location = await ref.read(userLocationProvider.future);
      if (location == null) return null;
      final resolution = await ref.read(
        spatialResolutionProvider(
          (lat: location.latitude, lon: location.longitude),
        ).future,
      );
      if (resolution == null ||
          resolution.confidence == GeoConfidence.invalid) {
        return null;
      }
      final regionId = resolution.regionId;
      if (regionId == null) return null;

      final repository = ref.read(regionRepositoryProvider);
      final existing = await repository.getUserRegion(user.id);
      if (!RegionPreferencePolicy.shouldPersistDetected(
        confidence: resolution.confidence,
        existing: existing,
      )) {
        return null;
      }
      await repository.setUserRegion(
        userId: user.id,
        regionId: regionId,
        source: RegionPreferenceSource.detected,
      );
      ref.invalidate(currentUserRegionProvider);
      return resolution;
    };
  },
);
