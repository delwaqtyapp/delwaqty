import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/_shared/complaints/presentation/complaints_providers.dart';
import 'package:delwaqty/features/_shared/complaints/domain/entities/complaint.dart';
import 'package:delwaqty/shared/widgets/glass_card.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class AdminComplaintsPage extends ConsumerStatefulWidget {
  const AdminComplaintsPage({super.key});

  @override
  ConsumerState<AdminComplaintsPage> createState() =>
      _AdminComplaintsPageState();
}

class _AdminComplaintsPageState extends ConsumerState<AdminComplaintsPage> {
  String _statusFilter = 'all';
  String _typeFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final complaintsAsync = ref.watch(complaintsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.complaintsManagement)),
      body: Column(
        children: [
          _buildFilters(cs, l10n),
          Expanded(
            child: complaintsAsync.when(
              loading: () => const Center(child: AppLoaderCircular()),
              error: (e, _) => PremiumEmptyState(
                icon: Icons.error_outline,
                title: l10n.error,
                message: e.toString(),
              ),
              data: (complaints) {
                final filtered = _applyFilters(complaints);
                if (filtered.isEmpty) {
                  return PremiumEmptyState(
                    icon: Icons.shield_outlined,
                    title: l10n.noComplaints,
                    message: l10n.noComplaintsDescription,
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return _ComplaintTile(
                      complaint: filtered[index],
                      cs: cs,
                      l10n: l10n,
                      onTap: () => _showComplaintDetail(filtered[index]),
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

  Widget _buildFilters(ColorScheme cs, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _statusFilter,
              decoration: InputDecoration(
                labelText: 'Status',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: [
                'all',
                'pending',
                'investigating',
                'resolved',
                'rejected',
                'escalated',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _statusFilter = v!),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _typeFilter,
              decoration: InputDecoration(
                labelText: l10n.type,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: [
                'all',
                'driver',
                'merchant',
                'customer',
                'provider',
                'other',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _typeFilter = v!),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(complaintsProvider),
          ),
        ],
      ),
    );
  }

  List<Complaint> _applyFilters(List<Complaint> complaints) {
    var result = complaints;
    if (_statusFilter != 'all') {
      result = result.where((c) => c.status == _statusFilter).toList();
    }
    if (_typeFilter != 'all') {
      result = result.where((c) => c.complaintType == _typeFilter).toList();
    }
    return result;
  }

  void _showComplaintDetail(Complaint complaint) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ComplaintDetailSheet(
        complaint: complaint,
        onStatusChanged: () => ref.invalidate(complaintsProvider),
      ),
    );
  }
}

class _ComplaintTile extends StatelessWidget {

  const _ComplaintTile({
    required this.complaint,
    required this.cs,
    required this.l10n,
    required this.onTap,
  });
  final Complaint complaint;
  final ColorScheme cs;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return cs.tertiary;
      case 'investigating':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'escalated':
        return Colors.deepPurple;
      default:
        return cs.onSurface;
    }
  }

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
                color: _statusColor(complaint.status).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.warning_rounded,
                color: _statusColor(complaint.status),
              ),
            ),
            title: Text(
              complaint.subject,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${complaint.complaintType} Â· ${complaint.status}',
              maxLines: 1,
            ),
            trailing: Chip(
              label: Text(
                complaint.priority,
                style: const TextStyle(fontSize: 10),
              ),
              backgroundColor: complaint.priority == 'urgent'
                  ? Colors.red.withValues(alpha: 0.2)
                  : null,
            ),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}

class _ComplaintDetailSheet extends ConsumerStatefulWidget {

  const _ComplaintDetailSheet({
    required this.complaint,
    required this.onStatusChanged,
  });
  final Complaint complaint;
  final VoidCallback onStatusChanged;

  @override
  ConsumerState<_ComplaintDetailSheet> createState() =>
      _ComplaintDetailSheetState();
}

class _ComplaintDetailSheetState extends ConsumerState<_ComplaintDetailSheet> {
  final _noteController = TextEditingController();
  String _selectedStatus = '';

  Future<void> _escalateWithReason(Complaint c) async {
    final l10n = AppLocalizations.of(context);
    final reasonController = TextEditingController();
    final escalated = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(l10n.escalationEscalate),
        content: TextField(
          controller: reasonController,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: l10n.escalationReason,
            hintText: l10n.escalationReasonHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.escalationRequired)),
                );
                return;
              }
              Navigator.of(dctx).pop(true);
            },
            child: Text(l10n.escalationEscalate),
          ),
        ],
      ),
    );
    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (escalated != true || reason.isEmpty) return;

    final ctx = context;
    try {
      final repo = ref.read(complaintsRepositoryProvider);
      await repo.escalateComplaint(id: c.id, reason: reason);
      widget.onStatusChanged();
      if (ctx.mounted) {
        Navigator.of(ctx).pop();
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(l10n.escalationEscalatedSuccess)),
        );
      }
    } catch (_) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(SnackBar(content: Text(l10n.escalationFailed)));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.complaint.status;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.complaint;
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
              Text(c.subject, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                c.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Chip(
                    label: Text(
                      '${AppLocalizations.of(context).type}: ${c.complaintType}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Chip(label: Text('${AppLocalizations.of(context).statusLabel}: ${c.status}')),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedStatus,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).updateStatus,
                ),
                items: ['pending', 'investigating', 'resolved', 'rejected']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedStatus = v!),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  if (_selectedStatus == 'escalated') {
                    await _escalateWithReason(c);
                    return;
                  }
                  final repo = ref.read(complaintsRepositoryProvider);
                  await repo.updateComplaintStatus(c.id, _selectedStatus);
                  widget.onStatusChanged();
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: Text(AppLocalizations.of(context).save),
              ),
              const SizedBox(height: 8),
              if (!c.isClosed)
                OutlinedButton.icon(
                  onPressed: () => _escalateWithReason(c),
                  icon: const Icon(Icons.swap_vert_circle_rounded),
                  label: Text(AppLocalizations.of(context).escalationEscalate),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).addAdminNote,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  if (_noteController.text.trim().isEmpty) return;
                  final repo = ref.read(complaintsRepositoryProvider);
                  await repo.addAdminNote(c.id, _noteController.text.trim());
                  _noteController.clear();
                  widget.onStatusChanged();
                },
                child: Text(AppLocalizations.of(context).addNote),
              ),
            ],
          ),
        );
      },
    );
  }
}
