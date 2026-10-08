import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/services/admin/admin_providers.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';

/// Emergency (SOS) console.
///
/// Migration 089 shipped `sos_alerts` + `trigger_sos_alert` +
/// `admin_list_sos_alerts` + `admin_resolve_sos_alert`, and the repository,
/// the service and `adminSosAlertsProvider` all existed — but NO page was
/// ever built and no route was registered. Four separate entry points in the
/// console (the sidebar item, the Quick Actions tile, the orders shortcut and
/// the member operations centre) therefore landed on the router's
/// "page not found".
class AdminEmergencyPage extends ConsumerStatefulWidget {
  const AdminEmergencyPage({super.key});

  @override
  ConsumerState<AdminEmergencyPage> createState() => _AdminEmergencyPageState();
}

class _AdminEmergencyPageState extends ConsumerState<AdminEmergencyPage> {
  String _filter = 'open';

  Future<void> _resolve(
    Map<String, dynamic> alert,
    String status,
  ) async {
    final l10n = AppLocalizations.of(context);
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          status == 'resolved' ? l10n.markResolved : l10n.dismiss,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          decoration: InputDecoration(labelText: l10n.note),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await ref.read(adminServiceProvider).resolveSosAlert(
          alert['id'] as String,
          status: status,
          note: noteController.text.trim().isEmpty
              ? null
              : noteController.text.trim(),
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? l10n.updatedSuccessfully : l10n.somethingWentWrong),
      ),
    );
    if (ok) ref.invalidate(adminSosAlertsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final alertsAsync = ref.watch(adminSosAlertsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminEmergency),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(adminSosAlertsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                _FilterChip(
                  label: l10n.openAlerts,
                  selected: _filter == 'open',
                  onTap: () => setState(() => _filter = 'open'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: l10n.all,
                  selected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: l10n.closed,
                  selected: _filter == 'resolved',
                  onTap: () => setState(() => _filter = 'resolved'),
                ),
              ],
            ),
          ),
          Expanded(
            child: alertsAsync.when(
              loading: () => const Center(child: AppLoaderCircular()),
              error: (e, _) => PremiumEmptyState(
                icon: Icons.error_outline,
                title: l10n.error,
                message: l10n.failedToLoad,
                actionLabel: l10n.retry,
                onAction: () => ref.invalidate(adminSosAlertsProvider),
              ),
              data: (alerts) {
                final filtered = switch (_filter) {
                  'open' => alerts
                      .where((a) => a['status'] != 'resolved')
                      .toList(growable: false),
                  'resolved' => alerts
                      .where((a) => a['status'] == 'resolved')
                      .toList(growable: false),
                  _ => alerts,
                };

                if (filtered.isEmpty) {
                  return PremiumEmptyState(
                    icon: Icons.shield_moon_outlined,
                    title: l10n.noEmergencies,
                    message: l10n.noEmergenciesDescription,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(adminSosAlertsProvider),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _AlertTile(
                      alert: filtered[index],
                      onResolve: (status) => _resolve(filtered[index], status),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.brandPurple.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert, required this.onResolve});

  final Map<String, dynamic> alert;
  final void Function(String status) onResolve;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = alert['status'] as String? ?? 'open';
    final type = alert['alert_type'] as String? ?? 'sos';
    final createdAt = alert['created_at'] as String?;
    final address = alert['address'] as String?;
    final isResolved = status == 'resolved';

    return Card(
      elevation: isResolved ? 0 : 3,
      color: isResolved ? null : AppColors.errorLight.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isResolved
            ? BorderSide.none
            : BorderSide(color: AppColors.errorLight.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: (isResolved
                          ? AppColors.successLight
                          : AppColors.errorLight)
                      .withValues(alpha: 0.15),
                  child: Icon(
                    isResolved
                        ? Icons.check_circle_outline
                        : Icons.emergency_share_outlined,
                    size: 20,
                    color:
                        isResolved ? AppColors.successLight : AppColors.errorLight,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.replaceAll('_', ' '),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (createdAt != null)
                        Text(
                          createdAt,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isResolved
                            ? AppColors.successLight
                            : AppColors.errorLight)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isResolved ? l10n.closed : l10n.openAlerts,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color:
                          isResolved ? AppColors.successLight : AppColors.errorLight,
                    ),
                  ),
                ),
              ],
            ),
            if (address != null && address.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(address)),
                ],
              ),
            ],
            if (!isResolved) ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onPressed: () => onResolve('resolved'),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(l10n.markResolved),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}