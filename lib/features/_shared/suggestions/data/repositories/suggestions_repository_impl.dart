import 'package:delwaqty/features/_shared/suggestions/domain/entities/suggestion.dart';
import 'package:delwaqty/features/_shared/suggestions/domain/repositories/suggestions_repository.dart';
import 'package:delwaqty/features/_shared/suggestions/data/datasources/remote/supabase_suggestions_data_source.dart';

class SuggestionsRepositoryImpl implements SuggestionsRepository {
  SuggestionsRepositoryImpl(this._dataSource);
  final SupabaseSuggestionsDataSource _dataSource;

  @override
  Future<String> submitSuggestion({
    required String subject,
    required String description,
    required String category,
    required String appRole,
  }) {
    return _dataSource.submitSuggestion(
      subject: subject,
      description: description,
      category: category,
      appRole: appRole,
    );
  }

  @override
  Future<List<Suggestion>> getMySuggestions(String userId) {
    return _dataSource.getMySuggestions(userId);
  }

  @override
  Future<List<Suggestion>> adminListSuggestions({
    String? status,
    String? appRole,
    int limit = 100,
    int offset = 0,
  }) {
    return _dataSource.adminListSuggestions(
      status: status,
      appRole: appRole,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<void> adminUpdateSuggestionStatus(
    String id,
    String status, {
    String? resolutionNote,
  }) {
    return _dataSource.adminUpdateSuggestionStatus(
      id,
      status,
      resolutionNote: resolutionNote,
    );
  }

  @override
  Future<void> adminTriageSuggestion(
    String id,
    String status, {
    String? resolutionNote,
    String? linkedUrl,
    bool updateLink = false,
  }) {
    return _dataSource.adminTriageSuggestion(
      id,
      status,
      resolutionNote: resolutionNote,
      linkedUrl: linkedUrl,
      updateLink: updateLink,
    );
  }
}
