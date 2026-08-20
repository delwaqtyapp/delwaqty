import 'package:delwaqty/features/customer/restaurant/domain/entities/working_hours.dart';

abstract interface class WorkingHoursRepository {
  Future<List<WorkingHours>> getHours(String merchantId, {String? branchId});
  Future<void> setHours(List<WorkingHours> hours);
  Future<void> deleteHours(String merchantId, {String? branchId});
}
