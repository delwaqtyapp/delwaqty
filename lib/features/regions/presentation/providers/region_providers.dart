import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/regions/domain/entities/region.dart';
import 'package:delwaqty/features/regions/domain/repositories/region_repository.dart';
import 'package:delwaqty/features/regions/domain/services/region_resolver.dart';
import 'package:delwaqty/features/regions/data/datasources/remote/supabase_region_data_source.dart';
import 'package:delwaqty/features/regions/data/repositories/region_repository_impl.dart';
import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/features/location/presentation/providers/location_provider.dart';

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

/// Applies GPS detection, honoring the state-preservation policy.
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
