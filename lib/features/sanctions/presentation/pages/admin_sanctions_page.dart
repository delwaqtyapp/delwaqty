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
  ConsumerState<AdminSanctionsPage> createState() => _AdminSanctionsPageState();
}

class _AdminSanctionsPageState extends ConsumerState<AdminSanctionsPage> {
  bool _showActiveOnly = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sanctionsAsync = ref.watch(_showActiveOnly ? activeSanctionsProvider : sanctionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sanctionsManagement),
        actions: [
          Row(
            children: [
              Text(l10n.activeOnly, style: Theme.of(context).textTheme.bodySmall),
              Switch(
                value: _showActiveOnly,
                onChanged: (v) => setState(() => _showActiveOnly = v),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(sanctionsProvider),
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
                    borderRadius: 16,
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
                          s.sanctionType == 'permanent_ban' || s.sanctionType == 'temporary_ban'
                              ? Icons.block : Icons.warning_amber_rounded,
                          color: s.sanctionType == 'permanent_ban' ? Colors.red : Colors.orange,
                        ),
                      ),
                      title: Text('${s.sanctionType} — ${s.targetRole}', maxLines: 1),
                      subtitle: Text(s.reason, maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: s.isActive
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(l10n.active, style: const TextStyle(fontSize: 11, color: Colors.green)),
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
      builder: (ctx) => _SanctionDetailSheet(sanction: sanction),
    );
  }
}

class _SanctionDetailSheet extends StatelessWidget {
  final Sanction sanction;
  const _SanctionDetailSheet({required this.sanction});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
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
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text('${sanction.sanctionType} — ${sanction.targetRole}',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(sanction.reason, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              if (sanction.amount > 0)
                Text('${l10n.fineAmount}: \$${sanction.amount.toStringAsFixed(2)}'),
              if (sanction.durationDays > 0)
                Text('${l10n.duration}: ${sanction.durationDays} ${l10n.days}'),
              Text('Status: ${sanction.isActive ? l10n.active : l10n.inactive}'),
              Text('${l10n.startDate}: ${sanction.startDate.toLocal().toString().split('.')[0]}'),
              if (sanction.endDate != null)
                Text('${l10n.endDate}: ${sanction.endDate!.toLocal().toString().split('.')[0]}'),
              if (sanction.notes != null && sanction.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(l10n.notes, style: Theme.of(context).textTheme.titleMedium),
                Text(sanction.notes!),
              ],
            ],
          ),
        );
      },
    );
  }
}
