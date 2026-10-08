import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/_shared/complaints/presentation/complaints_providers.dart';
import 'package:delwaqty/shared/widgets/glass_card.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class MyComplaintsPage extends ConsumerStatefulWidget {
  const MyComplaintsPage({super.key});

  @override
  ConsumerState<MyComplaintsPage> createState() => _MyComplaintsPageState();
}

class _MyComplaintsPageState extends ConsumerState<MyComplaintsPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final complaintsAsync = ref.watch(myComplaintsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).myComplaints)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/new-complaint'),
        icon: const Icon(Icons.add_comment_outlined),
        label: Text(l10n.submitComplaint),
      ),
      body: complaintsAsync.when(
        loading: () => const Center(child: AppLoaderCircular()),
        error: (e, _) => PremiumEmptyState(
          icon: Icons.error_outline,
          title: l10n.error,
          message: e.toString(),
        ),
        data: (complaints) {
          if (complaints.isEmpty) {
            return PremiumEmptyState(
              icon: Icons.shield_outlined,
              title: l10n.noComplaints,
              message: l10n.noComplaintsDescription,
              actionLabel: l10n.submitComplaint,
              onAction: () => context.push('/new-complaint'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: complaints.length,
            itemBuilder: (context, index) {
              final c = complaints[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AnimatedFadeIn(
                  child: GlassCard(
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: c.status == 'resolved'
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          c.status == 'resolved'
                              ? Icons.check_circle
                              : Icons.pending,
                          color: c.status == 'resolved'
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                      title: Text(
                        c.subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${l10n.statusLabel}: ${_statusLabel(l10n, c.status)}',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showComplaintDetail(context, l10n, c),
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

  String _statusLabel(AppLocalizations l10n, String status) {
    switch (status) {
      case 'resolved':
        return l10n.resolved;
      case 'in_progress':
        return l10n.inProgress;
      case 'closed':
        return l10n.closed;
      default:
        return l10n.pending;
    }
  }

  void _showComplaintDetail(
    BuildContext context,
    AppLocalizations l10n,
    dynamic complaint,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              complaint.subject,
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              complaint.description,
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.circle, size: 8),
                const SizedBox(width: 8),
                Text(_statusLabel(l10n, complaint.status)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.ok),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
