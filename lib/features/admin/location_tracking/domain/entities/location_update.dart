class LocationUpdate {

  const LocationUpdate({
    required this.id,
    required this.userId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.speed,
    this.heading,
    this.isMoving = false,
    required this.recordedAt,
  });

  factory LocationUpdate.fromJson(Map<String, dynamic> json) {
    return LocationUpdate(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      isMoving: json['is_moving'] as bool? ?? false,
      recordedAt: DateTime.parse(json['recorded_at'] as String),
    );
  }
  final String id;
  final String userId;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final bool isMoving;
  final DateTime recordedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'speed': speed,
    'heading': heading,
    'is_moving': isMoving,
    'recorded_at': recordedAt.toIso8601String(),
  };
}
