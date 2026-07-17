/// Audit trail for the Delwaqty platform.
///
/// Records who did what, when, and on which resource so that all
/// significant actions can be traced for compliance and debugging.
library;

import 'dart:convert';

/// A single audit log entry.
class AuditEntry {
  /// Creates an [AuditEntry].
  const AuditEntry({
    required this.id,
    required this.action,
    this.resource,
    this.resourceId,
    this.userId,
    this.details,
    this.metadata,
    required this.timestamp,
  });

  /// Unique identifier for this entry.
  final String id;

  /// The action performed (e.g., 'order.created', 'user.updated').
  final String action;

  /// The resource type affected.
  final String? resource;

  /// The ID of the specific resource instance.
  final String? resourceId;

  /// The user who performed the action.
  final String? userId;

  /// Human-readable detail string.
  final String? details;

  /// Arbitrary key-value metadata.
  final Map<String, dynamic>? metadata;

  /// When this entry was recorded.
  final DateTime timestamp;

  @override
  String toString() => '[${timestamp.toIso8601String()}] $action by $userId';
}

/// Abstract interface for audit logging.
abstract class AuditLogger {
  /// Records an audit entry.
  void log(
    String action, {
    String? resource,
    String? resourceId,
    String? userId,
    String? details,
    Map<String, dynamic>? metadata,
  });

  /// Retrieves audit entries matching the given filters.
  List<AuditEntry> getAuditLog({
    String? userId,
    String? resource,
    DateTime? since,
    int? limit,
  });

  /// Exports the audit log in the given [format] (e.g., 'json', 'csv').
  String export(String format);
}

/// In-memory implementation of [AuditLogger].
class InMemoryAuditLogger extends AuditLogger {
  final List<AuditEntry> _entries = [];
  int _counter = 0;

  @override
  void log(
    String action, {
    String? resource,
    String? resourceId,
    String? userId,
    String? details,
    Map<String, dynamic>? metadata,
  }) {
    _entries.add(
      AuditEntry(
        id: 'audit-${++_counter}',
        action: action,
        resource: resource,
        resourceId: resourceId,
        userId: userId,
        details: details,
        metadata: metadata,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  List<AuditEntry> getAuditLog({
    String? userId,
    String? resource,
    DateTime? since,
    int? limit,
  }) {
    var filtered = _entries.where((e) {
      if (userId != null && e.userId != userId) return false;
      if (resource != null && e.resource != resource) return false;
      if (since != null && e.timestamp.isBefore(since)) return false;
      return true;
    }).toList();

    if (limit != null && filtered.length > limit) {
      filtered = filtered.sublist(0, limit);
    }

    return List.unmodifiable(filtered);
  }

  @override
  String export(String format) {
    switch (format) {
      case 'json':
        return jsonEncode(_entries.map(_entryToMap).toList());
      case 'csv':
        return _toCsv();
      default:
        throw ArgumentError('Unsupported export format: $format');
    }
  }

  Map<String, dynamic> _entryToMap(AuditEntry e) => {
    'id': e.id,
    'action': e.action,
    'resource': e.resource,
    'resourceId': e.resourceId,
    'userId': e.userId,
    'details': e.details,
    'metadata': e.metadata,
    'timestamp': e.timestamp.toIso8601String(),
  };

  String _toCsv() {
    final buffer = StringBuffer(
      'id,action,resource,resourceId,userId,details,timestamp\n',
    );
    for (final e in _entries) {
      buffer.writeln(
        '${e.id},${e.action},${e.resource ?? ''},${e.resourceId ?? ''},${e.userId ?? ''},${e.details ?? ''},${e.timestamp.toIso8601String()}',
      );
    }
    return buffer.toString();
  }
}

/// No-op audit logger for tests.
class NoOpAuditLogger extends AuditLogger {
  @override
  void log(
    String action, {
    String? resource,
    String? resourceId,
    String? userId,
    String? details,
    Map<String, dynamic>? metadata,
  }) {}

  @override
  List<AuditEntry> getAuditLog({
    String? userId,
    String? resource,
    DateTime? since,
    int? limit,
  }) => [];

  @override
  String export(String format) => '';
}
