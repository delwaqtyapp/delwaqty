class EscalationEvent {

  const EscalationEvent({
    required this.id,
    required this.entityType,
    required this.entityId,
    this.fromAdminId,
    this.toAdminId,
    required this.actorId,
    required this.reason,
    this.previousScope,
    this.newScope,
    required this.createdAt,
  });

  factory EscalationEvent.fromJson(Map<String, dynamic> json) {
    return EscalationEvent(
      id: json['id'] as String,
      entityType: (json['entity_type'] as String?) ?? 'complaint',
      entityId: json['entity_id'] as String,
      fromAdminId: json['from_admin_id'] as String?,
      toAdminId: json['to_admin_id'] as String?,
      actorId: json['actor_id'] as String,
      reason: json['reason'] as String? ?? '',
      previousScope: json['previous_scope'] as String?,
      newScope: json['new_scope'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
  final String id;
  final String entityType;
  final String entityId;
  final String? fromAdminId;
  final String? toAdminId;
  final String actorId;
  final String reason;
  final String? previousScope;
  final String? newScope;
  final DateTime createdAt;

  bool get isOwnerQueue => toAdminId == null;
}
