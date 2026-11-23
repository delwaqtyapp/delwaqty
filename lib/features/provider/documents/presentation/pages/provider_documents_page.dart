import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

import '../providers/provider_documents_providers.dart';

import 'package:delwaqty/core/errors/app_error_text.dart';

class ProviderDocumentsPage extends ConsumerStatefulWidget {
  const ProviderDocumentsPage({super.key});

  @override
  ConsumerState<ProviderDocumentsPage> createState() =>
      _ProviderDocumentsPageState();
}

class _ProviderDocumentsPageState extends ConsumerState<ProviderDocumentsPage> {
  bool _busy = false;
  String? _busyKey;
  String? _error;
  String? _viewUrl;

  Future<void> _upload(String docType, String label) async {
    final l10n = AppLocalizations.of(context);
    if (_busy) return;
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result.isEmpty) return;
    final file = result.first;
    setState(() {
      _busy = true;
      _busyKey = docType;
      _error = null;
    });
    try {
      final bytes = await file.readAsBytes();
      final path = await ref
          .read(providerDocumentsRepositoryProvider)
          .uploadDoc('${docType}_${file.name}', bytes);
      await ref
          .read(providerDocumentsRepositoryProvider)
          .upsertDocument(docType, path);
      if (mounted) {
        ref.invalidate(providerDocumentsProvider);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.uploadedForReview(label))));
      }
    } catch (e) {
      if (mounted) setState(() => _error = appErrorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(String docType, String label) async {
    final l10n = AppLocalizations.of(context);
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text('${l10n.areYouSureYouWantToDelete} $label?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dlgCtx).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _busyKey = docType;
      _error = null;
    });
    try {
      await ref
          .read(providerDocumentsRepositoryProvider)
          .deleteDocument(docType);
      if (mounted) {
        ref.invalidate(providerDocumentsProvider);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.docRemoved(label))));
      }
    } catch (e) {
      if (mounted) setState(() => _error = appErrorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _view(String path) async {
    try {
      final url = await ref
          .read(providerDocumentsRepositoryProvider)
          .getDocumentUrl(path);
      if (mounted) setState(() => _viewUrl = url);
    } catch (e) {
      if (mounted) setState(() => _error = appErrorText(context, e));
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'verified':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _docLabel(String key) {
    final l10n = AppLocalizations.of(context);
    switch (key) {
      case 'identity':
        return l10n.identity;
      case 'license':
        return l10n.license;
      case 'certification':
        return l10n.certification;
      case 'insurance':
        return l10n.insurance;
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(providerDocumentsProvider);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.documents)),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(appErrorText(context, e), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(providerDocumentsProvider),
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
        ),
        data: (docs) {
          final byType = {for (final d in docs) d['doc_type'] as String: d};
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ...providerDocTypes.map((doc) {
                final existing = byType[doc.key];
                final status = existing?['status'] as String?;
                final rejectionReason =
                    existing?['rejection_reason'] as String?;
                final fileUrl = existing?['file_url'] as String?;
                final hasDoc = fileUrl != null && fileUrl.isNotEmpty;
                final label = _docLabel(doc.key);
                final localizedStatus = switch (status) {
                  'verified' || 'approved' => l10n.verified,
                  'rejected' => l10n.rejected,
                  'pending' => l10n.pendingReview,
                  _ => l10n.done,
                };
                return Card(
                  child: ListTile(
                    leading: hasDoc
                        ? Icon(
                            Icons.check_circle_outline,
                            color: _statusColor(status),
                          )
                        : const Icon(Icons.upload_file_outlined),
                    title: Text(label),
                    // Title and reason get the full tile width; the actions
                    // wrap onto their own line below so they never starve
                    // the text at small widths or large text scales.
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        !hasDoc
                            ? Text(l10n.notUploaded)
                            : Text(
                                rejectionReason != null &&
                                        rejectionReason.isNotEmpty
                                    ? '$localizedStatus — $rejectionReason'
                                    : localizedStatus,
                              ),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: _busy && _busyKey == doc.key
                              ? const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : Wrap(
                                  spacing: 4,
                                  children: [
                                    if (hasDoc)
                                      IconButton(
                                        tooltip: l10n.viewDocumentTooltip,
                                        icon: const Icon(
                                          Icons.visibility_outlined,
                                        ),
                                        onPressed: _busy
                                            ? null
                                            : () => _view(fileUrl),
                                      ),
                                    if (hasDoc)
                                      IconButton(
                                        tooltip: l10n.delete,
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: _busy
                                            ? null
                                            : () => _delete(doc.key, label),
                                      ),
                                    TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _upload(doc.key, label),
                                      child: Text(
                                        hasDoc ? l10n.replace : l10n.upload,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
      floatingActionButton: _viewUrl == null
          ? null
          : FloatingActionButton(
              onPressed: () => setState(() => _viewUrl = null),
              child: const Icon(Icons.close),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomSheet: _viewUrl == null
          ? null
          : SizedBox(
              height: 320,
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(l10n.docPreview),
                    ),
                    Expanded(
                      child: Image.network(
                        _viewUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.broken_image_outlined,
                                size: 40,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(height: 8),
                              Text(l10n.failedToLoad),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
