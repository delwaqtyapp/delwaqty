import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';

class AdminPendingDeletionsPage extends ConsumerStatefulWidget {
  const AdminPendingDeletionsPage({super.key});

  @override
  ConsumerState<AdminPendingDeletionsPage> createState() =>
      _AdminPendingDeletionsPageState();
}

class _AdminPendingDeletionsPageState
    extends ConsumerState<AdminPendingDeletionsPage> {
  List<Map<String, dynamic>> _pendingDeletions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingDeletions();
  }

  Future<void> _loadPendingDeletions() async {
    try {
      final client = Supabase.instance.client;
      final result = await client.rpc('get_pending_deletions');
      final deletions = (result as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];

      if (mounted) {
        setState(() {
          _pendingDeletions = deletions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pendingDeletions),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPendingDeletions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingDeletions.isEmpty
              ? PremiumEmptyState(
                  icon: Icons.check_circle_outline_rounded,
                  title: l10n.noPendingDeletions,
                  message: l10n.allCaughtUp,
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pendingDeletions.length,
                  itemBuilder: (context, index) {
                    final deletion = _pendingDeletions[index];
                    return AnimatedFadeIn(
                      delay: Duration(milliseconds: index * 80),
                      child: _buildDeletionCard(deletion, l10n, cs),
                    );
                  },
                ),
    );
  }

  Widget _buildDeletionCard(
    Map<String, dynamic> deletion,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    final memberEmail = deletion['member_email'] as String? ?? '';
    final requestedBy = deletion['requested_by'] as String? ?? '';
    final reason = deletion['reason'] as String? ?? '';
    final createdAt = deletion['created_at'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_remove_rounded, color: cs.error, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        memberEmail,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${l10n.requestedBy}: $requestedBy',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  reason,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            if (createdAt.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                createdAt,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _approveDeletion(deletion, l10n),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(l10n.approveDeletion),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectDeletion(deletion, l10n),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: Text(l10n.rejectDeletion),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.error,
                      side: BorderSide(color: cs.error),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveDeletion(
    Map<String, dynamic> deletion,
    AppLocalizations l10n,
  ) async {
    final deletionId = deletion['id'] as String?;
    if (deletionId == null) return;

    try {
      final client = Supabase.instance.client;
      await client.rpc('approve_member_deletion', params: {
        'p_deletion_id': deletionId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.deletionApproved)),
        );
        _loadPendingDeletions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _rejectDeletion(
    Map<String, dynamic> deletion,
    AppLocalizations l10n,
  ) async {
    final deletionId = deletion['id'] as String?;
    if (deletionId == null) return;

    try {
      final client = Supabase.instance.client;
      await client.rpc('reject_member_deletion', params: {
        'p_deletion_id': deletionId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.deletionRejected)),
        );
        _loadPendingDeletions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
