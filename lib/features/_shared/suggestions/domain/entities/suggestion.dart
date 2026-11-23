class Suggestion {
  const Suggestion({
    required this.id,
    required this.userId,
    this.appRole = 'customer',
    this.category = 'general',
    required this.subject,
    required this.description,
    this.status = 'pending',
    this.resolutionNote,
    required this.createdAt,
    this.updatedAt,
  });

  factory Suggestion.fromJson(Map<String, dynamic> json) {
    return Suggestion(
      id: json['id'] as String,
      userId: (json['user_id'] as String?) ?? '',
      appRole: (json['app_role'] as String?) ?? 'customer',
      category: (json['category'] as String?) ?? 'general',
      subject: (json['subject'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'pending',
      resolutionNote: json['resolution_note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  final String id;
  final String userId;
  final String appRole;
  final String category;
  final String subject;
  final String description;
  final String status;
  final String? resolutionNote;
  final DateTime createdAt;
  final DateTime? updatedAt;

  bool get isClosed =>
      const {'accepted', 'rejected', 'implemented'}.contains(status);

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'app_role': appRole,
    'category': category,
    'subject': subject,
    'description': description,
    'status': status,
    'resolution_note': resolutionNote,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };
}
