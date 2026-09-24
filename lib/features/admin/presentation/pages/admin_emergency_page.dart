import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/admin/admin_providers.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class AdminEmergencyPage extends ConsumerStatefulWidget {
  const AdminEmergencyPage({super.key});

  @override
  ConsumerState<AdminEmergencyPage> createState() => _AdminEmergencyPageState();
}

class _AdminEmergencyPageState extends ConsumerState<AdminEmergencyPage> {
  bool _activeOnly = true;

  Color _statusColor(String status, bool isDark) =>
      switch (status) {
        'active' => isDark ? const Color(0xFFFF6B6B) : const Color(0xFFFF3B30),
        'escalated' => isDark ? const Color(0xFFFFA276) : const Color(0xFFFF9500),
        'resolved' => isDark ? const Color(0xFF6EDC93) : AppColors.successLight,
        'false_alarm' => isDark
            ? const Color(0xFF9BA1A6)
            : const Color(0xFF6B7280),
        _ => Theme.of(context).colorScheme.primary,
      };

  String _statusLabel(String status, AppLocalizations l10n) =>
      switch (status) {
        'active' => l10n.emergencyActive,
        'escalated' => l10n.emergencyEscalated,
        'resolved' => l10n.emergencyResolved,
        'false_alarm' => l10n.emergencyFalseAlarm,
        _ => status,
      };

  String _typeLabel(String type, AppLocalizations l10n) =>
      switch (type) {
        'manual' => l10n.sosAlertTypeManual,
        'automatic' => l10n.sosAlertTypeAutomatic,
        'timer' => l10n.sosAlertTypeTimer,
        _ => type,
      };

  String _typeIcon(String type) => switch (type) {
        'manual' => '🚨',
        'automatic' => '📡',
        'timer' => '⏱️',
        _ => '🚨',
      };

  String _formatDate(String iso) {
    final date = DateTime.tryParse(iso)?.toLocal();
    if (date == null) return iso;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _resolve(
    String alertId,
    String status, {
    String? note,
  }) async {
    final l10n = AppLocalizations.of(context);
    final adminService = ref.read(adminServiceProvider);
    final success = await adminService.resolveSosAlert(
      alertId,
      status: status,
      note: note,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? l10n.sosResolved : l10n.sosActionFailed),
        backgroundColor:
            success ? AppColors.successLight : AppColors.errorLight,
      ),
    );
    if (success) ref.invalidate(adminSosAlertsProvider);
  }

  Future<void> _showResolveSheet(
    Map<String, dynamic> alert,
    String status,
  ) async {
    final l10n = AppLocalizations.of(context);
    final noteController = TextEditingController();
    final alertId = alert['id'] as String;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              status == 'false_alarm'
                  ? l10n.markSosFalseAlarm
                  : l10n.resolveSosAlert,
              style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: l10n.sosNoteHint,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                child: Text(
                  status == 'false_alarm'
                      ? l10n.markSosFalseAlarm
                      : l10n.resolveSosAlert,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      await _resolve(
        alertId,
        status,
        note: noteController.text.trim().isEmpty
            ? null
            : noteController.text.trim(),
      );
    }
    noteController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sosAsync = ref.watch(adminSosAlertsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminEmergency),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(adminSosAlertsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _StatusFilterChip(
                  label: l10n.emergencyOnlyActive,
                  selected: _activeOnly,
                  onTap: () => setState(() => _activeOnly = true),
                ),
                const SizedBox(width: 8),
                _StatusFilterChip(
                  label: l10n.emergencyAll,
                  selected: !_activeOnly,
                  onTap: () => setState(() => _activeOnly = false),
                ),
              ],
            ),
          ),
          Expanded(
            child: sosAsync.when(
              loading: () => const Center(child: AppLoaderCircular()),
              error: (e, _) => Center(
                child: PremiumEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: l10n.error,
                  message: l10n.errorLoading,
                  actionLabel: l10n.retry,
                  onAction: () => ref.invalidate(adminSosAlertsProvider),
                ),
              ),
              data: (alerts) {
                final filtered = _activeOnly
                    ? alerts.where((a) => a['status'] == 'active').toList()
                    : alerts;
                if (filtered.isEmpty) {
                  return PremiumEmptyState(
                    icon: Icons.sos_rounded,
                    title: l10n.sosNoAlerts,
                    message: l10n.sosNoAlertsHint,
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final alert = filtered[index];
                    final status = alert['status'] as String? ?? 'active';
                    return AnimatedFadeIn(
                      delay: Duration(milliseconds: index * 50),
                      child: _SosTile(
                        alert: alert,
                        l10n: l10n,
                        statusLabel: _statusLabel(status, l10n),
                        statusColor: _statusColor(status, isDark),
                        typeLabel: _typeLabel(
                          alert['alert_type'] as String? ?? 'manual',
                          l10n,
                        ),
                        typeIcon: _typeIcon(
                          alert['alert_type'] as String? ?? 'manual',
                        ),
                        dateText: _formatDate(
                          alert['created_at'] as String? ?? '',
                        ),
                        onResolve: () => _showResolveSheet(alert, 'resolved'),
                        onFalseAlarm: status == 'active' ||
                            status == 'escalated'
                            ? () => _showResolveSheet(alert, 'false_alarm')
                            : null,
                      ),
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
}

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: scheme.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        color: selected ? scheme.primary : scheme.onSurfaceVariant,
      ),
    );
  }
}

class _SosTile extends StatelessWidget {
  const _SosTile({
    required this.alert,
    required this.l10n,
    required this.statusLabel,
    required this.statusColor,
    required this.typeLabel,
    required this.typeIcon,
    required this.dateText,
    required this.onResolve,
    this.onFalseAlarm,
  });

  final Map<String, dynamic> alert;
  final AppLocalizations l10n;
  final String statusLabel;
  final Color statusColor;
  final String typeLabel;
  final String typeIcon;
  final String dateText;
  final VoidCallback onResolve;
  final VoidCallback? onFalseAlarm;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = alert['user_name'] as String? ?? '-';
    final phone = alert['user_phone'] as String? ?? '';
    final driverName = alert['driver_name'] as String? ?? '-';
    final address = alert['address'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text(typeIcon, style: const TextStyle(fontSize: 22))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        phone,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(
              label: l10n.sosDriver,
              value: '$driverName (${alert['driver_phone'] as String? ?? '-'})',
            ),
            _InfoRow(label: l10n.sosAlertType, value: typeLabel),
            if (address.isNotEmpty)
              _InfoRow(label: l10n.address, value: address),
            if (alert['notes'] != null && (alert['notes'] as String? ?? '').isNotEmpty)
              _InfoRow(label: l10n.sosNoteHint, value: alert['notes'] as String),
            const SizedBox(height: 6),
            Text(
              dateText,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onResolve,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(l10n.resolveSosAlert),
                  ),
                ),
                if (onFalseAlarm != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: l10n.markSosFalseAlarm,
                    onPressed: onFalseAlarm,
                    icon: const Icon(Icons.flag_outlined),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}