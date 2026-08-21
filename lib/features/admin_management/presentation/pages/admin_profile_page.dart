import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/features/admin_management/domain/entities/admin_account.dart';
import 'package:delwaqty/features/admin_management/presentation/providers/admin_management_providers.dart';

class AdminManagementProfilePage extends ConsumerStatefulWidget {
  const AdminManagementProfilePage({required this.adminId, super.key});

  final String adminId;

  @override
  ConsumerState<AdminManagementProfilePage> createState() =>
      _AdminProfilePageState();
}

class _AdminProfilePageState
    extends ConsumerState<AdminManagementProfilePage> {
  bool get _isSelf {
    final me = Supabase.instance.client.auth.currentUser?.id;
    return me == widget.adminId;
  }

  String _roleLabel(AppLocalizations loc, String role) => switch (role) {
        'owner' => loc.adminMgmtRoleOwner,
        'admin' => loc.adminMgmtRoleAdmin,
        _ => role,
      };

  Future<void> _runWithSnack(Future<void> Function() action, String ok) async {
    final loc = AppLocalizations.of(context);
    try {
      await action();
      if (mounted) {
        ref.invalidate(adminDetailProvider(widget.adminId));
        ref.invalidate(adminsListProvider);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ok)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${loc.adminMgmtFailed}: $e')));
      }
    }
  }

  Future<String?> _askReason(BuildContext context, AppLocalizations loc) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.adminMgmtReason),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(hintText: loc.adminMgmtReasonHint),
          maxLines: 2,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(loc.adminMgmtCancel)),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
              child: Text(loc.adminMgmtConfirm)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final detail = ref.watch(adminDetailProvider(widget.adminId));
    final perms = ref.watch(adminPermissionsProvider(widget.adminId));
    final audit = ref.watch(adminAuditProvider(widget.adminId));

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.adminMgmtProfile),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${loc.adminMgmtFailed}: $e')),
        data: (account) {
          if (account == null) {
            return Center(child: Text(loc.adminMgmtNotFound));
          }
          final isOwner = account.role == 'owner';
          final canManage = !_isSelf && !isOwner;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _section(
                loc.adminMgmtIdentity,
                [
                  _row(loc.adminMgmtFullName,
                      account.fullName ?? loc.adminMgmtUnknown),
                  _row(loc.adminMgmtEmail, account.email),
                  _row(loc.adminMgmtId, account.id),
                  _row(loc.adminMgmtCreatedAt,
                      account.createdAt?.toLocal().toString().split('.')[0] ??
                          loc.adminMgmtUnknown),
                ],
              ),
              _section(loc.adminMgmtAccountStatus, [
                _row(
                  loc.adminMgmtStatus,
                  account.isActive
                      ? loc.adminMgmtStatusActive
                      : loc.adminMgmtStatusInactive,
                ),
                _row(loc.adminMgmtLastActivity, loc.adminMgmtNotTracked),
              ]),
              _section(
                loc.adminMgmtRole,
                [
                  _row(loc.adminMgmtRoleLabel, _roleLabel(loc, account.role)),
                  if (canManage)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        icon: const Icon(Icons.badge),
                        label: Text(loc.adminMgmtAssignRole),
                        onPressed: () => _assignRole(context, loc, account),
                      ),
                    ),
                ],
              ),
              _section(
                loc.adminMgmtHierarchy,
                [
                  _row(loc.adminMgmtSupervisor,
                      account.supervisorEmail ?? loc.adminMgmtNone),
                  if (canManage)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        icon: const Icon(Icons.swap_horiz),
                        label: Text(loc.adminMgmtChangeSupervisor),
                        onPressed: () => _changeSupervisor(context, loc, account),
                      ),
                    ),
                ],
              ),
              _section(
                loc.adminMgmtRegionScope,
                [
                  _row(loc.adminMgmtRegion,
                      account.regionName ?? loc.adminMgmtNone),
                  _row(
                    loc.adminMgmtScope,
                    account.scope == AdminScope.self
                        ? loc.adminMgmtScopeSelf
                        : account.scope == AdminScope.descendants
                            ? loc.adminMgmtScopeDescendants
                            : loc.adminMgmtUnknown,
                  ),
                  if (canManage)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        icon: const Icon(Icons.map),
                        label: Text(loc.adminMgmtAssignRegion),
                        onPressed: () => _assignRegion(context, loc, account),
                      ),
                    ),
                ],
              ),
              _section(loc.adminMgmtPermissions, [
                Text(loc.adminMgmtEffective),
                perms.when(
                  loading: () =>
                      const LinearProgressIndicator(),
                  error: (e, _) => Text('${loc.adminMgmtFailed}: $e'),
                  data: (p) {
                    final effective =
                        List<String>.from(p['effective'] as List? ?? []);
                    final granted = List<String>.from(p['grants'] as List? ?? []);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          children: effective
                              .map((x) => Chip(
                                    label: Text(x),
                                    visualDensity: VisualDensity.compact,
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                        Text(loc.adminMgmtGranted),
                        Wrap(
                          spacing: 6,
                          children: granted
                              .map((x) => Chip(
                                    label: Text(x),
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: Colors.blue.shade50,
                                  ))
                              .toList(),
                        ),
                        if (canManage)
                          Row(
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.add),
                                label: Text(loc.adminMgmtGrant),
                                onPressed: () => _grantPermission(
                                    context, loc, account, granted),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.remove),
                                label: Text(loc.adminMgmtRevoke),
                                onPressed: () => _revokePermission(
                                    context, loc, account, granted),
                              ),
                            ],
                          ),
                      ],
                    );
                  },
                ),
              ]),
              _section(
                loc.adminMgmtAudit,
                [
                  audit.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('${loc.adminMgmtFailed}: $e'),
                    data: (entries) {
                      if (entries.isEmpty) {
                        return Text(loc.adminMgmtNoAudit);
                      }
                      return Column(
                        children: entries
                            .map((e) => ListTile(
                                  dense: true,
                                  title: Text(e.action),
                                  subtitle: Text(
                                      '${e.resource}${e.resourceId != null ? ' • ${e.resourceId}' : ''}'),
                                  trailing: e.timestamp != null
                                      ? Text(e.timestamp!
                                          .toLocal()
                                          .toString()
                                          .split('.')[0])
                                      : null,
                                ))
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
              if (canManage)
                _section(loc.adminMgmtActions, [
                  if (account.isActive)
                    FilledButton.icon(
                      icon: const Icon(Icons.block),
                      label: Text(loc.adminMgmtDeactivate),
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade700),
                      onPressed: () => _deactivate(context, loc, account),
                    )
                  else
                    FilledButton.icon(
                      icon: const Icon(Icons.restart_alt),
                      label: Text(loc.adminMgmtReactivate),
                      onPressed: () => _reactivate(context, loc, account),
                    ),
                ]),
            ],
          );
        },
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
                flex: 2, child: Text(label, style: const TextStyle(color: Colors.grey))),
            Expanded(flex: 3, child: Text(value)),
          ],
        ),
      );

  Future<void> _deactivate(
    BuildContext context,
    AppLocalizations loc,
    AdminAccount account,
  ) async {
    final reason = await _askReason(context, loc);
    if (reason == null) return;
    await _runWithSnack(
      () => ref
          .read(adminActionProvider.notifier)
          .deactivate(id: account.id, adminId: account.id, reason: reason),
      loc.adminMgmtDeactivated,
    );
  }

  Future<void> _reactivate(
    BuildContext context,
    AppLocalizations loc,
    AdminAccount account,
  ) async {
    final reason = await _askReason(context, loc);
    if (reason == null) return;
    await _runWithSnack(
      () => ref
          .read(adminActionProvider.notifier)
          .reactivate(id: account.id, adminId: account.id, reason: reason),
      loc.adminMgmtReactivated,
    );
  }

  Future<void> _assignRole(
    BuildContext context,
    AppLocalizations loc,
    AdminAccount account,
  ) async {
    final reason = await _askReason(context, loc);
    if (reason == null) return;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.adminMgmtSelectRole),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(loc.adminMgmtRoleAdmin),
              onTap: () => Navigator.of(ctx).pop('admin'),
            ),
            ListTile(
              title: Text(loc.adminMgmtRoleOwner),
              onTap: () => Navigator.of(ctx).pop('owner'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(loc.adminMgmtCancel)),
        ],
      ),
    );
    if (picked == null) return;
    await _runWithSnack(
      () => ref.read(adminActionProvider.notifier).assignRole(
            id: account.id,
            adminId: account.id,
            role: picked,
            reason: reason,
          ),
      loc.adminMgmtRoleUpdated,
    );
  }

  Future<void> _changeSupervisor(
    BuildContext context,
    AppLocalizations loc,
    AdminAccount account,
  ) async {
    final reason = await _askReason(context, loc);
    if (reason == null) return;
    final admins = await ref.read(adminsListProvider.future);
    final candidates = admins
        .where((a) => a.id != account.id && a.role != 'owner')
        .toList();
    if (!mounted) return;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.adminMgmtSelectSupervisor),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: candidates
                .map((a) => ListTile(
                      title: Text(a.fullName ?? a.email),
                      onTap: () => Navigator.of(ctx).pop(a.id),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(loc.adminMgmtCancel)),
        ],
      ),
    );
    if (picked == null) return;
    await _runWithSnack(
      () => ref.read(adminActionProvider.notifier).changeSupervisor(
            id: account.id,
            adminId: account.id,
            newSupervisorId: picked,
            reason: reason,
          ),
      loc.adminMgmtSupervisorUpdated,
    );
  }

  Future<void> _assignRegion(
    BuildContext context,
    AppLocalizations loc,
    AdminAccount account,
  ) async {
    final reason = await _askReason(context, loc);
    if (reason == null) return;
    String? regionId;
    String scope = 'descendants';
    final regions = await ref
        .read(supabaseClientProvider)
        .from('regions')
        .select('id,name_en')
        .order('name_en');
    if (!mounted) return;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setSt) => AlertDialog(
          title: Text(loc.adminMgmtSelectRegion),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                items: regions
                    .map((r) => DropdownMenuItem(
                        value: r['id'] as String,
                        child: Text((r['name_en'] as String?) ?? '')))
                    .toList(),
                onChanged: (v) => setSt(() => regionId = v),
                decoration:
                    InputDecoration(labelText: loc.adminMgmtSelectRegion),
              ),
              DropdownButtonFormField<String>(
                initialValue: scope,
                items: [
                  DropdownMenuItem(
                      value: 'descendants',
                      child: Text(loc.adminMgmtScopeDescendants)),
                  DropdownMenuItem(
                      value: 'self', child: Text(loc.adminMgmtScopeSelf)),
                ],
                onChanged: (v) => setSt(() {}),
                onSaved: (v) => scope = v ?? 'descendants',
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(loc.adminMgmtCancel)),
            FilledButton(
                onPressed: () => Navigator.of(ctx).pop(regionId),
                child: Text(loc.adminMgmtConfirm)),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await _runWithSnack(
      () => ref.read(adminActionProvider.notifier).assignRegion(
            id: account.id,
            adminId: account.id,
            regionId: picked,
            scope: scope,
          ),
      loc.adminMgmtRegionUpdated,
    );
  }

  Future<void> _grantPermission(
    BuildContext context,
    AppLocalizations loc,
    AdminAccount account,
    List<String> granted,
  ) async {
    final options =
        adminPermissionVocabulary.where((p) => !granted.contains(p)).toList();
    if (!mounted) return;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.adminMgmtGrant),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: options
                .map((p) => ListTile(
                      title: Text(p),
                      onTap: () => Navigator.of(ctx).pop(p),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(loc.adminMgmtCancel)),
        ],
      ),
    );
    if (picked == null) return;
    await _runWithSnack(
      () => ref.read(adminActionProvider.notifier).grantPermission(
            id: account.id,
            adminId: account.id,
            permission: picked,
          ),
      loc.adminMgmtGrantedUpdated,
    );
  }

  Future<void> _revokePermission(
    BuildContext context,
    AppLocalizations loc,
    AdminAccount account,
    List<String> granted,
  ) async {
    if (granted.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(loc.adminMgmtNoGrants)));
      return;
    }
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.adminMgmtRevoke),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: granted
                .map((p) => ListTile(
                      title: Text(p),
                      onTap: () => Navigator.of(ctx).pop(p),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(loc.adminMgmtCancel)),
        ],
      ),
    );
    if (picked == null) return;
    await _runWithSnack(
      () => ref.read(adminActionProvider.notifier).revokePermission(
            id: account.id,
            adminId: account.id,
            permission: picked,
          ),
      loc.adminMgmtGrantedUpdated,
    );
  }
}
