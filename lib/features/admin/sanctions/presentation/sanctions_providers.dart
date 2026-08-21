import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/admin/sanctions/domain/entities/sanction.dart';
import 'package:delwaqty/features/admin/sanctions/domain/repositories/sanctions_repository.dart';
import 'package:delwaqty/features/admin/sanctions/data/datasources/remote/supabase_sanctions_data_source.dart';
import 'package:delwaqty/features/admin/sanctions/data/repositories/sanctions_repository_impl.dart';

final supabaseSanctionsDataSourceProvider =
    Provider<SupabaseSanctionsDataSource>((ref) {
  return SupabaseSanctionsDataSource(Supabase.instance.client);
});

final sanctionsRepositoryProvider = Provider<SanctionsRepository>((ref) {
  return SanctionsRepositoryImpl(
    ref.read(supabaseSanctionsDataSourceProvider),
  );
});

final sanctionsProvider = FutureProvider<List<Sanction>>((ref) async {
  final repo = ref.read(sanctionsRepositoryProvider);
  return repo.getSanctions();
});

final activeSanctionsProvider = FutureProvider<List<Sanction>>((ref) async {
  final repo = ref.read(sanctionsRepositoryProvider);
  return repo.getSanctions(active: true);
});
