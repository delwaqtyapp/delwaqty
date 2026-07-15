/// Generic pagination model for the Delwaqty platform.
///
/// Contains [PageRequest] (what the caller asks for) and [PageResult]
/// (what the data layer returns), decoupling transport from domain.
library;

import 'package:delwaqty/core/database/sort_params.dart';

/// Describes a page of data the caller wants to fetch.
class PageRequest {
  /// Creates a [PageRequest].
  const PageRequest({
    this.page = 1,
    this.pageSize = 20,
    this.sortBy,
    this.sortOrder = const SortParams(field: 'createdAt'),
  });

  /// The zero-based page index.
  final int page;

  /// Number of items per page.
  final int pageSize;

  /// Optional field to sort by (free-text; the repository decides validity).
  final String? sortBy;

  /// Sort direction.
  final SortParams sortOrder;

  /// Shorthand for the first page.
  static const first = PageRequest();

  /// Returns a [PageRequest] for the next page.
  PageRequest get nextPage => PageRequest(
        page: page + 1,
        pageSize: pageSize,
        sortBy: sortBy,
        sortOrder: sortOrder,
      );

  /// Returns a [PageRequest] for the previous page, clamped to 0.
  PageRequest get previousPage => PageRequest(
        page: page > 0 ? page - 1 : 0,
        pageSize: pageSize,
        sortBy: sortBy,
        sortOrder: sortOrder,
      );

  @override
  String toString() =>
      'PageRequest(page: $page, pageSize: $pageSize, sortBy: $sortBy)';
}

/// Encapsulates a paginated response.
class PageResult<T> {
  /// Creates a [PageResult].
  const PageResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  /// The items on the current page.
  final List<T> items;

  /// Total number of items across all pages.
  final int total;

  /// The current page index (zero-based).
  final int page;

  /// Number of items per page.
  final int pageSize;

  /// Total number of pages.
  int get totalPages => pageSize == 0 ? 0 : (total / pageSize).ceil();

  /// Whether a next page exists.
  bool get hasNext => page + 1 < totalPages;

  /// Whether a previous page exists.
  bool get hasPrevious => page > 0;

  @override
  String toString() =>
      'PageResult(items: ${items.length}, total: $total, page: $page/$totalPages)';
}
