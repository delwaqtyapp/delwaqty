enum AudioLogStatus { recording, completed, failed }

class ServiceAudioLog {

  const ServiceAudioLog({
    required this.id,
    required this.orderId,
    required this.userId,
    this.providerId,
    this.audioUrl,
    this.durationSeconds,
    required this.createdAt,
    this.status = AudioLogStatus.recording,
  });

  factory ServiceAudioLog.fromJson(Map<String, dynamic> json) {
    return ServiceAudioLog(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      userId: json['user_id'] as String,
      providerId: json['provider_id'] as String?,
      audioUrl: json['audio_url'] as String?,
      durationSeconds: json['duration'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      status: _parseStatus(json['status'] as String?),
    );
  }
  final String id;
  final String orderId;
  final String userId;
  final String? providerId;
  final String? audioUrl;
  final int? durationSeconds;
  final DateTime createdAt;
  final AudioLogStatus status;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'user_id': userId,
      'provider_id': providerId,
      'audio_url': audioUrl,
      'duration': durationSeconds,
      'created_at': createdAt.toIso8601String(),
      'status': status.name,
    };
  }

  static AudioLogStatus _parseStatus(String? status) {
    switch (status) {
      case 'completed':
        return AudioLogStatus.completed;
      case 'failed':
        return AudioLogStatus.failed;
      default:
        return AudioLogStatus.recording;
    }
  }
}
