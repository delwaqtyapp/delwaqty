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
      final url = await ref
          .read(providerDocumentsRepositoryProvider)
          .uploadDoc('${docType}_${file.name}', bytes);
      await ref
          .read(providerDocumentsRepositoryProvider)
          .upsertDocument(docType, url);
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
                return Card(
                  child: ListTile(
                    title: Text(doc.label),
                    subtitle: fileUrl == null
                        ? const Text('Not uploaded')
                        : Text(
                            status == null
                                ? 'Uploaded'
                                : status[0].toUpperCase() + status.substring(1),
                          ),
                    trailing: _busy && _busyKey == doc.key
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : TextButton(
                            onPressed: _busy ? null : () => _upload(doc.key, doc.label),
                            child: Text(fileUrl == null ? 'Upload' : 'Replace'),
                          ),
                    leading: fileUrl == null
                        ? const Icon(Icons.upload_file_outlined)
                        : Icon(
                            Icons.check_circle_outline,
                            color: _statusColor(status),
                          ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
