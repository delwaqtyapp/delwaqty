class ChatRoom {
  final String id;
  final String roomType;
  final List<String> participantIds;
  final String? orderId;
  final String? complaintId;
  final bool isActive;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ChatRoom({
    required this.id,
    required this.roomType,
    required this.participantIds,
    this.orderId,
    this.complaintId,
    this.isActive = true,
    this.lastMessageAt,
    required this.createdAt,
    this.updatedAt,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'] as String,
      roomType: json['room_type'] as String,
      participantIds: (json['participant_ids'] as List<dynamic>).cast<String>(),
      orderId: json['order_id'] as String?,
      complaintId: json['complaint_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      lastMessageAt: json['last_message_at'] != null ? DateTime.parse(json['last_message_at'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'room_type': roomType,
    'participant_ids': participantIds,
    'order_id': orderId,
    'complaint_id': complaintId,
    'is_active': isActive,
    'last_message_at': lastMessageAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };
}
