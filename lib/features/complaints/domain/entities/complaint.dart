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
    required this.createdAt,
    this.updatedAt,
  });

  factory Complaint.fromJson(Map<String, dynamic> json) {
    return Complaint(
      id: json['id'] as String,
      orderId: json['order_id'] as String?,
      complainantId: json['complainant_id'] as String,
      respondentId: json['respondent_id'] as String?,
      complaintType: json['complaint_type'] as String,
      subject: json['subject'] as String,
      description: json['description'] as String,
      attachments: (json['attachments'] as List<dynamic>?)?.cast<String>() ?? [],
      status: json['status'] as String? ?? 'pending',
      priority: json['priority'] as String? ?? 'medium',
      adminNotes: (json['admin_notes'] as List<dynamic>?)?.cast<String>() ?? [],
      resolutionNote: json['resolution_note'] as String?,
      resolvedAt: json['resolved_at'] != null ? DateTime.parse(json['resolved_at'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
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
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };
}
