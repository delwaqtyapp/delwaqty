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

/// Admin triage list. Fetches up to 500 (the RPC's clamp) newest first; the
/// admin page applies its status filter client-side, same as complaints.
final adminSuggestionsProvider = FutureProvider<List<Suggestion>>((ref) async {
  final repo = ref.read(suggestionsRepositoryProvider);
  return repo.adminListSuggestions(limit: 500);
});
