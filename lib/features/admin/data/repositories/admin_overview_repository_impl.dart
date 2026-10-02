import 'package:delwaqty/features/admin/data/datasources/remote/admin_overview_data_source.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_overview.dart';
import 'package:delwaqty/features/admin/domain/repositories/admin_overview_repository.dart';

class AdminOverviewRepositoryImpl implements AdminOverviewRepository {
  AdminOverviewRepositoryImpl(this._dataSource);

  final AdminOverviewDataSource _dataSource;

  @override
  Future<AdminOverviewStats> getStats() => _dataSource.fetchStats();
}