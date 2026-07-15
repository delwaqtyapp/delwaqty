/// Soft-delete mix-in for the Delwaqty platform.
///
/// Entities that mix in [SoftDeletable] gain the ability to be logically
/// removed without physical deletion, enabling audit trails and recovery.
library;

/// Mix-in that adds soft-delete capability to an entity.
///
/// The entity must provide a mutable [deletedAt] field.
mixin SoftDeletable {
  /// Timestamp when this entity was soft-deleted.
  DateTime? deletedAt;

  /// Marks this entity as deleted by setting [deletedAt] to now.
  void markDeleted() {
    deletedAt = DateTime.now();
  }

  /// Whether this entity has been soft-deleted.
  bool get isDeleted => deletedAt != null;

  /// Restores a soft-deleted entity by clearing [deletedAt].
  void restore() {
    deletedAt = null;
  }
}

/// A simple entity that demonstrates [SoftDeletable] usage.
class SoftDeletableEntity with SoftDeletable {
  /// Creates a [SoftDeletableEntity].
  SoftDeletableEntity({required this.id});

  /// The entity identifier.
  final String id;

  @override
  String toString() => 'SoftDeletableEntity(id: $id, deleted: $isDeleted)';
}
