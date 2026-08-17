import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/sanctions/presentation/sanctions_providers.dart';
import 'package:delwaqty/features/sanctions/domain/entities/sanction.dart';
import 'package:delwaqty/shared/widgets/glass_card.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class AdminSanctionsPage extends ConsumerStatefulWidget {
  const AdminSanctionsPage({super.key});

  @override
  ConsumerState<AdminSanctionsPage> createState() =>
      _AdminSanctionsPageState();
}

class _AdminSanctionsPageState extends ConsumerState<AdminSanctionsPage> {
  bool _showActiveOnly = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sanctionsAsync =
        ref.watch(_showActiveOnly ? activeSanctionsProvider : sanctionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sanctionsManagement),
        actions: [
          Row(
            children: [
              Text(l10n.activeOnly,
                  style: Theme.of(context).textTheme.bodySmall),
              Switch(
                value: _showActiveOnly,
                onChanged: (v) => setState(() => _showActiveOnly = v),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(sanctionsProvider);
              ref.invalidate(activeSanctionsProvider);
            },
          ),
        ],
      ),
      body: sanctionsAsync.when(
        loading: () => const Center(child: AppLoaderCircular()),
        error: (e, _) => PremiumEmptyState(
          icon: Icons.error_outline,
          title: l10n.error,
          message: e.toString(),
        ),
        data: (sanctions) {
          if (sanctions.isEmpty) {
            return PremiumEmptyState(
              icon: Icons.gavel_outlined,
              title: l10n.noSanctions,
              message: l10n.noSanctionsDescription,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: sanctions.length,
            itemBuilder: (context, index) {
              final s = sanctions[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AnimatedFadeIn(
                  child: GlassCard(
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: s.sanctionType == 'permanent_ban'
                              ? Colors.red.withValues(alpha: 0.15)
                              : Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          s.sanctionType == 'permanent_ban' ||
                                  s.sanctionType == 'temporary_ban'
                              ? Icons.block
                              : Icons.warning_amber_rounded,
                          color: s.sanctionType == 'permanent_ban'
                              ? Colors.red
                              : Colors.orange,
                        ),
                      ),
                      title: Text('${s.sanctionType} — ${s.targetRole}',
                          maxLines: 1),
                      subtitle: Text(s.reason,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: s.isActive
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(l10n.active,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.green)),
                            )
                          : null,
                      onTap: () => _showSanctionDetail(s),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showSanctionDetail(Sanction sanction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SanctionDetailSheet(
        sanction: sanction,
        onRevoked: () {
          ref.invalidate(sanctionsProvider);
          ref.invalidate(activeSanctionsProvider);
        },
      ),
    );
  }
}

class _SanctionDetailSheet extends ConsumerStatefulWidget {
  const _SanctionDetailSheet({
    required this.sanction,
    required this.onRevoked,
  });

  final Sanction sanction;
  final VoidCallback onRevoked;

  @override
  ConsumerState<_SanctionDetailSheet> createState() =>
      _SanctionDetailSheetState();
}

class _SanctionDetailSheetState extends ConsumerState<_SanctionDetailSheet> {
  bool _isRevoking = false;

  Future<void> _confirmRevoke() async {
    final l10n = AppLocalizations.of(context);
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke Sanction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Revoke ${widget.sanction.sanctionType} for ${widget.sanction.targetRole}?',
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
            child: Text(l10n.cancel),
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
          sanctionId: widget.sanction.id,
          reason: reasonController.text.isEmpty
              ? 'Revoked by admin'
              : reasonController.text,
        );
        if (mounted) {
          widget.onRevoked();
          Navigator.of(context).pop();
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
    final l10n = AppLocalizations.of(context);
    final sanction = widget.sanction;

    return DraggableScrollableSheet(
      minChildSize: 0.3,
      maxChildSize: 0.7,
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
              Text('${sanction.sanctionType} — ${sanction.targetRole}',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(sanction.reason,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              if (sanction.amount > 0)
                Text('${l10n.fineAmount}: \$${sanction.amount.toStringAsFixed(2)}'),
              if (sanction.durationDays > 0)
                Text(
                    '${l10n.duration}: ${sanction.durationDays} ${l10n.days}'),
              Text(
                  'Status: ${sanction.isActive ? l10n.active : l10n.inactive}'),
              Text(
                  '${l10n.startDate}: ${sanction.startDate.toLocal().toString().split('.')[0]}'),
              if (sanction.endDate != null)
                Text(
                    '${l10n.endDate}: ${sanction.endDate!.toLocal().toString().split('.')[0]}'),
              if (sanction.notes != null && sanction.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(l10n.notes,
                    style: Theme.of(context).textTheme.titleMedium),
                Text(sanction.notes!),
              ],
              if (sanction.isActive) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isRevoking ? null : _confirmRevoke,
                    icon: _isRevoking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.undo_rounded),
                    label: Text(_isRevoking ? 'Revoking...' : 'Revoke Sanction'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.errorContainer,
                      foregroundColor:
                          Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
