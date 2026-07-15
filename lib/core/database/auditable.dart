/// Audit trail mix-in for the Delwaqty platform.
///
/// Tracks who created and last updated an entity plus the optimistic-
/// concurrency version for safe concurrent modifications.
library;

/// Mix-in that adds audit fields to an entity.
mixin Auditable {
  /// ID of the user who created this entity.
  String? createdBy;

  /// ID of the user who last updated this entity.
  String? updatedBy;

  /// Optimistic-concurrency version counter.
  int version = 0;

  /// Increments [version] and sets [updatedBy].
  void touch({String? userId}) {
    version++;
    updatedBy = userId;
  }
}

/// A simple entity demonstrating [Auditable] usage.
class AuditableEntity with Auditable {
  /// Creates an [AuditableEntity].
  AuditableEntity({required this.id});

  /// The entity identifier.
  final String id;

  @override
  String toString() =>
      'AuditableEntity(id: $id, version: $version, createdBy: $createdBy, updatedBy: $updatedBy)';
}
