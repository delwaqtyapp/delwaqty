class Complaint {
  final String id;
  final String? orderId;
  final String complainantId;
  final String? respondentId;
  final String complaintType;
  final String subject;
  final String description;
  final List<String> attachments;
  final String status;
  final String priority;
  final List<String> adminNotes;
  final String? resolutionNote;
  final DateTime? resolvedAt;
  final String? assignedAdminId;
  final DateTime? escalatedAt;
  final String? escalatedFromAdminId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Complaint({
    required this.id,
    this.orderId,
    required this.complainantId,
    this.respondentId,
    required this.complaintType,
    required this.subject,
    required this.description,
    this.attachments = const [],
    this.status = 'pending',
    this.priority = 'medium',
    this.adminNotes = const [],
    this.resolutionNote,
    this.resolvedAt,
    this.assignedAdminId,
    this.escalatedAt,
    this.escalatedFromAdminId,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isClosed =>
      const {'resolved', 'rejected', 'dismissed'}.contains(status);

  factory Complaint.fromJson(Map<String, dynamic> json) {
    return Complaint(
      id: json['id'] as String,
      orderId: json['order_id'] as String?,
      complainantId:
          (json['complainant_id'] as String?) ??
          (json['reporter_id'] as String?) ??
          '',
      respondentId: json['respondent_id'] as String?,
      complaintType: (json['complaint_type'] as String?) ?? 'other',
      subject:
          (json['subject'] as String?) ?? (json['category'] as String?) ?? '',
      description: json['description'] as String,
      attachments:
          (json['attachments'] as List<dynamic>?)?.cast<String>() ?? [],
      status: json['status'] as String? ?? 'pending',
      priority: json['priority'] as String? ?? 'medium',
      adminNotes: (json['admin_notes'] as List<dynamic>?)?.cast<String>() ?? [],
      resolutionNote: json['resolution_note'] as String?,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      assignedAdminId: json['assigned_admin_id'] as String?,
      escalatedAt: json['escalated_at'] != null
          ? DateTime.parse(json['escalated_at'] as String)
          : null,
      escalatedFromAdminId: json['escalated_from_admin_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'order_id': orderId,
    'complainant_id': complainantId,
    'respondent_id': respondentId,
    'complaint_type': complaintType,
    'subject': subject,
    'description': description,
    'attachments': attachments,
    'status': status,
    'priority': priority,
    'admin_notes': adminNotes,
    'resolution_note': resolutionNote,
    'resolved_at': resolvedAt?.toIso8601String(),
    'assigned_admin_id': assignedAdminId,
    'escalated_at': escalatedAt?.toIso8601String(),
    'escalated_from_admin_id': escalatedFromAdminId,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };
}
