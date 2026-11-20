import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/features/_shared/complaints/domain/entities/complaint.dart';
import 'package:delwaqty/features/_shared/complaints/domain/repositories/complaints_repository.dart';
import 'package:delwaqty/features/_shared/complaints/data/datasources/remote/supabase_complaints_data_source.dart';
import 'package:delwaqty/features/_shared/complaints/data/repositories/complaints_repository_impl.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';

final supabaseComplaintsDataSourceProvider =
    Provider<SupabaseComplaintsDataSource>((ref) {
      return SupabaseComplaintsDataSource(ref.watch(supabaseClientProvider));
    });

final complaintsRepositoryProvider = Provider<ComplaintsRepository>((ref) {
  return ComplaintsRepositoryImpl(
    ref.read(supabaseComplaintsDataSourceProvider),
  );
});

final complaintsProvider = FutureProvider<List<Complaint>>((ref) async {
  final repo = ref.read(complaintsRepositoryProvider);
  return repo.getComplaints();
});

final myComplaintsProvider = FutureProvider<List<Complaint>>((ref) async {
  final repo = ref.read(complaintsRepositoryProvider);
  final authState = ref.watch(authStateProvider);
  final user = authState is AuthAuthenticated ? authState.user : null;
  if (user == null) return [];
  return repo.getMyComplaints(user.id);
});
