import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/features/_shared/suggestions/domain/entities/suggestion.dart';
import 'package:delwaqty/features/_shared/suggestions/domain/repositories/suggestions_repository.dart';
import 'package:delwaqty/features/_shared/suggestions/data/datasources/remote/supabase_suggestions_data_source.dart';
import 'package:delwaqty/features/_shared/suggestions/data/repositories/suggestions_repository_impl.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';

final supabaseSuggestionsDataSourceProvider =
    Provider<SupabaseSuggestionsDataSource>((ref) {
      return SupabaseSuggestionsDataSource(ref.watch(supabaseClientProvider));
    });

final suggestionsRepositoryProvider = Provider<SuggestionsRepository>((ref) {
  return SuggestionsRepositoryImpl(
    ref.read(supabaseSuggestionsDataSourceProvider),
  );
});

final mySuggestionsProvider = FutureProvider<List<Suggestion>>((ref) async {
  final repo = ref.read(suggestionsRepositoryProvider);
  final authState = ref.watch(authStateProvider);
  final user = authState is AuthAuthenticated ? authState.user : null;
  if (user == null) return [];
  return repo.getMySuggestions(user.id);
});

/// Admin triage page: one server-side page (status filter applied by the
/// RPC BEFORE the limit, so nothing is lost beyond the page size). The
/// admin page paginates with offset via load-more (#146).
typedef AdminSuggestionsQuery = ({String? status, int offset});

final adminSuggestionsPageProvider =
    FutureProvider.family<List<Suggestion>, AdminSuggestionsQuery>((
      ref,
      q,
    ) async {
      final repo = ref.read(suggestionsRepositoryProvider);
      return repo.adminListSuggestions(
        status: q.status,
        limit: 100,
        offset: q.offset,
      );
    });
