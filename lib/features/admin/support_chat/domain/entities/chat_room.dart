class ChatRoom {

  const ChatRoom({
    required this.id,
    required this.roomType,
    required this.participantIds,
    this.orderId,
    this.complaintId,
    this.regionId,
    this.isActive = true,
    this.status = 'open',
    this.lastActivity,
    this.assignedAdminId,
    this.closedAt,
    this.autoDeleteAt,
    this.welcomeMessage,
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
      regionId: json['region_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      status: json['status'] as String? ?? 'open',
      lastActivity: json['last_activity'] != null
          ? DateTime.parse(json['last_activity'] as String)
          : null,
      assignedAdminId: json['assigned_admin_id'] as String?,
      closedAt: json['closed_at'] != null
          ? DateTime.parse(json['closed_at'] as String)
          : null,
      autoDeleteAt: json['auto_delete_at'] != null
          ? DateTime.parse(json['auto_delete_at'] as String)
          : null,
      welcomeMessage: json['welcome_message'] as String?,
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
  final String? regionId;
  final bool isActive;
  final String status;
  final DateTime? lastActivity;
  final String? assignedAdminId;
  final DateTime? closedAt;
  final DateTime? autoDeleteAt;
  final String? welcomeMessage;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'room_type': roomType,
    'participant_ids': participantIds,
    'order_id': orderId,
    'complaint_id': complaintId,
    'region_id': regionId,
    'is_active': isActive,
    'status': status,
    'last_activity': lastActivity?.toIso8601String(),
    'assigned_admin_id': assignedAdminId,
    'closed_at': closedAt?.toIso8601String(),
    'auto_delete_at': autoDeleteAt?.toIso8601String(),
    'welcome_message': welcomeMessage,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };
}