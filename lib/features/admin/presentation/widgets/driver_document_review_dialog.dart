import 'package:flutter/material.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// Review is explicit; a driver cannot be approved from the list by one tap.
class DriverDocumentReviewDialog extends StatefulWidget {
  const DriverDocumentReviewDialog({
    super.key,
    required this.documents,
    required this.onOpen,
  });

  final List<Map<String, dynamic>> documents;
  final Future<void> Function(String path) onOpen;

  @override
  State<DriverDocumentReviewDialog> createState() =>
      _DriverDocumentReviewDialogState();
}

class _DriverDocumentReviewDialogState
    extends State<DriverDocumentReviewDialog> {
  bool _reviewed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final requiredTypes = ['driving_license', 'vehicle_registration'];
    final requiredDocs = requiredTypes.map((type) {
      final matches = widget.documents.where((doc) => doc['doc_type'] == type);
      return matches.isEmpty ? null : matches.first;
    }).toList();
    final complete = requiredDocs.every((doc) {
      if (doc == null || !['pending', 'verified'].contains(doc['status']))
        return false;
      if ((doc['file_url'] as String? ?? '').isEmpty) return false;
      final expires = DateTime.tryParse(doc['expires_at'] as String? ?? '');
      final now = DateTime.now();
      return expires == null ||
          !expires.isBefore(DateTime(now.year, now.month, now.day));
    });

    return AlertDialog(
      title: Text(l10n.reviewDriverDocuments),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < requiredTypes.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined),
                  title: Text(
                    i == 0 ? l10n.drivingLicense : l10n.vehicleRegistration,
                  ),
                  subtitle: Text(
                    requiredDocs[i] == null
                        ? l10n.noDocuments
                        : requiredDocs[i]!['status'] == 'verified'
                        ? l10n.documentVerified
                        : requiredDocs[i]!['status'] == 'rejected'
                        ? l10n.documentRejected
                        : l10n.documentPending,
                  ),
                  trailing: IconButton(
                    tooltip: l10n.viewDocument,
                    icon: const Icon(Icons.open_in_new_rounded),
                    onPressed:
                        (requiredDocs[i]?['file_url'] as String? ?? '').isEmpty
                        ? null
                        : () => widget.onOpen(
                            requiredDocs[i]!['file_url'] as String,
                          ),
                  ),
                ),
              if (!complete)
                Text(
                  l10n.driverRequiredDocuments,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.driverDocumentsReviewed),
                value: _reviewed,
                onChanged: complete
                    ? (value) => setState(() => _reviewed = value ?? false)
                    : null,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: complete && _reviewed
              ? () => Navigator.pop(context, true)
              : null,
          child: Text(l10n.verify),
        ),
      ],
    );
  }
}
