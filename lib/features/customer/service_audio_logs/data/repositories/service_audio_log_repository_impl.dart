import 'package:delwaqty/features/customer/service_audio_logs/domain/entities/service_audio_log.dart';
import 'package:delwaqty/features/customer/service_audio_logs/domain/repositories/service_audio_log_repository.dart';
import 'package:delwaqty/features/customer/service_audio_logs/data/datasources/remote/supabase_service_audio_log_data_source.dart';

class ServiceAudioLogRepositoryImpl implements ServiceAudioLogRepository {

  ServiceAudioLogRepositoryImpl(this._dataSource);
  final SupabaseServiceAudioLogDataSource _dataSource;

  @override
  Future<List<ServiceAudioLog>> getLogsForUser(String userId) {
    return _dataSource.getLogsForUser(userId);
  }

  @override
  Future<List<ServiceAudioLog>> getLogsForOrder(String orderId) {
    return _dataSource.getLogsForOrder(orderId);
  }

  @override
  Future<List<ServiceAudioLog>> getAllLogs() {
    return _dataSource.getAllLogs();
  }

  @override
  Future<ServiceAudioLog> createLog(ServiceAudioLog log) {
    return _dataSource.createLog(log);
  }

  @override
  Future<void> updateAudioUrl(String logId, String audioUrl, int duration, AudioLogStatus status) {
    return _dataSource.updateAudioUrl(logId, audioUrl, duration, status);
  }
}
