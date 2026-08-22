import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/provider_documents_providers.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label uploaded for review')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(String docType, String label) async {
    if (_busy) return;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label removed')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
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
      if (mounted) setState(() => _error = e.toString());
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(providerDocumentsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (docs) {
          final byType = {
            for (final d in docs) d['doc_type'] as String: d,
          };
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              ...providerDocTypes.map((doc) {
                final existing = byType[doc.key];
                final status = existing?['status'] as String?;
                final fileUrl = existing?['file_url'] as String?;
                final hasDoc = fileUrl != null && fileUrl.isNotEmpty;
                return Card(
                  child: ListTile(
                    leading: hasDoc
                        ? Icon(Icons.check_circle_outline,
                            color: _statusColor(status))
                        : const Icon(Icons.upload_file_outlined),
                    title: Text(doc.label),
                    subtitle: !hasDoc
                        ? const Text('Not uploaded')
                        : Text(
                            (status ?? 'uploaded')[0].toUpperCase() +
                                (status ?? 'uploaded').substring(1),
                          ),
                    trailing: _busy && _busyKey == doc.key
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasDoc)
                                IconButton(
                                  icon: const Icon(Icons.visibility_outlined),
                                  onPressed: _busy ? null : () => _view(fileUrl!),
                                ),
                              if (hasDoc)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: _busy
                                      ? null
                                      : () => _delete(doc.key, doc.label),
                                ),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _upload(doc.key, doc.label),
                                child: Text(hasDoc ? 'Replace' : 'Upload'),
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
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Document preview'),
                    ),
                    Expanded(
                      child: Image.network(_viewUrl!, fit: BoxFit.contain),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
