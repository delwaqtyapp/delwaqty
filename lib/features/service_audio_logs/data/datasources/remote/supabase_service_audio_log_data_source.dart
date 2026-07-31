import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/service_audio_logs/domain/entities/service_audio_log.dart';

class SupabaseServiceAudioLogDataSource {
  final SupabaseClient _client;
  final String _bucketName = 'service-audio-logs';

  SupabaseServiceAudioLogDataSource(this._client);

  Future<List<ServiceAudioLog>> getLogsForUser(String userId) async {
    final rows = await _client
        .from('service_audio_logs')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return rows.map((row) => ServiceAudioLog.fromJson(row)).toList();
  }

  Future<List<ServiceAudioLog>> getLogsForOrder(String orderId) async {
    final rows = await _client
        .from('service_audio_logs')
        .select()
        .eq('order_id', orderId)
        .order('created_at', ascending: false);
    return rows.map((row) => ServiceAudioLog.fromJson(row)).toList();
  }

  Future<List<ServiceAudioLog>> getAllLogs() async {
    final rows = await _client
        .from('service_audio_logs')
        .select()
        .order('created_at', ascending: false);
    return rows.map((row) => ServiceAudioLog.fromJson(row)).toList();
  }

  Future<ServiceAudioLog> createLog(ServiceAudioLog log) async {
    await _client.from('service_audio_logs').insert(log.toJson());
    return log;
  }

  Future<void> updateAudioUrl(String logId, String audioUrl, int duration, AudioLogStatus status) async {
    await _client.from('service_audio_logs').update({
      'audio_url': audioUrl,
      'duration': duration,
      'status': status.name,
    }).eq('id', logId);
  }

  Future<String> uploadAudio(String logId, String filePath) async {
    final bytes = await _client.storage.from(_bucketName).download(filePath);
    final fileName = '$logId-${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _client.storage.from(_bucketName).uploadBinary(fileName, bytes);
    final url = _client.storage.from(_bucketName).getPublicUrl(fileName);
    return url;
  }
}
