import 'package:delwaqty/features/_shared/suggestions/domain/entities/suggestion.dart';

abstract class SuggestionsRepository {
  /// Creates a suggestion through the submit_suggestion RPC (the only write
  /// path; direct table insert is revoked). Returns the new suggestion id.
  Future<String> submitSuggestion({
    required String subject,
    required String description,
    required String category,
    required String appRole,
  });

  Future<List<Suggestion>> getMySuggestions(String userId);

  Future<List<Suggestion>> adminListSuggestions({
    String? status,
    String? appRole,
    int limit = 100,
    int offset = 0,
  });

  /// Passing a null resolutionNote clears a previous note (the server sets
  /// the column unconditionally).
  Future<void> adminUpdateSuggestionStatus(
    String id,
    String status, {
    String? resolutionNote,
  });

  /// Sets the issue/task link (https only); null or blank clears it.
  Future<void> adminSetSuggestionLink(String id, String? url);
}
