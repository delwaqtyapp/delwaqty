import 'package:delwaqty/features/admin/domain/entities/admin_overview.dart';

abstract interface class AdminOverviewRepository {
  Future<AdminOverviewStats> getStats();
}