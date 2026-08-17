import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/member_management/domain/entities/member.dart';
import 'package:delwaqty/features/member_management/presentation/member_providers.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class MemberListPage extends ConsumerStatefulWidget {
  const MemberListPage({super.key});

  @override
  ConsumerState<MemberListPage> createState() => _MemberListPageState();
}

class _MemberListPageState extends ConsumerState<MemberListPage> {
  String _search = '';
  String? _roleFilter;
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final membersAsync = ref.watch(memberListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Members'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(memberListProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.search,
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All Roles',
                  selected: _roleFilter == null,
                  onTap: () => setState(() => _roleFilter = null),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Customer',
                  selected: _roleFilter == 'customer',
                  onTap: () => setState(() => _roleFilter = 'customer'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Driver',
                  selected: _roleFilter == 'driver',
                  onTap: () => setState(() => _roleFilter = 'driver'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Merchant',
                  selected: _roleFilter == 'merchant',
                  onTap: () => setState(() => _roleFilter = 'merchant'),
                ),
              ],
            ),
          ),
          Expanded(
            child: membersAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => PremiumEmptyState(
                icon: Icons.error_outline,
                title: l10n.error,
                message: e.toString(),
              ),
              data: (members) {
                final filtered = members.where((m) {
                  if (_search.isNotEmpty) {
                    final q = _search.toLowerCase();
                    final name = (m.fullName ?? '').toLowerCase();
                    final email = (m.email ?? '').toLowerCase();
                    if (!name.contains(q) && !email.contains(q)) return false;
                  }
                  if (_roleFilter != null && m.role != _roleFilter) return false;
                  if (_statusFilter != null && m.accountStatus != _statusFilter) {
                    return false;
                  }
                  return true;
                }).toList();
                if (filtered.isEmpty) {
                  return const PremiumEmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'No members found',
                    message: 'Try adjusting your search or filters.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final m = filtered[index];
                    return AnimatedFadeIn(
                      child: _MemberTile(
                        member: m,
                        onTap: () =>
                            context.push('/admin/members/${m.id}'),
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

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.onTap});

  final Member member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (member.accountStatus) {
      'active' => Colors.green,
      'restricted' => Colors.orange,
      'suspended' => Colors.red,
      'banned' => Colors.red.shade900,
      _ => Colors.grey,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Text(
            (member.fullName ?? member.email ?? '?').substring(0, 1).toUpperCase(),
            style: TextStyle(color: statusColor, fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(
          member.fullName ?? 'Unnamed',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${member.email ?? ''}  •  ${member.role}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            member.accountStatus,
            style: TextStyle(
              fontSize: 11,
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
