import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/features/customer/restaurant/data/datasources/remote/supabase_working_hours_data_source.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/working_hours.dart';
import 'package:delwaqty/features/customer/restaurant/domain/repositories/working_hours_repository.dart';

class WorkingHoursRepositoryImpl implements WorkingHoursRepository {
  WorkingHoursRepositoryImpl(this._dataSource);
  final SupabaseWorkingHoursDataSource _dataSource;

  @override
  Future<List<WorkingHours>> getHours(
    String merchantId, {
    String? branchId,
  }) async {
    try {
      return await _dataSource.getHours(merchantId, branchId: branchId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> setHours(List<WorkingHours> hours) async {
    try {
      await _dataSource.setHours(hours);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> deleteHours(String merchantId, {String? branchId}) async {
    try {
      await _dataSource.deleteHours(merchantId, branchId: branchId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
