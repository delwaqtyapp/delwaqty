import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/_shared/suggestions/domain/entities/suggestion.dart';

class SupabaseSuggestionsDataSource {
  SupabaseSuggestionsDataSource(this._client);
  final SupabaseClient _client;

  /// Only these columns are granted to authenticated on public.suggestions;
  /// admin_notes/reviewed_at/reviewed_by are internal and a select * fails.
  static const String mySuggestionColumns =
      'id,user_id,app_role,category,subject,description,status,resolution_note,created_at,updated_at';

  Future<String> submitSuggestion({
    required String subject,
    required String description,
    required String category,
    required String appRole,
  }) async {
    final id = await _client.rpc(
      'submit_suggestion',
      params: {
        'p_subject': subject,
        'p_description': description,
        'p_category': category,
        'p_app_role': appRole,
      },
    );
    return id as String;
  }

  Future<List<Suggestion>> getMySuggestions(String userId) async {
    final rows = await _client
        .from('suggestions')
        .select(mySuggestionColumns)
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return rows.map((r) => Suggestion.fromJson(r)).toList();
  }

  Future<List<Suggestion>> adminListSuggestions({
    String? status,
    int limit = 100,
    int offset = 0,
  }) async {
    final rows = await _client.rpc(
      'admin_list_suggestions',
      params: {'p_status': status, 'p_limit': limit, 'p_offset': offset},
    );
    return (rows as List<dynamic>)
        .map((r) => Suggestion.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> adminUpdateSuggestionStatus(
    String id,
    String status, {
    String? resolutionNote,
  }) async {
    await _client.rpc(
      'admin_update_suggestion_status',
      params: {
        'p_suggestion_id': id,
        'p_status': status,
        'p_resolution_note': resolutionNote,
      },
    );
  }
}
