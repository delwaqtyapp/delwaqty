import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/features/admin_management/domain/entities/admin_account.dart';
import 'package:delwaqty/features/admin_management/presentation/providers/admin_management_providers.dart';

class AdminManagementListPage extends ConsumerStatefulWidget {
  const AdminManagementListPage({super.key});

  @override
  ConsumerState<AdminManagementListPage> createState() =>
      _AdminManagementListPageState();
}

class _AdminManagementListPageState
    extends ConsumerState<AdminManagementListPage> {
  final _searchCtrl = TextEditingController();
  String? _roleFilter;
  String? _statusFilter;
  String? _regionFilter;
  String _sort = 'createdAt';
  int _page = 0;
  static const int _pageSize = 20;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AdminAccount> _applyFilters(List<AdminAccount> all) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final list = all.where((a) {
      if (_roleFilter != null && a.role != _roleFilter) return false;
      if (_statusFilter == 'active' && !a.isActive) return false;
      if (_statusFilter == 'inactive' && a.isActive) return false;
      if (_regionFilter != null && a.regionName != _regionFilter) return false;
      if (q.isNotEmpty) {
        final hay = '${a.fullName ?? ''} ${a.email} ${a.regionName ?? ''}'
            .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    list.sort((a, b) {
      switch (_sort) {
        case 'name':
          return (a.fullName ?? a.email).compareTo(b.fullName ?? b.email);
        case 'role':
          return a.role.compareTo(b.role);
        case 'createdAt':
        default:
          final ta = a.createdAt;
          final tb = b.createdAt;
          if (ta == null && tb == null) return 0;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return tb.compareTo(ta);
      }
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final asyncAdmins = ref.watch(adminsListProvider);
    final regions = asyncAdmins.maybeWhen(
      data: (list) => {
        for (final a in list)
          if (a.regionName != null) a.regionName!,
      }.toList(),
      orElse: () => <String>[],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.adminMgmtList),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: loc.adminMgmtRefresh,
            onPressed: () => ref.invalidate(adminsListProvider),
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: loc.adminMgmtCreate,
            onPressed: () => _openCreateDialog(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: loc.adminMgmtSearch,
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                DropdownButton<String?>(
                  value: _roleFilter,
                  hint: Text(loc.adminMgmtFilterRole),
                  items: [
                    DropdownMenuItem(child: Text(loc.adminMgmtAll)),
                    DropdownMenuItem(
                        value: 'owner', child: Text(loc.adminMgmtRoleOwner)),
                    DropdownMenuItem(
                        value: 'admin', child: Text(loc.adminMgmtRoleAdmin)),
                  ],
                  onChanged: (v) => setState(() => _roleFilter = v),
                ),
                DropdownButton<String?>(
                  value: _statusFilter,
                  hint: Text(loc.adminMgmtFilterStatus),
                  items: [
                    DropdownMenuItem(child: Text(loc.adminMgmtAll)),
                    DropdownMenuItem(
                        value: 'active',
                        child: Text(loc.adminMgmtStatusActive)),
                    DropdownMenuItem(
                        value: 'inactive',
                        child: Text(loc.adminMgmtStatusInactive)),
                  ],
                  onChanged: (v) => setState(() => _statusFilter = v),
                ),
                DropdownButton<String?>(
                  value: _regionFilter,
                  hint: Text(loc.adminMgmtFilterRegion),
                  items: [
                    DropdownMenuItem(child: Text(loc.adminMgmtAll)),
                    for (final r in regions)
                      DropdownMenuItem(value: r, child: Text(r)),
                  ],
                  onChanged: (v) => setState(() => _regionFilter = v),
                ),
                DropdownButton<String>(
                  value: _sort,
                  items: [
                    DropdownMenuItem(
                        value: 'createdAt',
                        child: Text(loc.adminMgmtSortCreated)),
                    DropdownMenuItem(
                        value: 'name', child: Text(loc.adminMgmtSortName)),
                    DropdownMenuItem(
                        value: 'role', child: Text(loc.adminMgmtSortRole)),
                  ],
                  onChanged: (v) => setState(() => _sort = v!),
                ),
              ],
            ),
          ),
          Expanded(
            child: asyncAdmins.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('${loc.adminMgmtFailed}: $e'),
              ),
              data: (all) {
                final filtered = _applyFilters(all);
                if (filtered.isEmpty) {
                  return Center(child: Text(loc.adminMgmtNoAdmins));
                }
                final pageCount =
                    (filtered.length / _pageSize).ceil();
                if (_page >= pageCount) _page = pageCount - 1;
                final start = _page * _pageSize;
                final end = (start + _pageSize).clamp(0, filtered.length);
                final pageItems = filtered.sublist(start, end);
                return Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: pageItems.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final a = pageItems[i];
                          return _AdminRow(account: a, onTap: () {
                            context.push('/admin/admins/${a.id}');
                          });
                        },
                      ),
                    ),
                    _Pager(
                      page: _page,
                      pageCount: pageCount,
                      total: filtered.length,
                      onPrev: () =>
                          setState(() => _page = (_page - 1).clamp(0, pageCount - 1)),
                      onNext: () => setState(
                          () => _page = (_page + 1).clamp(0, pageCount - 1)),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminRow extends StatelessWidget {
  const _AdminRow({required this.account, required this.onTap});

  final AdminAccount account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final initials = (account.fullName?.isNotEmpty == true
            ? account.fullName!
            : account.email)
        .trim()
        .characters
        .take(2)
        .join()
        .toUpperCase();
    final roleLabel = account.role == 'owner'
        ? loc.adminMgmtRoleOwner
        : account.role == 'admin'
            ? loc.adminMgmtRoleAdmin
            : account.role;
    return ListTile(
      leading: CircleAvatar(child: Text(initials)),
      title: Text(account.fullName ?? account.email),
      subtitle: Text(
        '${account.email} • ${loc.adminMgmtRegion}: ${account.regionName ?? loc.adminMgmtUnknown}',
      ),
      trailing: Wrap(
        spacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Chip(
            label: Text(roleLabel),
            visualDensity: VisualDensity.compact,
          ),
          Chip(
            label: Text(account.isActive
                ? loc.adminMgmtStatusActive
                : loc.adminMgmtStatusInactive),
            visualDensity: VisualDensity.compact,
            backgroundColor: account.isActive
                ? Colors.green.shade100
                : Colors.red.shade100,
          ),
          const Icon(Icons.chevron_left),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.pageCount,
    required this.total,
    required this.onPrev,
    required this.onNext,
  });

  final int page;
  final int pageCount;
  final int total;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(onPressed: page > 0 ? onPrev : null, icon: const Icon(Icons.navigate_before)),
          Text('${loc.adminMgmtPage} ${page + 1} / $pageCount  •  $total'),
          IconButton(
              onPressed: page < pageCount - 1 ? onNext : null,
              icon: const Icon(Icons.navigate_next)),
        ],
      ),
    );
  }
}

// ─── Create Admin dialog (Edge Function boundary) ─────────────────────────

Future<void> _openCreateDialog(BuildContext context, WidgetRef ref) async {
  final loc = AppLocalizations.of(context);
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  String? supervisorId;
  String? regionId;
  final formKey = GlobalKey<FormState>();

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(loc.adminMgmtCreateTitle),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: loc.adminMgmtFullName),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? loc.adminMgmtFullNameRequired : null,
              ),
              TextFormField(
                controller: emailCtrl,
                decoration: InputDecoration(labelText: loc.adminMgmtEmail),
                validator: (v) =>
                    (v == null || !v.contains('@')) ? loc.adminMgmtEmailInvalid : null,
              ),
              TextFormField(
                controller: passCtrl,
                decoration: InputDecoration(labelText: loc.adminMgmtPassword),
                obscureText: true,
                validator: (v) =>
                    (v == null || v.length < 8) ? loc.adminMgmtPasswordHint : null,
              ),
              FutureBuilder<List<AdminAccount>>(
                future: ref.read(adminsListProvider.future),
                builder: (c, snap) {
                  final admins = snap.data ?? [];
                  return DropdownButtonFormField<String?>(
                    initialValue: supervisorId,
                    decoration:
                        InputDecoration(labelText: loc.adminMgmtSelectSupervisor),
                    items: [
                      DropdownMenuItem(child: Text(loc.adminMgmtNone)),
                      for (final a in admins)
                        DropdownMenuItem(
                            value: a.id, child: Text(a.fullName ?? a.email)),
                    ],
                    onChanged: (v) => supervisorId = v,
                  );
                },
              ),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: ref
                    .read(supabaseClientProvider)
                    .from('regions')
                    .select('id,name_en')
                    .order('name_en'),
                builder: (c, snap) {
                  final regions = snap.data ?? [];
                  return DropdownButtonFormField<String?>(
                    initialValue: regionId,
                    decoration:
                        InputDecoration(labelText: loc.adminMgmtSelectRegion),
                    items: [
                      DropdownMenuItem(child: Text(loc.adminMgmtNone)),
                      for (final r in regions)
                        DropdownMenuItem(
                            value: r['id'] as String,
                            child: Text((r['name_en'] as String?) ?? '')),
                    ],
                    onChanged: (v) => regionId = v,
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(loc.adminMgmtCancel)),
        FilledButton(
          onPressed: () async {
            if (!formKey.currentState!.validate()) return;
            try {
              await ref.read(adminManagementRepositoryProvider).createAdmin(
                    email: emailCtrl.text.trim(),
                    password: passCtrl.text,
                    fullName: nameCtrl.text.trim(),
                    supervisorId: supervisorId,
                    regionId: regionId,
                  );
              if (ctx.mounted) Navigator.of(ctx).pop();
              ref.invalidate(adminsListProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(loc.adminMgmtCreateSuccess)),
              );
            } catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('${loc.adminMgmtFailed}: $e')),
                );
              }
            }
          },
          child: Text(loc.adminMgmtCreate),
        ),
      ],
    ),
  );
}
