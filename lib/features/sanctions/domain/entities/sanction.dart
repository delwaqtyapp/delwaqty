class Sanction {
  final String id;
  final String targetUserId;
  final String targetRole;
  final String sanctionType;
  final String? complaintId;
  final String reason;
  final double amount;
  final int durationDays;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final String? notes;
  final String issuedBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Sanction({
    required this.id,
    required this.targetUserId,
    required this.targetRole,
    required this.sanctionType,
    this.complaintId,
    required this.reason,
    this.amount = 0,
    this.durationDays = 0,
    required this.startDate,
    this.endDate,
    this.isActive = true,
    this.notes,
    required this.issuedBy,
    required this.createdAt,
    this.updatedAt,
  });

  factory Sanction.fromJson(Map<String, dynamic> json) {
    return Sanction(
      id: json['id'] as String,
      targetUserId: json['target_user_id'] as String,
      targetRole: json['target_role'] as String,
      sanctionType: json['sanction_type'] as String,
      complaintId: json['complaint_id'] as String?,
      reason: json['reason'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      durationDays: json['duration_days'] as int? ?? 0,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date'] as String) : null,
      isActive: json['is_active'] as bool? ?? true,
      notes: json['notes'] as String?,
      issuedBy: json['issued_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'target_user_id': targetUserId,
    'target_role': targetRole,
    'sanction_type': sanctionType,
    'complaint_id': complaintId,
    'reason': reason,
    'amount': amount,
    'duration_days': durationDays,
    'start_date': startDate.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
    'is_active': isActive,
    'notes': notes,
    'issued_by': issuedBy,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };
}
