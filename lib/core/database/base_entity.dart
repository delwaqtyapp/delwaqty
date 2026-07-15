/// Base entity pattern for the Delwaqty platform.
///
/// Defines the common fields every persistence entity must carry:
/// UUID, timestamps, soft-delete marker, optimistic-concurrency version,
/// and arbitrary metadata.
library;

import 'package:delwaqty/core/database/uuid_generator.dart';

/// Abstract base class for all domain entities.
///
/// Subclass this (or use it as a mix-in target) to guarantee a consistent
/// persistence contract across the data layer.
abstract class BaseEntity {
  /// Creates a [BaseEntity].
  BaseEntity({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
    this.version = 0,
    this.metadata = const {},
  })  : id = id ?? UuidGenerator.generate(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Globally unique identifier (UUID v4).
  final String id;

  /// Timestamp when this entity was first persisted.
  final DateTime createdAt;

  /// Timestamp of the most recent update.
  DateTime updatedAt;

  /// Non-null when the entity has been soft-deleted.
  DateTime? deletedAt;

  /// Optimistic-concurrency version counter.
  int version;

  /// Arbitrary key-value metadata attached to this entity.
  Map<String, dynamic> metadata;

  /// Serialises the entity to a JSON-compatible map.
  Map<String, dynamic> toJson();

  /// Whether this entity has been soft-deleted.
  bool get isDeleted => deletedAt != null;
}
