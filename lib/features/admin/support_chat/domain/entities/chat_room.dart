class ChatRoom {

  const ChatRoom({
    required this.id,
    required this.roomType,
    required this.participantIds,
    this.orderId,
    this.complaintId,
    this.isActive = true,
    this.status = 'open',
    this.priority = 'low',
    this.regionId,
    this.assignedAdminId,
    this.assignedAt,
    this.lastMessageAt,
    this.escalatedAt,
    this.escalatedFromAdminId,
    this.closedAt,
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
      status: json['status'] as String? ?? 'open',
      priority: json['priority'] as String? ?? 'low',
      regionId: json['region_id'] as String?,
      assignedAdminId: json['assigned_admin_id'] as String?,
      assignedAt: json['assigned_at'] != null
          ? DateTime.parse(json['assigned_at'] as String)
          : null,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      escalatedAt: json['escalated_at'] != null
          ? DateTime.parse(json['escalated_at'] as String)
          : null,
      escalatedFromAdminId: json['escalated_from_admin_id'] as String?,
      closedAt: json['closed_at'] != null
          ? DateTime.parse(json['closed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
  final String id;
  final String roomType;
  final List<String> participantIds;
  final String? orderId;
  final String? complaintId;
  final bool isActive;
  final String status;
  final String priority;
  final String? regionId;
  final String? assignedAdminId;
  final DateTime? assignedAt;
  final DateTime? lastMessageAt;
  final DateTime? escalatedAt;
  final String? escalatedFromAdminId;
  final DateTime? closedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'room_type': roomType,
    'participant_ids': participantIds,
    'order_id': orderId,
    'complaint_id': complaintId,
    'is_active': isActive,
    'status': status,
    'priority': priority,
    'region_id': regionId,
    'assigned_admin_id': assignedAdminId,
    'assigned_at': assignedAt?.toIso8601String(),
    'last_message_at': lastMessageAt?.toIso8601String(),
    'escalated_at': escalatedAt?.toIso8601String(),
    'escalated_from_admin_id': escalatedFromAdminId,
    'closed_at': closedAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };
}
