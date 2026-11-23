import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/config/app_mode_provider.dart';
import 'package:delwaqty/features/_shared/suggestions/presentation/suggestions_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class NewSuggestionPage extends ConsumerStatefulWidget {
  const NewSuggestionPage({super.key});

  @override
  ConsumerState<NewSuggestionPage> createState() => _NewSuggestionPageState();
}

class _NewSuggestionPageState extends ConsumerState<NewSuggestionPage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _category = 'general';
  bool _submitting = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.newSuggestion)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _subjectController,
                maxLength: 120,
                decoration: InputDecoration(
                  labelText: l10n.suggestionSubject,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? l10n.requiredField : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: InputDecoration(
                  labelText: l10n.suggestionCategory,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: ['general', 'app', 'feature', 'payment', 'other']
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(suggestionCategoryLabel(l10n, s)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLength: 2000,
                decoration: InputDecoration(
                  labelText: l10n.suggestionDescription,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 5,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? l10n.requiredField : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submitSuggestion,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.suggestionSubmit),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitSuggestion() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final repo = ref.read(suggestionsRepositoryProvider);
      await repo.submitSuggestion(
        subject: _subjectController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _category,
        appRole: ref.read(appFlavorProvider).name,
      );
      ref.invalidate(mySuggestionsProvider);

      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.suggestionSent)));
        navigator.pop();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.error)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

String suggestionCategoryLabel(AppLocalizations l10n, String category) {
  switch (category) {
    case 'general':
      return l10n.suggestionCategoryGeneral;
    case 'app':
      return l10n.suggestionCategoryApp;
    case 'feature':
      return l10n.suggestionCategoryFeature;
    case 'payment':
      return l10n.suggestionCategoryPayment;
    case 'other':
      return l10n.suggestionCategoryOther;
    default:
      return category;
  }
}

String suggestionStatusLabel(AppLocalizations l10n, String status) {
  switch (status) {
    case 'pending':
      return l10n.suggestionStatusPending;
    case 'reviewing':
      return l10n.suggestionStatusReviewing;
    case 'accepted':
      return l10n.suggestionStatusAccepted;
    case 'rejected':
      return l10n.suggestionStatusRejected;
    case 'implemented':
      return l10n.suggestionStatusImplemented;
    default:
      return status;
  }
}
