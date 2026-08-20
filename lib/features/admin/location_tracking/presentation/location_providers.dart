import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/admin/location_tracking/domain/entities/location_update.dart';
import 'package:delwaqty/features/admin/location_tracking/domain/repositories/location_repository.dart';
import 'package:delwaqty/features/admin/location_tracking/data/datasources/remote/supabase_location_data_source.dart';
import 'package:delwaqty/features/admin/location_tracking/data/repositories/location_repository_impl.dart';

final supabaseLocationDataSourceProvider = Provider<SupabaseLocationDataSource>((ref) {
  return SupabaseLocationDataSource(Supabase.instance.client);
});

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepositoryImpl(ref.read(supabaseLocationDataSourceProvider));
});

final activeDriversLocationProvider = FutureProvider<List<LocationUpdate>>((ref) async {
  final repo = ref.read(locationRepositoryProvider);
  return repo.getActiveDrivers();
});
