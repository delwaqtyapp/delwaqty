import 'package:flutter/material.dart';

import 'package:delwaqty/l10n/app_localizations.dart';

/// Result of [showDeliveryIncidentDialog]: the category the reporter picked
/// plus an optional free-text note.
class DeliveryIncidentReport {
  const DeliveryIncidentReport(this.kind, this.note);

  final String kind;
  final String? note;
}

/// Asks a rider or driver what went wrong with a delivery whose goods are
/// already in the driver's custody. Plain cancellation is refused by the
/// server at that stage; this report is what reaches support instead.
Future<DeliveryIncidentReport?> showDeliveryIncidentDialog(
  BuildContext context,
) {
  return showDialog<DeliveryIncidentReport>(
    context: context,
    builder: (ctx) => const _DeliveryIncidentDialog(),
  );
}

class _DeliveryIncidentDialog extends StatefulWidget {
  const _DeliveryIncidentDialog();

  @override
  State<_DeliveryIncidentDialog> createState() =>
      _DeliveryIncidentDialogState();
}

class _DeliveryIncidentDialogState extends State<_DeliveryIncidentDialog> {
  String _kind = 'breakdown';
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kinds = <String, String>{
      'breakdown': l10n.incidentKindBreakdown,
      'accident': l10n.incidentKindAccident,
      'goods_damaged': l10n.incidentKindGoodsDamaged,
      'customer_unreachable': l10n.incidentKindCustomerUnreachable,
      'other': l10n.incidentKindOther,
    };
    return AlertDialog(
      title: Text(l10n.reportIncidentTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.reportIncidentBody),
            const SizedBox(height: 12),
            for (final entry in kinds.entries)
              RadioListTile<String>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(entry.value),
                value: entry.key,
                groupValue: _kind,
                onChanged: (v) => setState(() => _kind = v ?? 'other'),
              ),
            TextField(
              controller: _note,
              maxLines: 2,
              decoration: InputDecoration(hintText: l10n.incidentNoteHint),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final note = _note.text.trim();
            Navigator.of(context)
                .pop(DeliveryIncidentReport(_kind, note.isEmpty ? null : note));
          },
          child: Text(l10n.sendReport),
        ),
      ],
    );
  }
}
