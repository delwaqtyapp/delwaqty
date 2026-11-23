import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/_shared/suggestions/domain/entities/suggestion.dart';
import 'package:delwaqty/features/_shared/suggestions/presentation/suggestions_providers.dart';
import 'package:delwaqty/features/_shared/suggestions/presentation/pages/new_suggestion_page.dart';
import 'package:delwaqty/shared/widgets/glass_card.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';

class AdminSuggestionsPage extends ConsumerStatefulWidget {
  const AdminSuggestionsPage({super.key});

  @override
  ConsumerState<AdminSuggestionsPage> createState() =>
      _AdminSuggestionsPageState();
}

class _AdminSuggestionsPageState extends ConsumerState<AdminSuggestionsPage> {
  String _statusFilter = 'all';

  static const _statuses = [
    'pending',
    'reviewing',
    'accepted',
    'rejected',
    'implemented',
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final suggestionsAsync = ref.watch(adminSuggestionsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminSuggestionsTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _statusFilter,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.status,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: ['all', ..._statuses]
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(
                              s == 'all'
                                  ? l10n.all
                                  : suggestionStatusLabel(l10n, s),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _statusFilter = v!),
                  ),
                ),
                IconButton(
                  tooltip: l10n.refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => ref.invalidate(adminSuggestionsProvider),
                ),
              ],
            ),
          ),
          Expanded(
            child: suggestionsAsync.when(
              loading: () => const Center(child: AppLoaderCircular()),
              error: (e, _) => PremiumEmptyState(
                icon: Icons.error_outline,
                title: l10n.error,
                message: appErrorText(context, e),
                actionLabel: l10n.retry,
                onAction: () => ref.invalidate(adminSuggestionsProvider),
              ),
              data: (suggestions) {
                final filtered = _statusFilter == 'all'
                    ? suggestions
                    : suggestions
                          .where((s) => s.status == _statusFilter)
                          .toList();
                if (filtered.isEmpty) {
                  return PremiumEmptyState(
                    icon: Icons.lightbulb_outline_rounded,
                    title: l10n.noSuggestions,
                    message: l10n.noSuggestionsDescription,
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return _SuggestionTile(
                      suggestion: filtered[index],
                      cs: cs,
                      l10n: l10n,
                      onTap: () => _showSuggestionDetail(filtered[index]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSuggestionDetail(Suggestion suggestion) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SuggestionTriageSheet(
        suggestion: suggestion,
        onStatusChanged: () => ref.invalidate(adminSuggestionsProvider),
      ),
    );
  }
}

Color _suggestionStatusColor(ColorScheme cs, String status) {
  switch (status) {
    case 'pending':
      return cs.tertiary;
    case 'reviewing':
      return Colors.orange;
    case 'accepted':
      return Colors.green;
    case 'rejected':
      return Colors.red;
    case 'implemented':
      return Colors.deepPurple;
    default:
      return cs.onSurface;
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.suggestion,
    required this.cs,
    required this.l10n,
    required this.onTap,
  });
  final Suggestion suggestion;
  final ColorScheme cs;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedFadeIn(
        child: GlassCard(
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _suggestionStatusColor(
                  cs,
                  suggestion.status,
                ).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.lightbulb_outline_rounded,
                color: _suggestionStatusColor(cs, suggestion.status),
              ),
            ),
            title: Text(
              suggestion.subject,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${suggestionCategoryLabel(l10n, suggestion.category)} · '
              '${suggestionStatusLabel(l10n, suggestion.status)} · '
              '${suggestion.appRole}',
              maxLines: 1,
            ),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}

class _SuggestionTriageSheet extends ConsumerStatefulWidget {
  const _SuggestionTriageSheet({
    required this.suggestion,
    required this.onStatusChanged,
  });
  final Suggestion suggestion;
  final VoidCallback onStatusChanged;

  @override
  ConsumerState<_SuggestionTriageSheet> createState() =>
      _SuggestionTriageSheetState();
}

class _SuggestionTriageSheetState
    extends ConsumerState<_SuggestionTriageSheet> {
  final _noteController = TextEditingController();
  String _selectedStatus = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.suggestion.status;
    _noteController.text = widget.suggestion.resolutionNote ?? '';
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = widget.suggestion;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(s.subject, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                s.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(
                      '${l10n.suggestionCategory}: '
                      '${suggestionCategoryLabel(l10n, s.category)}',
                    ),
                  ),
                  Chip(label: Text(s.appRole)),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue:
                    _AdminSuggestionsPageState._statuses.contains(
                      _selectedStatus,
                    )
                    ? _selectedStatus
                    : null,
                decoration: InputDecoration(labelText: l10n.updateStatus),
                items: _AdminSuggestionsPageState._statuses
                    .map(
                      (st) => DropdownMenuItem(
                        value: st,
                        child: Text(suggestionStatusLabel(l10n, st)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedStatus = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.suggestionResolutionNote,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.save),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final repo = ref.read(suggestionsRepositoryProvider);
      final note = _noteController.text.trim();
      // An empty note is sent as NULL, which clears a previous note.
      await repo.adminUpdateSuggestionStatus(
        widget.suggestion.id,
        _selectedStatus,
        resolutionNote: note.isEmpty ? null : note,
      );
      widget.onStatusChanged();
      if (mounted) navigator.pop();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.somethingWentWrong)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
