import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/member_management/presentation/member_providers.dart';
import 'package:delwaqty/features/sanctions/presentation/sanctions_providers.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class MemberDetailPage extends ConsumerWidget {
  const MemberDetailPage({super.key, required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profileAsync = ref.watch(memberProfileProvider(memberId));

    return Scaffold(
      appBar: AppBar(title: const Text('Member Profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => PremiumEmptyState(
          icon: Icons.error_outline,
          title: l10n.error,
          message: e.toString(),
        ),
        data: (profile) {
          if (profile == null) {
            return const PremiumEmptyState(
              icon: Icons.person_off_rounded,
              title: 'Member not found',
              message: 'This member does not exist or you lack access.',
            );
          }
          return _MemberProfileBody(
            memberId: memberId,
            profile: profile,
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showIssueSanctionSheet(context, ref),
        icon: const Icon(Icons.gavel_rounded),
        label: const Text('Issue Sanction'),
      ),
    );
  }

  void _showIssueSanctionSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _IssueSanctionSheet(
        memberId: memberId,
        onIssued: () {
          ref.invalidate(memberStatusProvider(memberId));
          ref.invalidate(memberTimelineProvider(memberId));
        },
      ),
    );
  }
}

class _IssueSanctionSheet extends ConsumerStatefulWidget {
  const _IssueSanctionSheet({
    required this.memberId,
    required this.onIssued,
  });

  final String memberId;
  final VoidCallback onIssued;

  @override
  ConsumerState<_IssueSanctionSheet> createState() =>
      _IssueSanctionSheetState();
}

class _IssueSanctionSheetState extends ConsumerState<_IssueSanctionSheet> {
  String _selectedType = 'warning';
  final _reasonController = TextEditingController();
  final _durationController = TextEditingController(text: '0');
  final _amountController = TextEditingController(text: '0');
  bool _isSubmitting = false;

  static const _types = [
    'warning',
    'fine',
    'suspension',
    'temporary_ban',
    'permanent_ban',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    _durationController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reasonController.text.trim().isEmpty) return;
    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(sanctionsRepositoryProvider);
      await repo.issueSanction(
        memberId: widget.memberId,
        sanctionType: _selectedType,
        reason: _reasonController.text.trim(),
        durationDays: int.tryParse(_durationController.text) ?? 0,
        amount: double.tryParse(_amountController.text) ?? 0,
      );
      if (mounted) {
        widget.onIssued();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sanction issued')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to issue sanction: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            Text('Issue Sanction',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              decoration: InputDecoration(
                labelText: 'Sanction Type',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _types
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedType = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                labelText: 'Reason *',
                hintText: 'Enter reason for sanction',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _durationController,
                    decoration: InputDecoration(
                      labelText: 'Duration (days)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    decoration: InputDecoration(
                      labelText: 'Amount (\$)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Issue Sanction'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberProfileBody extends ConsumerWidget {
  const _MemberProfileBody({
    required this.memberId,
    required this.profile,
  });

  final String memberId;
  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(memberStatusProvider(memberId));
    final basicInfo = profile['basic'] as Map<String, dynamic>? ?? {};
    final name = basicInfo['full_name'] as String? ?? 'Unnamed';
    final email = basicInfo['email'] as String? ?? '';
    final phone = basicInfo['phone'] as String? ?? '';
    final role = basicInfo['role'] as String? ?? 'customer';

    final accountStatus =
        statusAsync.valueOrNull?['account_status'] as String? ?? 'active';
    final statusColor = switch (accountStatus) {
      'active' => Colors.green,
      'restricted' => Colors.orange,
      'suspended' => Colors.red,
      'banned' => Colors.red.shade900,
      _ => Colors.grey,
    };

    return ListView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
      children: [
        Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor: statusColor.withValues(alpha: 0.15),
            child: Text(
              name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                fontSize: 32,
                color: statusColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              accountStatus,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _InfoCard(title: 'Contact', items: [
          if (email.isNotEmpty)
            _InfoRow(icon: Icons.email_outlined, text: email),
          if (phone.isNotEmpty)
            _InfoRow(icon: Icons.phone_outlined, text: phone),
          _InfoRow(icon: Icons.badge_outlined, text: 'Role: $role'),
        ]),
        const SizedBox(height: 12),
        if (statusAsync.hasValue)
          _SanctionsSection(
            memberId: memberId,
            statusData: statusAsync.value!,
          ),
        const SizedBox(height: 12),
        _TimelineSection(memberId: memberId),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.items});

  final String title;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
            const SizedBox(height: 8),
            ...items,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _SanctionsSection extends ConsumerStatefulWidget {
  const _SanctionsSection({
    required this.memberId,
    required this.statusData,
  });

  final String memberId;
  final Map<String, dynamic> statusData;

  @override
  ConsumerState<_SanctionsSection> createState() => _SanctionsSectionState();
}

class _SanctionsSectionState extends ConsumerState<_SanctionsSection> {
  bool _isRevoking = false;

  Future<void> _confirmRevoke(Map<String, dynamic> sanction) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke Sanction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Revoke ${sanction['sanction_type']}?',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Reason',
                hintText: 'Enter reason for revocation',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isRevoking = true);
      try {
        final repo = ref.read(sanctionsRepositoryProvider);
        await repo.revokeSanction(
          sanctionId: sanction['id'] as String,
          reason: reasonController.text.isEmpty
              ? 'Revoked by admin'
              : reasonController.text,
        );
        if (mounted) {
          ref.invalidate(memberStatusProvider(widget.memberId));
          ref.invalidate(memberTimelineProvider(widget.memberId));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sanction revoked')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to revoke: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isRevoking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sanctions = widget.statusData['active_sanctions'] as List? ?? [];
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Active Sanctions',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
            const SizedBox(height: 8),
            if (sanctions.isEmpty)
              Text(
                'No active sanctions',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              ...sanctions.map((s) {
                final type = s['sanction_type'] as String? ?? '?';
                final reason = s['reason'] as String? ?? '';
                final sanctionId = s['id'] as String? ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.gavel_rounded,
                          size: 14, color: Colors.orange),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('$type — $reason',
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                      if (sanctionId.isNotEmpty)
                        IconButton(
                          icon: _isRevoking
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.undo_rounded, size: 16),
                          onPressed:
                              _isRevoking ? null : () => _confirmRevoke(s),
                          tooltip: 'Revoke',
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _TimelineSection extends ConsumerWidget {
  const _TimelineSection({required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync = ref.watch(memberTimelineProvider(memberId));

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Timeline',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
            const SizedBox(height: 8),
            timelineAsync.when(
              loading: () => const ShimmerLoading(
                child: SizedBox(height: 80),
              ),
              error: (e, _) => Text('Failed to load timeline',
                  style: Theme.of(context).textTheme.bodySmall),
              data: (events) {
                if (events.isEmpty) {
                  return Text(
                    'No events yet',
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                }
                return Column(
                  children: events.take(10).map((e) {
                    final type = e['event_type'] as String? ?? '?';
                    final createdAt = e['created_at'] as String? ?? '';
                    final detail =
                        e['detail'] as Map<String, dynamic>? ?? {};
                    final reason = detail['reason'] as String? ?? '';
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        _timelineIcon(type),
                        size: 16,
                        color: _timelineColor(type),
                      ),
                      title: Text(type, style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                        reason.isNotEmpty ? '$createdAt — $reason' : createdAt,
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _timelineIcon(String type) {
    if (type.contains('sanction')) return Icons.gavel_rounded;
    if (type.contains('ban')) return Icons.block;
    if (type.contains('reward')) return Icons.card_giftcard_rounded;
    return Icons.circle;
  }

  Color _timelineColor(String type) {
    if (type.contains('ban')) return Colors.red;
    if (type.contains('sanction')) return Colors.orange;
    if (type.contains('reward')) return Colors.green;
    return Colors.grey;
  }
}
