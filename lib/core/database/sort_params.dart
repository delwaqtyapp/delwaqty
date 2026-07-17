/// Sort parameter model for the Delwaqty platform.
///
/// Encapsulates field name and direction for ordered queries.
library;

/// Describes how results should be sorted.
class SortParams {
  /// Creates a [SortParams].
  const SortParams({required this.field, this.ascending = true});

  /// The field name to sort by.
  final String field;

  /// Whether to sort ascending (true) or descending (false).
  final bool ascending;

  /// Creates a [SortParams] from a [field] string with optional [ascending]
  /// flag (defaults to ascending).
  factory SortParams.fromField(String field, {bool ascending = true}) {
    return SortParams(field: field, ascending: ascending);
  }

  /// Returns a copy with the direction flipped.
  SortParams get reversed => SortParams(field: field, ascending: !ascending);

  @override
  String toString() => '${ascending ? 'ASC' : 'DESC'} $field';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SortParams &&
          runtimeType == other.runtimeType &&
          field == other.field &&
          ascending == other.ascending;

  @override
  int get hashCode => Object.hash(field, ascending);
}
