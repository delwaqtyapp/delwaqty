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

// The admin triage list intentionally has no cached provider (#147): the
// admin page fetches fresh pages from the repository with a generation
// guard, so refresh/retry/after-triage can never serve stale rows.
