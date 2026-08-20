import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/customer/service_audio_logs/domain/entities/service_audio_log.dart';
import 'package:delwaqty/features/customer/service_audio_logs/domain/repositories/service_audio_log_repository.dart';
import 'package:delwaqty/features/customer/service_audio_logs/data/datasources/remote/supabase_service_audio_log_data_source.dart';
import 'package:delwaqty/features/customer/service_audio_logs/data/repositories/service_audio_log_repository_impl.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/core/auth/admin_access.dart';

final supabaseAudioLogDataSourceProvider = Provider<SupabaseServiceAudioLogDataSource>((ref) {
  return SupabaseServiceAudioLogDataSource(Supabase.instance.client);
});

final serviceAudioLogRepositoryProvider = Provider<ServiceAudioLogRepository>((ref) {
  return ServiceAudioLogRepositoryImpl(ref.read(supabaseAudioLogDataSourceProvider));
});

final serviceAudioLogsProvider = FutureProvider<List<ServiceAudioLog>>((ref) async {
  final repo = ref.read(serviceAudioLogRepositoryProvider);
  final authState = ref.watch(authStateProvider);
  final user = authState is AuthAuthenticated ? authState.user : null;
  if (user == null) return [];
  if (user.isAdmin) {
    return repo.getAllLogs();
  }
  return repo.getLogsForUser(user.id);
});

final serviceAudioLogsForOrderProvider = FutureProvider.family<List<ServiceAudioLog>, String>((
  ref,
  orderId,
) async {
  final repo = ref.read(serviceAudioLogRepositoryProvider);
  return repo.getLogsForOrder(orderId);
});
