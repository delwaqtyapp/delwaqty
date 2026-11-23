import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/features/admin/presentation/widgets/admin_page_header.dart';
import 'package:delwaqty/features/admin/presentation/widgets/admin_states.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// Live directory of every platform user (customers, merchants, drivers,
/// admins, owner). The sidebar "Users" entry previously opened the admin-tier
/// management list, which only ever shows admin accounts — an owner looking
/// for real users saw a tiny count and concluded the numbers were wrong.
class AdminUsersWebPage extends StatefulWidget {
  const AdminUsersWebPage({super.key});

  @override
  State<AdminUsersWebPage> createState() => _AdminUsersWebPageState();
}

class _AdminUsersWebPageState extends State<AdminUsersWebPage> {
  final _searchCtrl = TextEditingController();
  String _roleFilter = 'all';
  late Future<List<Map<String, dynamic>>> _future;

  static const _roles = ['all', 'customer', 'merchant', 'driver', 'admin'];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await Supabase.instance.client
        .from('users')
        .select(
          'id, email, full_name, phone, role, role_key, user_type, '
          'account_status, verification_status, created_at',
        )
        .order('created_at', ascending: false)
        .limit(1000);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  void _refresh() => setState(() => _future = _load());

  String _displayRole(Map<String, dynamic> u) {
    final role = (u['role'] ?? u['user_type'] ?? '').toString();
    final roleKey = (u['role_key'] ?? '').toString();
    if (roleKey == 'owner') return 'owner';
    if (role.isEmpty) return 'customer';
    return role;
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> users) {
    final q = _searchCtrl.text.trim().toLowerCase();
    return users.where((u) {
      final role = _displayRole(u);
      final isAdminTier =
          role == 'admin' || role == 'owner' || role == 'supervisor';
      if (_roleFilter == 'admin') {
        if (!isAdminTier) return false;
      } else if (_roleFilter != 'all' && role != _roleFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      final hay = [
        u['full_name'],
        u['name'],
        u['email'],
        u['phone'],
      ].whereType<String>().join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Narrow phones get tighter padding so the header and content keep
    // usable width at large text scales.
    final padding = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 32.0;
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: l10n.adminUsersPage,
            subtitle: l10n.adminUsersPageSubtitle,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: l10n.adminUsersSearchHint,
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: l10n.adminMgmtRefresh,
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final r in _roles)
                ChoiceChip(
                  label: Text(_roleLabel(l10n, r)),
                  selected: _roleFilter == r,
                  onSelected: (_) => setState(() => _roleFilter = r),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return AdminLoadingState(label: l10n.adminLoadingLiveStats);
                }
                if (snap.hasError) {
                  // Scrollable so a tall error state never overflows
                  // vertically on small screens.
                  return LayoutBuilder(
                    builder: (context, constraints) =>
                        SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: AdminErrorState(
                              message: appErrorText(context, snap.error!),
                              onRetry: _refresh,
                            ),
                          ),
                        ),
                  );
                }
                final users = _applyFilters(snap.data ?? const []);
                if (users.isEmpty) {
                  return Center(child: Text(l10n.noResults));
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    _refresh();
                    await _future;
                  },
                  child: ListView.separated(
                    itemCount: users.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) =>
                        _UserRow(user: users[i], l10n: l10n),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _roleLabel(AppLocalizations l10n, String role) {
    switch (role) {
      case 'customer':
        return l10n.customer;
      case 'merchant':
        return l10n.merchant;
      case 'driver':
        return l10n.driver;
      case 'admin':
        return l10n.adminMgmtList;
      default:
        return l10n.all;
    }
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user, required this.l10n});

  final Map<String, dynamic> user;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final name = (user['full_name'] ?? user['email'] ?? '—').toString();
    final email = (user['email'] ?? '').toString();
    final phone = (user['phone'] ?? '').toString();
    final status = (user['account_status'] ?? 'active').toString();
    final role = (user['role'] ?? user['user_type'] ?? 'customer').toString();
    final roleKey = (user['role_key'] ?? '').toString();
    final shownRole = roleKey == 'owner' ? 'owner' : role;
    final created = DateTime.tryParse((user['created_at'] ?? '').toString());
    final initials = name.isNotEmpty
        ? name
              .trim()
              .substring(0, name.trim().length >= 2 ? 2 : 1)
              .toUpperCase()
        : '?';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: AppColors.brandPurple.withValues(alpha: 0.12),
        child: Text(
          initials,
          style: const TextStyle(
            color: AppColors.brandPurple,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      // Chips wrap below so name and contact line keep the full width.
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            [
              if (email.isNotEmpty) email,
              if (phone.isNotEmpty) phone,
              if (created != null)
                '${l10n.joinedDate}: ${created.toLocal().toString().substring(0, 10)}',
            ].join(' • '),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(
              spacing: 8,
              children: [
                _Chip(label: shownRole, color: AppColors.brandPurple),
                _Chip(
                  label: status == 'active' ? l10n.active : status,
                  color: status == 'active' ? Colors.green : Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
