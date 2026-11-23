import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/_shared/suggestions/domain/entities/suggestion.dart';
import 'package:delwaqty/features/_shared/suggestions/presentation/suggestions_providers.dart';
import 'package:delwaqty/features/_shared/suggestions/presentation/pages/new_suggestion_page.dart';
import 'package:delwaqty/shared/widgets/glass_card.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';

class MySuggestionsPage extends ConsumerStatefulWidget {
  const MySuggestionsPage({super.key});

  @override
  ConsumerState<MySuggestionsPage> createState() => _MySuggestionsPageState();
}

class _MySuggestionsPageState extends ConsumerState<MySuggestionsPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final suggestionsAsync = ref.watch(mySuggestionsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mySuggestions)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/new-suggestion'),
        icon: const Icon(Icons.lightbulb_outline_rounded),
        label: Text(l10n.newSuggestion),
      ),
      body: suggestionsAsync.when(
        loading: () => const Center(child: AppLoaderCircular()),
        error: (e, _) => PremiumEmptyState(
          icon: Icons.error_outline,
          title: l10n.error,
          message: appErrorText(context, e),
          actionLabel: l10n.retry,
          onAction: () => ref.invalidate(mySuggestionsProvider),
        ),
        data: (suggestions) {
          if (suggestions.isEmpty) {
            return PremiumEmptyState(
              icon: Icons.lightbulb_outline_rounded,
              title: l10n.noSuggestions,
              message: l10n.noSuggestionsDescription,
              actionLabel: l10n.newSuggestion,
              onAction: () => context.push('/new-suggestion'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: suggestions.length,
            itemBuilder: (context, index) {
              final s = suggestions[index];
              final implemented = s.status == 'implemented';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AnimatedFadeIn(
                  child: GlassCard(
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: implemented
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          implemented ? Icons.check_circle : Icons.pending,
                          color: implemented ? Colors.green : Colors.orange,
                        ),
                      ),
                      title: Text(
                        s.subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${l10n.statusLabel}: ${suggestionStatusLabel(l10n, s.status)}',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showSuggestionDetail(context, l10n, s),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showSuggestionDetail(
    BuildContext context,
    AppLocalizations l10n,
    Suggestion suggestion,
  ) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        // Scrollable + height-bounded: descriptions run to 2000 chars, so a
        // plain Column would overflow on long Arabic text.
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.8,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion.subject,
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  suggestion.description,
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.circle, size: 8),
                    const SizedBox(width: 8),
                    Text(suggestionStatusLabel(l10n, suggestion.status)),
                  ],
                ),
                if (suggestion.resolutionNote != null &&
                    suggestion.resolutionNote!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    suggestion.resolutionNote!,
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(l10n.ok),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
