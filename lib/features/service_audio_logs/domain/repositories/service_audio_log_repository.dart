import 'package:delwaqty/features/service_audio_logs/domain/entities/service_audio_log.dart';

abstract interface class ServiceAudioLogRepository {
  Future<List<ServiceAudioLog>> getLogsForUser(String userId);
  Future<List<ServiceAudioLog>> getLogsForOrder(String orderId);
  Future<List<ServiceAudioLog>> getAllLogs();
  Future<ServiceAudioLog> createLog(ServiceAudioLog log);
  Future<void> updateAudioUrl(String logId, String audioUrl, int duration, AudioLogStatus status);
}
