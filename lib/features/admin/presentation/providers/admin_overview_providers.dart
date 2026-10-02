import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/admin/data/datasources/remote/admin_overview_data_source.dart';
import 'package:delwaqty/features/admin/data/repositories/admin_overview_repository_impl.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_overview.dart';
import 'package:delwaqty/features/admin/domain/repositories/admin_overview_repository.dart';

final adminOverviewDataSourceProvider = Provider<AdminOverviewDataSource>((ref) {
  return AdminOverviewDataSource();
});

final adminOverviewRepositoryProvider = Provider<AdminOverviewRepository>((ref) {
  return AdminOverviewRepositoryImpl(ref.watch(adminOverviewDataSourceProvider));
});

final adminOverviewStatsProvider = FutureProvider<AdminOverviewStats>((ref) {
  return ref.watch(adminOverviewRepositoryProvider).getStats();
});