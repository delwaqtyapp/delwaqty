import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_models.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/services/admin/admin_providers.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';

/// Audit trail.
///
/// Every moderation and finance RPC writes to `activity_logs`, and
/// `getRecentActivity` + `recentActivityProvider` already existed — but no
/// page consumed the provider, so the console had no audit view at all
/// despite the database recording every administrative action.
class AdminAuditLogPage extends ConsumerStatefulWidget {
  const AdminAuditLogPage({super.key});

  @override
  ConsumerState<AdminAuditLogPage> createState() => _AdminAuditLogPageState();
}

class _AdminAuditLogPageState extends ConsumerState<AdminAuditLogPage> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final logsAsync = ref.watch(recentActivityProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.auditLog),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(recentActivityProvider),
          ),
        ],
      ),
      body: logsAsync.when(
        loading: () => const Center(child: AppLoaderCircular()),
        error: (e, _) => PremiumEmptyState(
          icon: Icons.error_outline,
          title: l10n.error,
          message: l10n.failedToLoad,
          actionLabel: l10n.retry,
          onAction: () => ref.invalidate(recentActivityProvider),
        ),
        data: (logs) {
          if (logs.isEmpty) {
            return PremiumEmptyState(
              icon: Icons.history_rounded,
              title: l10n.noAuditEntries,
              message: l10n.noAuditEntriesDescription,
            );
          }

          final query = _filter.trim().toLowerCase();
          final filtered = query.isEmpty
              ? logs
              : logs
                  .where(
                    (l) =>
                        l.action.toLowerCase().contains(query) ||
                        l.resource.toLowerCase().contains(query),
                  )
                  .toList(growable: false);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _filter = v),
                  decoration: InputDecoration(
                    hintText: l10n.searchAudit,
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Text(l10n.noResults))
                    : RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(recentActivityProvider),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (context, index) =>
                              _LogTile(log: filtered[index]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.log});

  final AdminActivityLog log;

  @override
  Widget build(BuildContext context) {
    final isDestructive = _isDestructive(log.action);
    final color = isDestructive ? AppColors.errorLight : AppColors.brandPurple;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: color.withValues(alpha: 0.18),
        ),
      ),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(_icon(log.action), size: 18, color: color),
        ),
        title: Text(
          log.action,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(log.resource, style: const TextStyle(fontSize: 11)),
            Text(
              log.timestamp.toIso8601String().split('.').first,
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: (log.details ?? '').isEmpty
            ? null
            : Tooltip(
                message: log.details!,
                child: Icon(Icons.tag_rounded, size: 16, color: color),
              ),
      ),
    );
  }

  static bool _isDestructive(String action) {
    final a = action.toLowerCase();
    return a.contains('delete') ||
        a.contains('ban') ||
        a.contains('suspend') ||
        a.contains('reject') ||
        a.contains('restrict') ||
        a.contains('deactivat');
  }

  static IconData _icon(String action) {
    final a = action.toLowerCase();
    if (a.contains('delete')) return Icons.delete_outline_rounded;
    if (a.contains('create') || a.contains('add')) {
      return Icons.add_circle_outline_rounded;
    }
    if (a.contains('update') || a.contains('edit')) {
      return Icons.edit_outlined;
    }
    if (a.contains('ban') || a.contains('suspend') || a.contains('reject')) {
      return Icons.block_rounded;
    }
    if (a.contains('approve') || a.contains('grant')) {
      return Icons.check_circle_outline_rounded;
    }
    if (a.contains('login') || a.contains('sign')) {
      return Icons.login_rounded;
    }
    return Icons.history_rounded;
  }
}